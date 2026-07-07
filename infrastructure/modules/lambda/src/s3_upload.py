# Portions of this code are adapted from AWS Training and Certification:
# "Capstone Project: Building a Customer Onboarding App - Lab 03,04".
# Original lab code (c) Amazon Web Services, Inc. Adapted by Giancarlo Martinez
# for ACI Capstone 1.

import json
import os
import csv
import zipfile
import boto3
from botocore.exceptions import ClientError  # added: referenced in the send_message except handler; without this import a send failure raises NameError instead of being caught.
import shutil  # added: needed for shutil.rmtree() to wipe /tmp/unzipped/ between runs. Lambda reuses warm containers, so without this stale files from a previous invocation leak into the next one.

unzipped_dir = "/tmp/unzipped/"
unzipped_s3_prefix = "unzipped/"

#S3
s3 = boto3.client('s3')

#DynamoDB
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE'])# add ENV variable TABLE

#Rekognition
rekognition = boto3.client('rekognition')

#SNS
sns = boto3.client('sns')
env_topic = os.environ['TOPIC']# add ENV variable TABLE

#TEXTRACT
textract = boto3.client('textract')

#SQS
sqs = boto3.client('sqs')
QUEUE_URL = os.environ['SQS_URL']

def unzip_object(bucket, key):
    """Download a zip from S3, extract it locally, and return its file list.

    Pulls the zip at ``s3://{bucket}/{key}`` into ``/tmp/``, extracts every
    member into ``/tmp/unzipped/``, then removes the original zip from the
    Lambda ephemeral filesystem to free space.

    Args:
        bucket: Name of the S3 bucket the zip lives in.
        key: S3 object key of the zip (e.g. ``zipped/<app_uuid>.zip``).

    Returns:
        list[str]: Filenames extracted into ``/tmp/unzipped/`` (top level only).
    """
    if not os.path.exists(unzipped_dir):  # added: extractall() fails if /tmp/unzipped/ doesn't exist yet. Guarding here makes the function safe to call on a cold container without relying on the handler having created it.
        os.makedirs(unzipped_dir)         # added: create the target dir before extracting into it.

    zip_name = os.path.basename(key)
    zip_fullpath = f"/tmp/{zip_name}"
    s3.download_file(bucket, key, zip_fullpath)
    with zipfile.ZipFile(zip_fullpath, 'r') as zip_ref:
        zip_ref.extractall(unzipped_dir)
    os.remove(zip_fullpath)

    return [f for f in os.listdir(unzipped_dir) if not f.startswith('__')]  # added: filter out '__'-prefixed entries (e.g. macOS's __MACOSX folder). Without this, those junk entries get re-uploaded to S3 and can break the later file-name math.


def parse_csv_ddb(app_uuid, details_file):
    "Load CSV and save to dynamo"
    with open(details_file, 'r', encoding="utf-8") as file:
        reader = csv.DictReader(file)
        details_dict = next(reader)

    table.put_item(Item={**details_dict, "APP_UUID": app_uuid})

    return details_dict

def compare_faces(app_uuid, bucket, license_key, selfie_key):
    "calls rekognition to compare license and selfie"
    print("Starting face comparison")
    try:  # added: wrap the Rekognition call. A bad/blurry image or an API error would otherwise throw and abort the invocation before we record anything in DynamoDB. Catching it lets us treat a failed comparison as a non-match and keep going.
        compare_response = rekognition.compare_faces(
            SourceImage={'S3Object': {
                'Bucket': bucket,
                'Name': license_key,
            }},
            TargetImage={'S3Object': {
                'Bucket': bucket,
                'Name': selfie_key,
            }},
            SimilarityThreshold=80
        )

        if len(compare_response['FaceMatches']) < 1:
            photo_match_result = False
        else:
            photo_match_result = compare_response['FaceMatches'][0]['Similarity'] >= 80
    except Exception as e:  # added: any Rekognition failure becomes a recorded non-match instead of an unhandled crash.
        print(f"Error in face comparison: {str(e)}")  # added: log the cause to CloudWatch so failures are still debuggable.
        photo_match_result = False  # added: fail safe -> treat an errored comparison as "did not match".

    # Update DDB with photo match value.
    table.update_item(
        Key={
            'APP_UUID': app_uuid
            },
        UpdateExpression='SET LICENSE_SELFIE_MATCH = :p_match',
        ExpressionAttributeValues={
            ':p_match': photo_match_result
            }
        )

    # Amazon SNS publish and Amazon S3 folder.
    if not photo_match_result:
        sns.publish(
            TopicArn= env_topic,
            Message= 'License photo validation FAILED',
            Subject= 'License photo validation FAILED',
            )

    print("finished compare faces")
    return photo_match_result

# Fields we both extract from the license and compare against the CSV.
# added: defined once and reused by textract_response() and compare_dictionaries() so the two stay in sync (a field added here is automatically extracted AND compared).
REQUIRED_FIELDS = [
    'DOCUMENT_NUMBER', 'FIRST_NAME', 'LAST_NAME', 'DATE_OF_BIRTH',
    'ADDRESS', 'STATE_IN_ADDRESS', 'CITY_IN_ADDRESS', 'ZIP_CODE_IN_ADDRESS'
]

def textract_response(bucket, license_key):
    "Extract the required identity fields from the license via Textract"
    print("Starting textract validation")

    response = textract.analyze_id(DocumentPages=[
        {
            'S3Object': {
                'Bucket': bucket,
                'Name': license_key,
            }
        }
    ])

    id_data = response['IdentityDocuments'][0]['IdentityDocumentFields']

    id_fields = {}  # added: return a dict instead of a positional tuple. The old tuple dropped DOCUMENT_NUMBER and STATE, and a tuple can't be compared field-by-field against the CSV. A dict keyed by field name is what compare_dictionaries() needs.
    for field in id_data:
        field_type = field['Type']['Text']
        if field_type in REQUIRED_FIELDS:                       # added: keep only the fields we care about, ignore everything else Textract returns.
            id_fields[field_type] = field['ValueDetection']['Text']

    return id_fields

def compare_dictionaries(app_uuid, details_dict, textract_dict):
    "Compare the CSV-supplied details against the Textract-extracted license fields"
    # added: this whole function was missing. Extracting license text is pointless unless we verify it matches what the customer submitted in the CSV.
    csv_subset = {k: details_dict.get(k, '') for k in REQUIRED_FIELDS}       # added: narrow both sides to the same key set so the equality check is apples-to-apples (the CSV may carry extra columns).
    textract_subset = {k: textract_dict.get(k, '') for k in REQUIRED_FIELDS} # added: .get(..., '') avoids a KeyError when Textract fails to read a field.
    comparison = csv_subset == textract_subset                              # added: dict equality compares every required field at once.

    table.update_item(                                                       # added: persist the result so downstream consumers can read LICENSE_DETAILS_MATCH, mirroring how compare_faces records LICENSE_SELFIE_MATCH.
        Key={'APP_UUID': app_uuid},
        UpdateExpression='SET LICENSE_DETAILS_MATCH = :d_match',
        ExpressionAttributeValues={':d_match': comparison}
    )

    if not comparison:                                                       # added: alert on mismatch, same pattern as the face-comparison failure notification.
        sns.publish(
            TopicArn=env_topic,
            Message='Data validation between the license and the .csv file FAILED',
            Subject='Data validation between the license and the .csv file FAILED',
        )

    return comparison



def lambda_handler(event, context):
    """Entry point invoked by S3 on ``s3:ObjectCreated:Put`` under ``zipped/``.

    For each triggering zip:
        1. Download and extract the zip into ``/tmp/unzipped/``.
        2. Re-upload every extracted file to the same bucket under the
           ``unzipped/`` prefix.
        3. Derive ``app_uuid`` from the zip filename and build the expected
           selfie / license / details paths.
        4. Log the derived paths to CloudWatch for verification.

    Args:
        event: S3 event payload. Only ``Records[0].s3.bucket.name`` and
            ``Records[0].s3.object.key`` are read.
        context: Standard Lambda context object (unused).
    """
    # print(f"Full Record {event}")
    record = event['Records'][0]
    bucket = record['s3']['bucket']['name']
    key = record['s3']['object']['key']

    try:  # added: wrap the body so the finally block always runs and clears /tmp, even if a step throws.
        if os.path.exists(unzipped_dir):  # added: clear any leftovers from a previous warm-container run BEFORE extracting, so stale files from another applicant can't contaminate this one.
            shutil.rmtree(unzipped_dir)
        os.makedirs(unzipped_dir)         # added: recreate a clean working directory.

        # Unzip the object from the event
        files_list = unzip_object(bucket, key)

        # upload files to the unzipped location
        for file in files_list:
            s3.upload_file(unzipped_dir + file, bucket, unzipped_s3_prefix + file)
            print(f"File being uploaded is {file} to {unzipped_s3_prefix + file}")

        # retrieve app_uuid, selfie_key, license_key, and details_file and save them as variables for later use
        app_uuid = os.path.basename(key).replace(".zip", "")
        selfie_key = f"{unzipped_s3_prefix}{app_uuid}_selfie.png"
        license_key = f"{unzipped_s3_prefix}{app_uuid}_license.png"
        details_file = f"{unzipped_dir}{app_uuid}_details.csv"

        # Add print to verify your solution by checking CloudWatch logs
        print(f"app_uuid = {app_uuid}")
        print(f"selfie_key = {selfie_key}")
        print(f"license_key = {license_key}")
        print(f"details_file = {details_file}")

        # Save CSV to dynamo
        details_dict = parse_csv_ddb(app_uuid, details_file)

        # Submit license and selfie to rekognition to compare faces.
        compare_faces(app_uuid, bucket, license_key, selfie_key)  # added: dropped the `raise` on mismatch. Per the chosen flow, we run every check and record results rather than hard-stopping; compare_faces already writes LICENSE_SELFIE_MATCH and fires SNS on failure.

        # Extract the license fields and verify they match the submitted CSV.
        textract_dict = textract_response(bucket, license_key)            # added: now returns a dict of license fields...
        compare_dictionaries(app_uuid, details_dict, textract_dict)      # added: ...which we compare against the CSV and record as LICENSE_DETAILS_MATCH. This is the validation step that was previously missing entirely.


        # Send to License SQS Queue to submit and validate lambda function
        print(f"Sending message to SQS queue {QUEUE_URL}")
        sqs_message_body = {
            "driver_license_id": details_dict['DOCUMENT_NUMBER'],
            "validation_override": True,
            "uuid": app_uuid,
        }

        try:
            # 2. Send the message to the SQS queue
            response = sqs.send_message(
                QueueUrl=QUEUE_URL,
                MessageBody=json.dumps(sqs_message_body),
            )

            # 3. Return the SQS Message ID on success
            return {
                "statusCode": 200,
                "body": f"Message sent successfully. MessageId: {response['MessageId']}"
            }

        except ClientError as e:
            print(f"AWS ClientError: {e.response['Error']['Message']}")
            return {
                "statusCode": 500,
                "body": "Failed to send message to SQS."
            }


    finally:
        if os.path.exists(unzipped_dir):  # added: always wipe /tmp/unzipped/ on the way out so a warm container starts the next invocation clean and we don't slowly fill the 512MB /tmp budget.
            shutil.rmtree(unzipped_dir)


