# Step Function Module

Provisions the `DocumentStateMachine` that orchestrates the four-step document pipeline, plus the S3 → EventBridge → Step Functions trigger chain that starts it.

This module is what turns the unzip / write-to-dynamo / compare-faces / compare-details Lambdas (defined in `modules/lambda/`) into an actual running pipeline — those four functions have no triggers of their own.

> Only `document_state_machine_name` is env-stamped by the caller. `document_state_machine_iam_role_name` is passed in **without** the suffix (same pattern as most of the lambda module's role names).

## Files

- `DocumentStateMachine.tf` — the state machine + its IAM role/policy, the bucket's EventBridge notification toggle, and the EventBridge rule/target/role that start an execution.

## Resources

### State machine

- `aws_sfn_state_machine.document_state_machine` — Standard workflow, definition inlined as a heredoc. Flow:

  ```
  UnzipLambdaFunction          → ResultPath $.application
  WriteToDynamoLambdaFunction  → ResultPath $.validation
  PerformParallelChecks        → ResultPath $.parallelResults
    ├─ CompareFacesLambdaFunction
    └─ CompareDetailsLambdaFunction
  ValidateSQSQueue             → arn:aws:states:::sqs:sendMessage (End)
  ```

  The `ResultPath` values matter — each Lambda reads the previous step's output off the accumulated state, not off a bare payload. `write_to_dynamo_lambda.py` and both compare handlers read `event['application']['app_uuid']` (written by `UnzipLambdaFunction`) and `event['detail']['bucket']['name']` (carried through from the original EventBridge event), so **changing a `ResultPath` breaks the handlers downstream of it.**

  The final `ValidateSQSQueue` state sends `{driver_license_id, validation_override, uuid}` to `LicenseQueue`, pulled from `$.validation.*` — the write-to-dynamo Lambda's return value. That message is what the submit-license Lambda polls.

  `tracing_configuration { enabled = true }` turns on AWS X-Ray. Traces appear under **CloudWatch → Application Signals (APM) → Traces**, showing the trace map of states/services plus a per-state segment timeline. Execution **logging is not configured**, so the `loggingConfiguration` level is `OFF` — the console execution history is the only step-level record besides X-Ray.

- `aws_iam_role.document_state_machine_iam_role` — assume-role trust for `states.amazonaws.com`.
- `aws_iam_role_policy.document_state_machine_policy` — **inline** policy (`AllowStepFunctionsToAssumeRole`) granting `lambda:InvokeFunction` on exactly the four pipeline Lambda ARNs, `sqs:SendMessage` on `var.validate_sqs_queue_arn`, and the four X-Ray write/sampling actions (`PutTraceSegments`, `PutTelemetryRecords`, `GetSamplingRules`, `GetSamplingTargets`) on `*` — X-Ray does not support resource-level permissions on these.

### Trigger chain

- `aws_s3_bucket_notification.bucket_notification` — sets `eventbridge = true` on the document bucket, so object events are published to the default event bus.
- `aws_cloudwatch_event_rule.zipped_object_created` — `<state_machine_name>-zipped-object-created`. Matches `aws.s3` / `Object Created` for the document bucket, filtered with a single `wildcard` matcher: `zipped/*.zip`.
- `aws_cloudwatch_event_target.sfn_target` — points the rule at the state machine, assuming the role below.
- `aws_iam_role.eventbridge_sfn_role` — `<state_machine_iam_role_name>-eventbridge`, trust for `events.amazonaws.com`.
- `aws_iam_role_policy.eventbridge_start_execution` — `states:StartExecution` scoped to this state machine only.

## Inputs

| Name | Type | Description |
|---|---|---|
| `document_state_machine_name` | `string` | State machine name (env-suffixed by the caller). Also prefixes the EventBridge rule name. |
| `document_state_machine_iam_role_name` | `string` | State machine IAM role name — **not** env-suffixed by the caller. Also prefixes the EventBridge role name (`-eventbridge`). |
| `current_account_id` | `string` | Account ID — declared, currently unused by the resources |
| `current_region` | `string` | Region — declared, currently unused by the resources |
| `unzip_lambda_function_arn` | `string` | Step 1 Lambda ARN — `Resource` of `UnzipLambdaFunction`, scoped in the invoke policy |
| `unzip_lambda_function_name` | `string` | Step 1 Lambda name — passed in for reference |
| `write_to_dynamo_lambda_arn` | `string` | Step 2 Lambda ARN — `Resource` of `WriteToDynamoLambdaFunction`, scoped in the invoke policy |
| `write_to_dynamo_lambda_name` | `string` | Step 2 Lambda name — passed in for reference |
| `compare_faces_lambda_function_arn` | `string` | Step 3(a) Lambda ARN — parallel branch, scoped in the invoke policy |
| `compare_faces_lambda_function_name` | `string` | Step 3(a) Lambda name — passed in for reference |
| `compare_details_lambda_function_arn` | `string` | Step 3(b) Lambda ARN — parallel branch, scoped in the invoke policy |
| `compare_details_lambda_function_name` | `string` | Step 3(b) Lambda name — passed in for reference |
| `validate_sqs_queue_url` | `string` | `LicenseQueue` URL — `QueueUrl` parameter of the `ValidateSQSQueue` state |
| `validate_sqs_queue_arn` | `string` | `LicenseQueue` ARN — scopes `sqs:SendMessage` in the state machine policy |
| `document_s3_bucket_arn` | `string` | Bucket ARN — declared, currently unused by the resources |
| `document_s3_bucket_name` | `string` | Bucket name — matched in the EventBridge rule's event pattern |
| `document_s3_bucket_id` | `string` | Bucket ID — target of `aws_s3_bucket_notification` |

## Outputs

| Name | Description |
|---|---|
| `document_state_machine_name` | Name of the state machine |
| `document_state_machine_arn` | ARN of the state machine |

Neither is consumed by another module today.

## Cross-module dependencies

```
modules/lambda/outputs.tf → unzip / write_to_dynamo / compare_faces / compare_details ARNs + names
modules/sqs/outputs.tf    → sqs_license_queue_arn, sqs_url
modules/s3/outputs.tf     → document_bucket_arn, document_bucket_name, document_bucket_id
envs/dev/main.tf          → stamps env suffix on the state machine name, passes everything in
```

## Notes

- **Don't broaden the `zipped/*.zip` filter in the event rule.** The unzip Lambda writes its output back to `unzipped/` in the same bucket; a wider filter would make every extracted file start a new execution, in a loop.
- **Use one `wildcard` matcher, not a `prefix` + `suffix` array.** EventBridge **ORs** the elements of a matcher array, so `key = [{prefix = "zipped/"}, {suffix = ".zip"}]` reads as "anything under `zipped/` **or** any `.zip` anywhere" — broadening the filter instead of narrowing it, which is exactly how you get the loop above. Verify any change with `aws events test-event-pattern` before applying.
- The wildcard also fixed a live bug the bare `zipped/` prefix had: it matched the `zipped/` key itself, which is the empty placeholder object `modules/s3/` creates (`aws_s3_object.zipped_prefix`). Terraform creating that marker started an execution that could only fail.
- **This module owns the bucket's only `aws_s3_bucket_notification`.** The lambda module's version (for the monolithic `s3_upload.py` function) is commented out — a bucket accepts exactly one notification configuration, so re-enabling it there would fight this one on every apply. If the monolithic Lambda ever needs a trigger again, add it as a second EventBridge rule rather than a second bucket notification.
- **X-Ray tracing fails silently without the IAM grant.** `tracing_configuration.enabled = true` alone produces zero traces — Step Functions emits segments using this role, so dropping the `xray:*` statement leaves executions running normally with nothing ever appearing in CloudWatch Traces. The two must be changed together.
- Of the four pipeline Lambdas, **only `WriteToDynamoLambdaFunction` is traced** (Active tracing + Powertools layer — see `modules/lambda/README.md`). It expands in the trace map to show `## lambda_handler` with nested S3/DynamoDB subsegments; the other three appear as flat call targets.
- The parallel branches share no state — `CompareFaces` and `CompareDetails` both read from `$.application` / `$.detail` and write independently to DynamoDB.
- Both compare handlers **raise** on a mismatch, which fails the branch and therefore the whole `PerformParallelChecks` state. **`Catch` / `Retry` are not wired up yet (planned)** — until they are, a mismatch aborts the execution before `ValidateSQSQueue` runs, so no SQS message is sent for a failed application and the failure surfaces only via the SNS notification the handler publishes before raising.