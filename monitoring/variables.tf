variable "aws_region" {
  description = "The AWS region the infrastructure will live and logs data from"
  type = string
}

variable "project_name" {
  description = "Prefix fo resource names"
  type = string
}

variable "alert_emails" {
  description = "Addresses that receives every alert (all alarms share one SNS topic)"
  type = list(string)
}

variable "log_legacy_ec2_id" {
  description = "The ID of the legacy EC2 instance, from compute/ec2 module"
  type = string
}

variable "db_identifier" {  # Why: So that the db log group can follow RDS naming convention
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

variable "cwagent_namespace" {
  description = "Cloudwatch namespace the agent publishes to"
  type = string
  default = "CWAgent"
}

# Must equal the mount path in the EC2 folder, or the alarm never finds data.
variable "documents_volume_mount_path" {
  description = "Where the documents disk is mounted"
  type = string

  validation {
    condition = startswith(var.documents_volume_mount_path, "/")
    error_message = "documents_volume_mount_path must be an absolute path"
  }
}

variable "log_legacy_dlm_policy_id" {
  description = "The ID of the Data Lifecycle Manager (DLM) that snapshots the documents volume"
  type = string
}

variable "session_manager_logs_retention_days" {
  description = "How long in days EC2 session manager logs remain in its Cloudwatch Log group"
  type = number

  validation {   # Why: Retension values other than those in the list will fail at apply
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.session_manager_logs_retention_days)
    error_message = "Cloudwatch Logs only accepts specific retension values, pick from them to use"
  }
}

variable "app_logs_retention_days" {
  description = "How long in days legacy app logs remain in its Cloudwatch Log group"
  type = number

  validation {   # Why: Retension values other than those in the list will fail at apply
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.app_logs_retention_days)
    error_message = "Cloudwatch Logs only accepts specific retension values, pick from them to use"
  }
}