# DynamoDB Module

Provisions the `CustomerMetadataTable` DynamoDB table with provisioned capacity and optional autoscaling.

## Resources

- `module.customer_metadata_table` — `terraform-aws-modules/dynamodb-table/aws` v5.5.0
  - Billing mode: `PROVISIONED`
  - Partition key: `APP_UUID` (String)
  - Autoscaling cooldowns: 50s scale-in, 40s scale-out
  - Read and write autoscaling share the same min/max/target values

## Inputs

| Name | Type | Notes |
|---|---|---|
| `customer_metadata_dynamo_db_table_name` | `string` | Table name |
| `customer_metadata_table_hash_partition_key` | `string` | Partition key name (used as both `hash_key` and the attribute definition) |
| `customer_metadata_table_class` | `string` | `STANDARD` or `STANDARD_INFREQUENT_ACCESS` (validated) |
| `customer_metadata_table_RCU` | `number` | Min 2 |
| `customer_metadata_table_WCU` | `number` | Min 2 |
| `customer_metadata_table_autoscaling_enabled` | `bool` | See warning below |
| `customer_metadata_table_min_RWcapacity` | `number` | Min 2 |
| `customer_metadata_table_max_RWcapacity` | `number` | Max 20 |
| `customer_metadata_table_target_scaling_val` | `number` | Target % (1–100) |

## Outputs

| Name | Description |
|---|---|
| `customer_metadata_table_name` | Name of the CustomerMetadata DynamoDB table |
| `customer_metadata_table_arn` | ARN of the CustomerMetadata DynamoDB table |

## ⚠️ Autoscaling toggle warning

Toggling `customer_metadata_table_autoscaling_enabled` after creation **recreates the table** (data loss). To preserve data, run `terraform state mv` before applying:

```bash
terraform state mv \
  module.customer_metadata_dynamo_db_table.module.customer_metadata_table.aws_dynamodb_table.this \
  module.customer_metadata_dynamo_db_table.module.customer_metadata_table.aws_dynamodb_table.autoscaled
```

(Adjust source/destination addresses based on the direction of the toggle — the upstream module changes the resource name when autoscaling is enabled vs. disabled.)