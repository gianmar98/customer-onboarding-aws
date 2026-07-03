# SQS Module

Provisions the `LicenseQueue` standard queue and its `LicenseDeadLetterQueue` dead-letter queue.

## Resources

- `aws_sqs_queue.license_queue` — standard queue (`fifo_queue = false`), `visibility_timeout_seconds = 300`, with a `redrive_policy` sending messages to the DLQ after `maxReceiveCount = 5` failed receives
- `aws_sqs_queue.license_dead_letter_queue` — standard DLQ (`fifo_queue = false`)
- `aws_sqs_queue_redrive_allow_policy.terraform_queue_redrive_allow_policy` — scopes the DLQ to only accept redrives from `license_queue` (`redrivePermission = "byQueue"`)

## Inputs

| Name | Type | Description |
|---|---|---|
| `sqs_queue_name` | `string` | Name of the main SQS queue |
| `sqs_dlq_name` | `string` | Name of the dead-letter queue |

## Outputs

| Name | Description |
|---|---|
| `sqs_license_queue_arn` | ARN of `license_queue` — consumed by the lambda module's event source mapping + SQS IAM policy (flows through the env as `sqs_license_queue_arn`) |
| `sqs_license_dead_letter_queue_arn` | ARN of `license_dead_letter_queue` |
| `sqs_license_queue_name` | Name of `license_queue` |
| `sqs_url` | URL of `license_queue` — flows through the env into the document Lambda as its `SQS_URL` env var (the queue it writes the validation message to) |

## Notes

- Both queues are standard (not FIFO), matching the lab steps.
- The queue sits between the two Lambdas: the **document Lambda** writes to it (via the `sqs_url` output → its `SQS_URL` env var), and the **submit-license Lambda** polls it. The env wires `module.sqs.sqs_license_queue_arn` into `module.document_lambda`, where it scopes the submit-license SQS poll policy and is the `event_source_arn` of the event source mapping; `module.sqs.sqs_url` is wired in as the document Lambda's `SQS_URL`.
- The module call in `envs/dev/main.tf` passes the queue names directly without the `${local.env_suffix}` the other modules use, so dev/prod would collide on queue names. Add the suffix before standing up a second env.