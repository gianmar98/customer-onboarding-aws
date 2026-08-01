import json
import boto3
import os
import urllib3
# botocore ships with boto3 in the Lambda runtime, so SigV4 signing needs no extra package.
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

#DynamoDB
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE'])# add ENV variable TABLE

#API GW
# Pull the specific API Gateway Invoke URL from Environment Variables
http = urllib3.PoolManager()
api_url = os.environ['VALIDATE_LICENSE_API_URL']

# The POST /license route is authorization_type = "AWS_IAM", so an unsigned request gets a
# 403 before it ever reaches the validation Lambda. These are the execution role's creds;
# get_credentials() returns a refreshable object, so it stays valid across warm invocations.
session = boto3.Session()
credentials = session.get_credentials()
signing_region = session.region_name


def sign_request(url, body):
    "SigV4-sign a POST to the validation API and return the headers to send with it."
    request = AWSRequest(
        method="POST",
        url=url,
        data=body,
        headers={"Content-Type": "application/json"}
    )
    # 'execute-api' is the signing name for API Gateway. The signature covers the body, so
    # the exact same bytes passed here must be the ones sent on the wire.
    SigV4Auth(credentials, "execute-api", signing_region).add_auth(request)
    return dict(request.headers)

#SNS
sns = boto3.client('sns')
env_topic = os.environ['TOPIC']


def lambda_handler(event, context):
    "Takes API gateway event and responds with the validation_override"
    Records = event['Records']
    Record = Records[0]
    body = Record["body"]
    body_json = json.loads(body)
    print(f'body_json => {body_json}')
    driver_license_id = body_json["driver_license_id"]
    validation_override=body_json["validation_override"]
    uuid = body_json["uuid"]
    print(f'Drivers License: {driver_license_id}')
    print(f'Validation Override: {validation_override}')
    print(f'UUid: {uuid}')

    # Define payload and headers
    payload = {
        "driver_license_id": driver_license_id,
        "validation_override": validation_override,
        "uuid": uuid
    }
    print(f'Payload => {payload}')
    # Serialise once: the signature is computed over these exact bytes, so re-encoding
    # between signing and sending would invalidate it.
    encoded_payload = json.dumps(payload)
    headers = sign_request(api_url, encoded_payload)

    try:
        # Send the POST request (change to 'GET', 'PUT', etc., as needed)
        response = http.request(
            "POST",
            api_url,
            body=encoded_payload,
            headers=headers,
            timeout=5.0  # Timeout in seconds
        )

        # Parse and return the response data
        response_data = json.loads(response.data.decode("utf-8"))
        print(f'Response => {response_data}')

        # The DynamoDB write is identical either way — only the SNS notification is
        # conditional, so the write happens once outside the branch.
        print("Success" if response_data == True else "Failure")
        table.update_item(
            Key={
                "APP_UUID":uuid
            },
            UpdateExpression="SET LICENSE_VALIDATION = :v_match",
            ExpressionAttributeValues={
                ':v_match': response_data
            }
        )

        if response_data != True:
            sns.publish(
                TopicArn=env_topic,
                Message='License photo validation FAILED',
                Subject='License photo validation FAILED',
            )

    except Exception as e:
        print(f"Error sending request: {str(e)}")
        # Re-raise instead of returning. SQS only checks whether the function crashed —
        # a normal return (even with statusCode 500) counts as success and the message is
        # deleted. Raising is what engages the redrive policy, so a transient API Gateway
        # or DynamoDB failure gets retried and eventually lands in the DLQ instead of
        # being silently lost.
        raise

        # Previous behaviour — swallowed the error, so SQS deleted the message:
        # return {
        #     "statusCode": 500,
        #     "body": f"Internal Lambda Error: {str(e)}"
        # }