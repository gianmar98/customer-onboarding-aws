# Portions of this code are adapted from AWS Training and Certification:
# "Capstone Project: Building a Customer Onboarding App - Lab 09".
# Original lab code (c) Amazon Web Services, Inc. Adapted by Giancarlo Martinez
# for ACI Capstone 1.

import os
import boto3

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


def lambda_handler(event, context):
    print(f"Event=> {event}")
    app_uuid = event['application']['app_uuid']
    bucket = event['detail']['bucket']['name']
    license_key = f"{unzipped_s3_prefix}{app_uuid}_license.png"
    selfie_key = f"{unzipped_s3_prefix}{app_uuid}_selfie.png"

    # Add print to verify your solution by checking CloudWatch logs
    print(f"app_uuid = {app_uuid}")
    print(f"selfie_key = {selfie_key}")
    print(f"license_key = {license_key}")

    # Submit license and selfie to rekognition to compare faces.
    rekog_response = compare_faces(app_uuid, bucket, license_key, selfie_key)
    if not rekog_response:
        raise ValueError('Photo rekognition match FAILED. Program will stop')

    return True


# aws lambda invoke --function-name CompareFacesLambdaFunction \
# --cli-binary-format raw-in-base64-out \
# --payload '{"detail": {"bucket": {"name": "INSERT_YOUR_DOCUMENT_BUCKET"}}, "application": {"app_uuid": "8d247914"}}' response3.json
