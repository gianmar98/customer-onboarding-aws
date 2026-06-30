#Generate me a hello world function
import json

#DynamoDB
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE'])# add ENV variable TABLE

#API GW
api_gw = boto3.client('apigatewayv2')


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
    # Your business logic here
    output_data = {
        "driver_license_id": {driver_license_id},
        "validation_override": {validation_override},
        "uuid": {uuid}
    }

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps(output_data)
    }