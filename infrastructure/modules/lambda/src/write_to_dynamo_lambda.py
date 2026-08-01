# Portions of this code are adapted from AWS Training and Certification:
# "Capstone Project: Building a Customer Onboarding App - Lab 09".
# Original lab code (c) Amazon Web Services, Inc. Adapted by Giancarlo Martinez
# for ACI Capstone 1.
import os
import csv
import boto3
# Provided by the AWS Lambda Powertools layer (see write_to_dynamo_lambda_function.tf), not by the deployment zip.
#it resolves purely because Lambda mounted the layer at /opt/python.
from aws_lambda_powertools import Tracer


unzipped_s3_prefix = "unzipped/"

#DynamoDB
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE'])# add ENV variable TABLE

#S3
s3 = boto3.client('s3')

#X-Ray. Module scope: runs once per cold start. Reads POWERTOOLS_SERVICE_NAME and patches
#boto3 so S3/DynamoDB calls emit their own subsegments.
tracer = Tracer()


def parse_csv_ddb(app_uuid, details_file):
    "Load CSV and save to dynamo"
    with open(details_file, 'r', encoding="utf-8") as file:
        reader = csv.DictReader(file)
        details_dict = next(reader)

    table.put_item(Item={**details_dict, "APP_UUID": app_uuid})

    return details_dict

# @tracer.capture_lambda_handler wraps your handler and does four things per invocation:

#   1. Opens a subsegment named ## lambda_handler around your handler body, so you can see your own code's time separately from Lambda's init overhead.
#   2. Adds a ColdStart annotation — annotations are indexed, so you can filter X-Ray for cold starts specifically.
#   3. Adds the service name as an annotation (POWERTOOLS_SERVICE_NAME = var.project_name) in env vars.
#   4. Records the handler's return value as trace metadata, and on an exception, records the error and re-raises.
@tracer.capture_lambda_handler
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
