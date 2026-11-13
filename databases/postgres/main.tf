resource "aws_security_group" "log_legacy_db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "SG for legacy RDS, allowing only inbound from legacy instance only by referencing its SG"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "log_legacy_db_from_ec2_sg_rule" {
  description       = "Database traffic from legacy EC2 instance"
  security_group_id = aws_security_group.log_legacy_db_sg.id

  # References the instance SG, not a CIDR, so access follows the instance even if its IP changes.
  referenced_security_group_id = var.log_legacy_ec2_sg_id
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
}


resource "aws_db_subnet_group" "log_legacy_db_subnet_group" {
  description = "The DB tier subnets for the legacy infrastructure, must span at least 2 AZs even if multiAZ is disabled"
  name        = "${var.project_name}-db-subnet-group"
  subnet_ids  = var.db_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}


resource "aws_db_instance" "log_legacy_db_instance" {
  identifier = var.db_identifier
  # Why: same AZ as the EC2 instance (shared local.legacy_az in the root) to avoid cross-AZ transfer charges.
  availability_zone = var.db_availability_zone
  instance_class    = var.db_instance_class
  # Why: Postgres for the company's rich GPS/fleet-tracking features.
  engine         = "postgres"
  engine_version = var.db_engine_version
  # Why: legacy DB is single-AZ, so an automatic upgrade is a full outage that counts against availability.
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  # Why: For critical security issues or when a version reaches end of support, RDS applies a minor upgrade even if the option is false.
  maintenance_window = var.db_maintenance_window
  allow_major_version_upgrade = false

  allocated_storage = var.allocated_storage_gb
  storage_type      = "gp3"
  # Encryption can only be chosen at creation; adding it later means snapshot, encrypted copy, restore.
  storage_encrypted = var.storage_encrypted

  db_name  = var.db_name
  username = var.db_master_username
  password = var.db_master_password

  db_subnet_group_name   = aws_db_subnet_group.log_legacy_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.log_legacy_db_sg.id]

  # Why: single-AZ matches the legacy design; this also lets availability_zone be set (not allowed with Multi-AZ).
  multi_az                = false
  publicly_accessible     = false
  backup_retention_period = var.backup_retention_period
  backup_window = var.db_backup_window
  copy_tags_to_snapshot = true
  delete_automated_backups = false
  # As this code is just for my efficiency, and will be teared down and built up as needed
  deletion_protection = false

  skip_final_snapshot = var.skip_final_snapshot
  # Why: the provider requires a snapshot name when skip_final_snapshot is false, or destroy fails.
  # Note: Two destructions can cause snapshots names collision if the first is not deleted before second destruction.
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-db-final-snapshot"

  enabled_cloudwatch_logs_exports = local.rds_log_exports
  depends_on = [aws_cloudwatch_log_group.log_legacy_rds_log_groups] # So the log groups can before db instance is created, to avoid "ResourceAlreadyExistsException" error


  tags = {
    Name = "${var.project_name}-db-instance"
  }
}

# Why: So I can control rentention days
resource "aws_cloudwatch_log_group" "log_legacy_rds_log_groups" {
  for_each = toset(local.rds_log_exports)

  name = "/aws/rds/instance/${var.db_identifier}/${each.key}"
  retention_in_days = var.cw_log_groups_retention_days
}