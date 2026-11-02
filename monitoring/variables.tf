variable "project_name" {
  description = "Prefix fo resource names"
  type = string
}

variable "alert_email" {
  description = "Address that receives every alert (all alarms share one SNS topic)"
  type = string
}

variable "log_legacy_ec2_id" {
  description = "The ID of the legacy EC2 instance, from compute/ec2 module"
  type = string
}

variable "log_legacy_db_instance_identifier" {
  description = "The legacy RDS instance identifier (cloudwatch dimension and event source use this, not ARN)"
  type = string
}

variable "health_check_fqdn" {
  description = "The portal's public web address, so the check tests the same path customers use (DNS -> EIP -> app)"
  type = string
}

variable "health_check_path" {
  type = string
}

variable "db_health_check_path" {
  description = "Path of the developer-built endpoint that touches the DB"
  type = string
}

variable "rds_free_storage_threshold_gib" {
  description = "Alarms when free storage drops below this"
  type = number
}

variable "rds_max_connections" {
  type = number
}