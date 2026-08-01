import json
import boto3
import os
import urllib3

#DynamoDB
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE'])# add ENV variable TABLE

#API GW
# Pull the specific API Gateway Invoke URL from Environment Variables
http = urllib3.PoolManager()
api_url = os.environ['VALIDATE_LICENSE_API_URL']

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
    headers = {
        "Content-Type": "application/json",
        "X-API-Key": "your-api-key-if-required"
    }

    try:
        # Send the POST request (change to 'GET', 'PUT', etc., as needed)
        response = http.request(
            "POST",
            api_url,
            body=json.dumps(payload),
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