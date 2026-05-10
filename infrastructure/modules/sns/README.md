# SNS Module

Provisions the `ApplicationNotifications` SNS topic and an email subscription.

## Resources

- `module.app_notification_sns` — `terraform-aws-modules/sns/aws` v7.1.0
  - Encrypted with the supplied KMS key (default: `alias/aws/sns`, AWS-managed)
- `aws_sns_topic_subscription.personal_email_notification` — email subscription on the topic

## Inputs

| Name | Type | Description |
|---|---|---|
| `app_notification_sns_name` | `string` | Topic name |
| `app_notification_kms_key` | `string` | KMS key id or alias used to encrypt the topic (e.g. `alias/aws/sns`) |
| `app_notification_email_endpoint` | `string` | Email address to subscribe |

## Outputs

| Name | Description |
|---|---|
| `sns_topic_arn` | ARN of the application notifications SNS topic |
| `sns_topic_name` | Name of the application notifications SNS topic |

## Notes

- AWS sends a confirmation email to `app_notification_email_endpoint`. The subscription will not deliver messages until the recipient clicks the confirmation link.
- To inspect the AWS-managed KMS key: `aws kms describe-key --key-id alias/aws/sns --region us-east-1`.