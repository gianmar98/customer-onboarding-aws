# Portions of this code are adapted from AWS Training and Certification:
# "Capstone Project: Building a Customer Onboarding App - Lab 07".
# Original lab code (c) Amazon Web Services, Inc. Adapted by Giancarlo Martinez
# for ACI Capstone 1.

"Fake driver license API responds with the validation_override"
import json

def lambda_handler(event, context):
    "Takes API gateway event and responds with the validation_override"
    body = event['body']
    body_json = json.loads(body)
    license_id = body_json['driver_license_id']
    override_parameter = body_json['validation_override']

    response = {}
    response['statusCode'] = 200
    response['body'] = json.dumps(override_parameter)
    print(f"Response: {response}")
    return response
