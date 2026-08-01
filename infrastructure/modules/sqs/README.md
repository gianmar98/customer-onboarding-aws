# SQS Module

Provisions the `LicenseQueue` standard queue and its `LicenseDeadLetterQueue` dead-letter queue.

## Resources

- `aws_sqs_queue.license_queue` — standard queue (`fifo_queue = false`), `visibility_timeout_seconds = 120`, `sqs_managed_sse_enabled = true`, with a `redrive_policy` sending messages to the DLQ after `maxReceiveCount = 3` failed receives
- `aws_sqs_queue.license_dead_letter_queue` — standard DLQ (`fifo_queue = false`), `sqs_managed_sse_enabled = true`
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
| `sqs_url` | URL of `license_queue` — flows through the env into the stepFunction module as `validate_sqs_queue_url`, the `QueueUrl` of the state machine's final `ValidateSQSQueue` state. Also still passed into the lambda module as `var.sqs_url`, where its only references are commented-out `SQS_URL` env vars on the retired document Lambda |

## Notes

- Both queues are standard (not FIFO), matching the lab steps.
- **`sqs_managed_sse_enabled = true` is a no-op, deliberately.** AWS enables SSE-SQS on new queues by default, so both queues were already encrypted before this was written and the plan showed no changes. It's declared because the attribute is `Optional+Computed`: left unset, Terraform records whatever the API reports and never compares it, so encryption disabled outside Terraform would never appear in a plan. Declared, it does.
- **The redrive policy only works because `submit_license.py` re-raises on error.** SQS treats *any* normal return as success and deletes the message — a handler that catches an exception and returns a 500 dict makes the DLQ unreachable. See `modules/lambda/README.md`.
- **`visibility_timeout_seconds` does double duty**: it must be ≥ 6× the consumer's function timeout (`var.lambda_functions_timeout = 20s`) so a slow invocation can't have its message redelivered mid-processing, *and* it sets the retry spacing. At 120s × `maxReceiveCount = 3`, the arithmetic says ~4 minutes; **measured end-to-end it was ~6 minutes** (~5m20s from first receive), the difference being event-source-mapping poll latency. Raising either value directly lengthens that.
- The DLQ has no CloudWatch alarm on `ApproximateNumberOfMessagesVisible`, so messages land there unnoticed — the top open item in `FABLEfeedback.md` §4.1.
- The queue sits between the state machine and the submit-license Lambda: **`DocumentStateMachine`'s final `ValidateSQSQueue` state writes to it** (`module.sqs.sqs_url` → the stepFunction module's `validate_sqs_queue_url`), and the **submit-license Lambda** polls it. The env also wires `module.sqs.sqs_license_queue_arn` into `module.document_lambda`, where it scopes the submit-license SQS poll policy and is the `event_source_arn` of the event source mapping. The retired monolithic document Lambda used to be the writer via an `SQS_URL` env var — that wiring is commented out.
- The module call in `envs/dev/main.tf` passes the queue names directly without the `${local.env_suffix}` the other modules use, so dev/prod would collide on queue names. Add the suffix before standing up a second env.