module "customer_metadata_table" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "5.5.0"

  name     = var.customer_metadata_dynamo_db_table_name
  hash_key = var.customer_metadata_table_hash_partition_key #Partition Key
  #range_key = "" #Sort Key not required

  attributes = [
    {
      name = var.customer_metadata_table_hash_partition_key #Partition Key
      type = "S"                                            # String
    }
  ]
  billing_mode = "PROVISIONED" #Capacity Mode
  table_class  = var.customer_metadata_table_class

  read_capacity  = var.customer_metadata_table_RCU
  write_capacity = var.customer_metadata_table_WCU



  autoscaling_enabled = var.customer_metadata_table_autoscaling_enabled

  autoscaling_read = {
    scale_in_cooldown  = 50
    scale_out_cooldown = 40
    target_value       = var.customer_metadata_table_target_scaling_val
    min_capacity       = var.customer_metadata_table_min_RWcapacity
    max_capacity       = var.customer_metadata_table_max_RWcapacity
  }

  autoscaling_write = {
    scale_in_cooldown  = 50
    scale_out_cooldown = 40
    target_value       = var.customer_metadata_table_target_scaling_val
    min_capacity       = var.customer_metadata_table_min_RWcapacity
    max_capacity       = var.customer_metadata_table_max_RWcapacity
  }
}