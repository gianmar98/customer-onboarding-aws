# API Gateway Module

Provisions `ValidateLicenseApi`, an HTTP API exposing `POST /license`, proxying to the validation Lambda.

## Resources

- `aws_apigatewayv2_api.validate_license_api` — HTTP API (`protocol_type = "HTTP"`). HTTP APIs are always Regional (no edge-optimized/private choice like REST APIs).
- `aws_apigatewayv2_integration.validation_integration` — `AWS_PROXY` integration, `payload_format_version = "2.0"`, targeting `var.validate_lambda_invoke_arn` (the validation Lambda's invoke ARN, passed in from the lambda module via the env).
- `aws_apigatewayv2_route.post_license` — routes `POST /license` to the integration.
- `aws_apigatewayv2_stage.default` — the `$default` stage, `auto_deploy = true` (changes go live immediately, no manual deployment step). `default_route_settings` caps throughput at `throttling_rate_limit = 5` req/s with `throttling_burst_limit = 10` — defence in depth behind the route's IAM authorization (see Notes).
- `aws_lambda_permission.apigw_invoke_validate` — grants `apigateway.amazonaws.com` permission to invoke the validation Lambda, scoped to `${execution_arn}/*/*` (`statement_id = "AllowAPIGatewayInvoke"`).

## Inputs

| Name | Type | Description |
|---|---|---|
| `validate_api_gw_name` | `string` | Name of the HTTP API |
| `validate_lambda_invoke_arn` | `string` | Invoke ARN of the validation Lambda — target of the `AWS_PROXY` integration |
| `validate_lambda_function_name` | `string` | Function name of the validation Lambda — used by the invoke permission |

## Outputs

| Name | Description |
|---|---|
| `validate_license_api_arn` | ARN of the HTTP API |
| `validate_license_api_name` | Name of the HTTP API — flows into the lambda module as the submit-license Lambda's `VALIDATE_LICENSE_API` env var |
| `license_validation_invoke_url` | Invoke URL for `POST /license` — flows into the lambda module as the submit-license Lambda's `VALIDATE_LICENSE_API_URL` env var (the endpoint it POSTs to) |

## Cross-module dependencies

`validate_lambda_invoke_arn` and `validate_lambda_function_name` come from the lambda module's outputs, routed through the env (`module.document_lambda.validation_lambda_invoke_arn` → `var.validate_lambda_invoke_arn`); this module's own outputs flow back into the lambda module for the submit-license Lambda's env vars. Names are **not** env-suffixed by the caller (unlike most other modules).

## Notes

- This is the **internal mock 3rd-party validator**, called server-side by `submit_license.py` — not a browser-facing API. The frontend never calls it directly.
- **`POST /license` requires IAM auth** (`authorization_type = "AWS_IAM"`). An unsigned request gets `403` before the integration runs, so any test call needs `--aws-sigv4` (see the command below). The only caller is `submit_license.py`, which SigV4-signs via `botocore.auth.SigV4Auth`.
- **`license_validation_invoke_url` must keep its `trimsuffix`.** The `$default` stage's `invoke_url` ends in `/`, so naive interpolation yields `…amazonaws.com//license`. HTTP API normalizes the double slash for *routing* but builds the IAM authorization ARN from the raw path (`…/POST//license`), which doesn't match the grant — a 403 that only appears once `authorization_type = "AWS_IAM"` is on.
- **Three things must agree or every call 403s**: the route's `authorization_type`, the `execute-api:Invoke` grant on the caller's role (`modules/lambda/lambda_policies.tf`, scoped to `${execution_arn}/*/POST/license`), and the signature itself. Scope the grant against `execution_arn` — the API's plain `arn` is a different ARN and will not work.
- Stage throttling (5 req/s, burst 10) is still there as defence in depth.
- Test invoke (must be signed — a plain `curl` returns `403 Missing Authentication Token`):

  ```bash
  curl -X POST "$API_ENDPOINT_URL" \
    --aws-sigv4 "aws:amz:us-east-1:execute-api" \
    --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
    -H "x-amz-security-token: $AWS_SESSION_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"driver_license_id": "S123456579010", "validation_override": true}'
  ```

  The `x-amz-security-token` header is only needed for temporary credentials. Your own IAM identity needs `execute-api:Invoke` too — the policy in `modules/lambda/` grants it to the submit-license role only.