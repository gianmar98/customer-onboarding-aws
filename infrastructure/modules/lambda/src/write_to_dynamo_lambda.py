# Portions of this code are adapted from AWS Training and Certification:
# "Capstone Project: Building a Customer Onboarding App - Lab 09".
# Original lab code (c) Amazon Web Services, Inc. Adapted by Giancarlo Martinez
# for ACI Capstone 1.
import os
import csv
import boto3


unzipped_s3_prefix = "unzipped/"

#DynamoDB
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE'])# add ENV variable TABLE

#S3
s3 = boto3.client('s3')


def parse_csv_ddb(app_uuid, details_file):
    "Load CSV and save to dynamo"
    with open(details_file, 'r', encoding="utf-8") as file:
        reader = csv.DictReader(file)
        details_dict = next(reader)

    table.put_item(Item={**details_dict, "APP_UUID": app_uuid})

    return details_dict


def lambda_handler(event, context):
    """
    Called from step functions to load CSV to DynamoDB
    :param event:
    :param context:
    :return:
    """
    print(f"Full event => {event}")

    bucket = event['detail']['bucket']['name']
    app_uuid = event['application']['app_uuid']
    details_key = f"{unzipped_s3_prefix}{app_uuid}_details.csv"
    details_file = f"/tmp/{app_uuid}_details.csv"

    s3.download_file(bucket, details_key, details_file)
    csv_dict = parse_csv_ddb(app_uuid, details_file)

    return {
        "driver_license_id": csv_dict['DOCUMENT_NUMBER'],
        "validation_override": True,
        "app_uuid": app_uuid
    }


#TEST COMMAND
# aws lambda invoke --function-name WriteToDynamoLambdaFunction \
# --cli-binary-format raw-in-base64-out \
# --payload '{"detail": {"bucket": {"name": "INSERT_YOUR_DOCUMENT_BUCKET"}}, "application": {"app_uuid": "8d247914"}}' response2.json
