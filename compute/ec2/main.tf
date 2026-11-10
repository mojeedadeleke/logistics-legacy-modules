resource "aws_security_group" "log_legacy_ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "SG for the single legacy instance"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

resource "aws_iam_role" "log_legacy_ec2_role" {
  name = "${var.project_name}-ec2-session-manager-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role
}

resource "aws_iam_role_policy_attachment" "log_legacy_ec2_session_manager_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.log_legacy_ec2_role.name
}

resource "aws_iam_role_policy_attachment" "log_legacy_ec2_cwagent_policy" {
  role = aws_iam_role.log_legacy_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "log_legacy_ec2_instance_profile" {
  name = "${var.project_name}-ec2-instance-profile"
  role = aws_iam_role.log_legacy_ec2_role.name
}

resource "aws_instance" "log_legacy_ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.us_east_1a_web_subnet_id
  iam_instance_profile   = aws_iam_instance_profile.log_legacy_ec2_instance_profile.name
  vpc_security_group_ids = [aws_security_group.log_legacy_ec2_sg.id]

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = var.root_volume_type
  }

  tags = {
    Name = "${var.project_name}-instance"
    Role = "Web+App"
  }
}

# So that any DNS record that points to the instance does not break after stop/start (including resizes)
resource "aws_eip" "log_legacy_ec2_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-ec2-eip"
  }

  depends_on = [var.igw_id]
}

# Explicit assoc so that if the instance is replaced, only this assoc is recreated while the EIP remains intact
resource "aws_eip_association" "log_legacy_ec2_eip_assoc" {
  allocation_id = aws_eip.log_legacy_ec2_eip.id
  instance_id   = aws_instance.log_legacy_ec2.id
}

resource "aws_ebs_volume" "documents_volume" {
  availability_zone = var.documents_volume_az # To be in the same AZ as the instance (us-east-1a)
  size              = var.documents_volume_size_gb
  type              = var.documents_volume_type

  tags = {
    Name = "${var.project_name}-documents-volume"
    SnapshotPolicy = "documents-daily"
  }
}

resource "aws_volume_attachment" "documents_volume_attachment" {
  device_name = var.documents_volume_device_name
  volume_id   = aws_ebs_volume.documents_volume.id
  instance_id = aws_instance.log_legacy_ec2.id
}

resource "aws_iam_role" "log_legacy_dlm_role" {
  name = "${var.project_name}-docs-volume-dlm-role"
  assume_role_policy = data.aws_iam_policy_document.dlm_assume.json
}

resource "aws_iam_role_policy" "log_legacy_dlm_role_policy" {
  name = "${var.project_name}-dlm-role-permissions"
  role = aws_iam_role.log_legacy_dlm_role.id
  policy = data.aws_iam_policy_document.dlm_role_permissions.json
}

resource "aws_dlm_lifecycle_policy" "log_legacy_documents_volume_snapshots" {
  description = "Daily snapshots of the documents volume"
  execution_role_arn = aws_iam_role.log_legacy_dlm_role.arn
  state = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]
    target_tags = {SnapshotPolicy = "documents-daily"}

    schedule {
      name = "daily-documents-volume-snapshot"
      create_rule {
        interval = 24
        interval_unit = "HOURS"
        times = ["03:00"]  # UTC
      }
      retain_rule {
        count = var.documents_volume_snapshot_retain_counts
      }
      copy_tags = true
    }
  }
}



resource "aws_vpc_security_group_egress_rule" "log_legacy_ec2_ipv4_allow_all_outbound" {
  description       = "Allow all outbound over IPv4"
  security_group_id = aws_security_group.log_legacy_ec2_sg.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "log_legacy_ec2_ipv4_http_from_anywhere" {
  description       = "HTTP from the internet over IPv4"
  security_group_id = aws_security_group.log_legacy_ec2_sg.id

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "log_legacy_ec2_ipv4_https_from_anywhere" {
  description       = "HTTPS inbound from internet over IPv4"
  security_group_id = aws_security_group.log_legacy_ec2_sg.id

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "log_legacy_ec2_ipv6_allow_all_outbound" {
  description       = "Allow all outbound over IPv6"
  security_group_id = aws_security_group.log_legacy_ec2_sg.id

  cidr_ipv6   = "::/0"
  ip_protocol = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "log_legacy_ec2_ipv6_http_from_anywhere" {
  description       = "HTTP from the internet over IPv6"
  security_group_id = aws_security_group.log_legacy_ec2_sg.id

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv6   = "::/0"
}

resource "aws_vpc_security_group_ingress_rule" "log_legacy_ec2_ipv6_https_from_anywhere" {
  description       = "HTTPS from the internet over IPv6"
  security_group_id = aws_security_group.log_legacy_ec2_sg.id

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv6   = "::/0"
}