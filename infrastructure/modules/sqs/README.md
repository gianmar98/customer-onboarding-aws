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

None yet — the queue ARN/URL are not exposed. Add outputs here when another module needs to produce to or consume from the queue (see the cross-module pattern in the root `CLAUDE.md`).

## Notes

- Both queues are standard (not FIFO), matching the lab steps.
- The module call in `envs/dev/main.tf` passes the names directly without the `${local.env_suffix}` the other modules use, so dev/prod would collide on queue names. Add the suffix before standing up a second env.