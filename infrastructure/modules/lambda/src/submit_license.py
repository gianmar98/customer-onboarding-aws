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

        if response_data == True:
            print("Success")
            table.update_item(
                Key={
                    "APP_UUID":uuid
                },
                UpdateExpression="SET LICENSE_VALIDATION = :v_match",
                ExpressionAttributeValues={
                    ':v_match': response_data
                }
            )
        else:
            print("Failure")
            table.update_item(
                Key={
                    "APP_UUID":uuid
                },
                UpdateExpression="SET LICENSE_VALIDATION = :v_match",
                ExpressionAttributeValues={
                    ':v_match': response_data
                }
            )
            sns.publish(
                TopicArn=env_topic,
                Message='License photo validation FAILED',
                Subject='License photo validation FAILED',
            )

    except Exception as e:
        print(f"Error sending request: {str(e)}")
        return {
            "statusCode": 500,
            "body": f"Internal Lambda Error: {str(e)}"
        }