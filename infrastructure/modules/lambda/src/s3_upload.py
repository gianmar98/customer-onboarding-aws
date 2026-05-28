# Portions of this code are adapted from AWS Training and Certification:
# "Capstone Project: Building a Customer Onboarding App - Lab 03,04".
# Original lab code (c) Amazon Web Services, Inc. Adapted by Giancarlo Martinez
# for ACI Capstone 1.

import json
import os
import csv
import zipfile
import boto3

unzipped_dir = "/tmp/unzipped/"
unzipped_s3_prefix = "unzipped/"

s3 = boto3.client('s3')

#DynamoDB
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE'])# add ENV variable TABLE

#Rekognition
rekognition = boto3.client('rekognition')

#SNS
sns = boto3.client('sns')
env_topic = os.environ['TOPIC']# add ENV variable TABLE


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
    zip_name = os.path.basename(key)
    zip_fullpath = f"/tmp/{zip_name}"
    s3.download_file(bucket, key, zip_fullpath)
    with zipfile.ZipFile(zip_fullpath, 'r') as zip_ref:
        zip_ref.extractall(unzipped_dir)
    os.remove(zip_fullpath)

    zipped_files = os.listdir(unzipped_dir)
    return zipped_files


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
    record = event['Records'][0]
    bucket = record['s3']['bucket']['name']
    key = record['s3']['object']['key']

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
    rekog_response = compare_faces(app_uuid, bucket, license_key, selfie_key)
    if not rekog_response:
        raise ValueError('Photo rekognition match FAILED. Program will stop')


