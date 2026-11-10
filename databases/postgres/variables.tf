variable "project_name" {
  description = "The name of the project, used as a prefix in the resource names and tags"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID from the network module, passed in by the root config"
  type        = string
}

variable "db_subnet_ids" {
  description = "List of db tier subnet IDs from network module, and the network output is an AZ-keyed map. Must span at least 2 AZs, even if multiAZ is disabled"
  type        = list(string)

  validation {
    condition     = length(var.db_subnet_ids) >= 2
    error_message = "The db_subnet_ids variable needs at least 2 subnet ids in two different AZs"
  }
}

# The prod root module derives this from local.legacy_az, shared among the EC2 instance, the documents volume and this DB instance
variable "db_availability_zone" {
  description = "AZ for the single AZ DB instance, both db and app instances should be in the same AZ, to avoid cross AZs data transfer charges"
  type        = string
}

variable "log_legacy_ec2_sg_id" {
  description = "The ID of legacy instance SG (from compute module), for RDS instance SG to reference, not any CIDR"
  type        = string

  validation {
    condition     = startswith(var.log_legacy_ec2_sg_id, "sg-")
    error_message = "The log_legacy_ec2_sg_id variable must be a security group ID starting with sg-."
  }
}

variable "db_engine_version" {
  description = "The version of the chosen db engine"
  type        = string
}

variable "db_instance_class" {
  description = "The database instance class to use"
  type        = string

  validation {
    condition     = startswith(var.db_instance_class, "db.")
    error_message = "The db_instance_class variable must start with db. (for example db.m5.large)."
  }
}

variable "allocated_storage_gb" {
  description = "The legacy database storage size in GB"
  type        = number

  validation { # Why: RDS for PostgreSQL gp2/gp3 accepts 20 to 65536 GiB.
    condition     = var.allocated_storage_gb >= 20 && var.allocated_storage_gb <= 65536
    error_message = "Allocated_storage_gb must be between 20 and 65536 for PostgreSQL on gp2/gp3."
  }
}

variable "auto_minor_version_upgrade" {
  description = "Let RDS apply minor engine upgrades in the maintenance window. false means upgrades are deliberate; RDS still forces critical security and end-of-support upgrades"
  type        = bool
}

variable "db_maintenance_window" {
  description = "Weekly maintenance window in UTC (ddd:hh24:mi-ddd:hh24:mi). Choose a quiet period; this is when RDS runs required upgrades even with auto minor upgrade false"
  type        = string
}

variable "db_backup_window" {
  description = "Daily backup window"
  type = string
}

variable "storage_encrypted" {
  description = "Encrypt DB storage. Can only be chosen at creation; adding it later means snapshot, encrypted copy, restore"
  type        = bool
  default     = true
}

variable "db_port" {
  description = "DB port. Shared by the instance and its security group rule so the two cannot disagree"
  type        = number
  default     = 5432

  validation {
    condition     = var.db_port >= 1150 && var.db_port <= 65535
    error_message = "DB port must be between 1150 and 65535"
  }
}

variable "backup_retention_period" {
  description = "Days of automated backups. Set explicitly because the provider docs (0) and AWS API docs (1) disagree on the default. 0 disables automated backups"
  type        = number

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "backup_retention_days must be between 0 and 35."
  }
}

variable "skip_final_snapshot" {
  description = "Skip the snapshot taken on deletion. When false, main.tf must set final_snapshot_identifier or destroy fails"
  type        = bool
}

variable "db_name" {
  description = "Name of the initial database created at first launch" # RDS also always creates a database named postgres
  type        = string

  validation {
    condition     = length(regexall("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.db_name)) == 1
    error_message = "The db_name variable must be 1-63 letters, numbers or underscores, starting with a letter"
  }
}

variable "db_master_username" {
  description = "The master database username, marked sensitive"
  type        = string
  sensitive   = true

  validation {
    condition     = length(regexall("^[A-Za-z][A-Za-z0-9_]{0,15}$", var.db_master_username)) == 1
    error_message = "The db_master_username variable must 1-16 letters, numbers or underscore, starting with a letter"
  }
}

variable "db_master_password" {
  description = "The database password, marked sensitive"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_master_password) >= 8 && length(var.db_master_password) <= 128
    error_message = "The db_master_password variable must be 8-128 characters"
  }

  validation {
    condition     = length(regexall("[/\"@]", var.db_master_password)) == 0
    error_message = "The db_master_password variable must not contain /\"@."
  }
}