resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
  # Uses default SNS policy
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.alert_emails)
  topic_arn = aws_sns_topic.alerts.arn
  protocol = "email"
  endpoint = each.value
}

resource "aws_cloudwatch_metric_alarm" "log_legacy_ec2_system_status" {
  alarm_name = "${var.project_name}-ec2-system-status"
  namespace = "AWS/EC2"
  metric_name = "StatusCheckFailed_System"
  dimensions = {InstanceId = var.log_legacy_ec2_id}
  statistic = "Maximum"
  period = 60 # 1-minute by default
  evaluation_periods = 2 # two bad minutes in a row, so one blip doesn't move the instance
  datapoints_to_alarm = 2
  threshold = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data = "missing" # a stopped instance emits no data; that isn't a hardware fault

  # The automate ARN is a special action, not a real resource: it moves the instance to
  # healthy hardware, keeping instance ID, EIP and EBS volumes (so the documents disk survives).
  alarm_actions = [
    "arn:aws:automate:us-east-1:ec2:recover",
    aws_sns_topic.alerts.arn,
  ]
  ok_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "log_legacy_ec2_instance_status" {
  alarm_name = "${var.project_name}-ec2-instance-status"
  namespace = "AWS/EC2"
  metric_name = "StatusCheckFailed_Instance"
  dimensions = {InstanceId = var.log_legacy_ec2_id}
  statistic = "Maximum"
  period = 60
  evaluation_periods = 2
  datapoints_to_alarm = 2
  threshold = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data = "missing"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "log_legacy_ec2_cpu" {
  alarm_name = "${var.project_name}-ec2-cpu"
  namespace = "AWS/EC2"
  metric_name = "CPUUtilization"
  dimensions = {InstanceId = var.log_legacy_ec2_id}
  statistic = "Average"
  period = 300
  evaluation_periods = 2
  threshold = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_route53_health_check" "web" {
  type = "HTTPS"
  fqdn = var.health_check_fqdn
  port = 443
  resource_path = var.health_check_path
  request_interval = 30
  failure_threshold = 2
  tags = {Name = "${var.project_name}-web_health_check"}
}

resource "aws_cloudwatch_metric_alarm" "web_health" {
  alarm_name = "${var.project_name}-r53-web-health"
  namespace = "AWS/Route53"
  metric_name = "HealthCheckStatus"
  dimensions = {HealthCheckId = aws_route53_health_check.web.id}
  statistic = "Minimum"
  period = 60
  evaluation_periods = 1
  threshold = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data = "breaching"   # Because "no data" means the R53 check itself is broken
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_route53_health_check" "db_backed" {
  type = "HTTPS"
  fqdn = var.health_check_fqdn
  port = 443
  resource_path = var.db_health_check_path
  request_interval = 30
  failure_threshold = 2
  tags = {Name = "${var.project_name}-db-health-check"}
}

resource "aws_cloudwatch_metric_alarm" "db_backed_health" {
  alarm_name = "${var.project_name}-r53-db-backed-health"
  namespace = "AWS/Route53"
  metric_name = "HealthCheckStatus"
  dimensions = {HealthCheckId = aws_route53_health_check.db_backed.id}
  statistic = "Minimum"
  period = 60
  evaluation_periods = 1
  threshold = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data = "breaching"
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name = "${var.project_name}-rds-free-storage"
  namespace = "AWS/RDS"
  metric_name = "FreeStorageSpace"
  dimensions = {DBInstanceIdentifier = var.log_legacy_db_instance_identifier}
  statistic = "Minimum"
  period = 300
  evaluation_periods = 1
  threshold = var.rds_free_storage_threshold_gib * 1024 * 1024 * 1024 # The metric is in bytes
  comparison_operator = "LessThanThreshold"
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name = "${var.project_name}-rds-cpu"
  namespace = "AWS/RDS"
  metric_name = "CPUUtilization"
  dimensions = {DBInstanceIdentifier = var.log_legacy_db_instance_identifier}
  statistic = "Average"
  period = 60
  evaluation_periods = 6
  datapoints_to_alarm = 5 # Why: about 5 minutes to detect, and one dip or one blip can't flip the alarm either way.
  threshold = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name = "${var.project_name}-rds-connections"
  namespace = "AWS/RDS"
  metric_name = "DatabaseConnections"
  dimensions = {DBInstanceIdentifier = var.log_legacy_db_instance_identifier}
  statistic = "Maximum"
  period = 60
  evaluation_periods = 3
  datapoints_to_alarm = 3
  threshold = var.rds_max_connections * 0.8   # i.e, 80% of the max connections
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_db_event_subscription" "rds" {
  name = "${var.project_name}-rds-events"
  sns_topic = aws_sns_topic.alerts.arn
  source_type = "db-instance"
  source_ids = [var.log_legacy_db_instance_identifier]
  event_categories = ["availability", "backup", "failure", "low storage", "maintenance", "recovery"]
}

resource "aws_cloudwatch_metric_alarm" "log_legacy_root_disk" {
  alarm_name = "${var.project_name}-root-disk-used"
  namespace = var.cwagent_namespace
  metric_name = "Disk_Used_Percent"

  # Why InstanceId + path only: the agent' default extra dimensions (ImageId, device, fstype)
  # change when the AMI is rebuilt, and would orphan the alarm
  dimensions = {InstanceId = var.log_legacy_ec2_id, path = "/"}

  statistic = "Maximum"
  period = 300  # Disk fills over days, so 1-minute data adds cost, not value
  evaluation_periods = 4  # So we get no alarm during the 15-minutes window
  datapoints_to_alarm = 4
  threshold = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"

  # Why breaching: no data means the agent is down or the disk is gone, so we want to hear about it.
  # Trade-off: a deliberate stop/start longer than ~20 minutes also alarms.
  treat_missing_data = "breaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "log_legacy_documents_disk_warning" {
  alarm_name = "${var.project_name}-documents-disk-warning"
  namespace = var.cwagent_namespace
  metric_name = "Disk_Used_Percent"
  dimensions = {InstanceId = var.log_legacy_ec2_id, path = var.documents_volume_mount_path}
  statistic = "Maximum"
  period = 300
  evaluation_periods = 3
  datapoints_to_alarm = 3
  threshold = 80   # Why: at 29GB/month grrowth, this leaves time to plan and approve a bigger volume
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data = "breaching"
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "log_legacy_documents_disk_critical" {
  alarm_name = "${var.project_name}-documents-disk-critical"
  namespace = var.cwagent_namespace
  metric_name = "Disk_Used_Percent"
  dimensions = {InstanceId = var.log_legacy_ec2_id, path = var.documents_volume_mount_path}
  statistic = "Maximum"
  period = 300
  evaluation_periods = 2
  datapoints_to_alarm = 2
  threshold = 90   # Why: a second, louder tier. A full disk stops uploads (BR-10).
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data = "missing"   # Why: the warn alarm already covers missing data; this avoids duplicate emails.
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "log_legacy_memory" {
  alarm_name = "${var.project_name}-ec2-memory-used"
  namespace = var.cwagent_namespace
  metric_name = "Memory_Used_Percent"
  dimensions = {InstanceId = var.log_legacy_ec2_id}
  statistic = "Average"
  period = 300
  evaluation_periods = 2
  datapoints_to_alarm = 2
  threshold = 85
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data = "missing"  #  Why : if the agent dies, the disk alarms already say so, so memory stays quiet to avoid a pile of emails.
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "log_legacy_documents_snapshot_failed" {
  alarm_name = "${var.project_name}-documents-snapshot-failed"
  namespace = "AWS/EBS"
  metric_name = "SnapshotCreateFailed"
  dimensions = {DLMPolicyId = var.log_legacy_dlm_policy_id}
  statistic = "Sum"  
  period = 86400
  evaluation_periods = 1
  datapoints_to_alarm = 1
  threshold = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data = "notBreaching"
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "log_legacy_documents_snapshot_missing" {
  alarm_name          = "${var.project_name}-documents-snapshot-missing"
  namespace           = "AWS/EBS"
  metric_name         = "SnapshotsCreateCompleted"
  dimensions          = { DLMPolicyId = var.log_legacy_dlm_policy_id }
  statistic           = "Sum"
  period              = 3600
  evaluation_periods  = 28
  datapoints_to_alarm = 28   # Why: 24h schedule + 4h slack for DLM's start window and retries. All 28 empty hours means a run was really missed.
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching" # Why: most hours have no data, and a skipped run publishes nothing.
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_log_group" "log_legacy_poller_tracking" {
  name = "/logistics/tracking-poller"
  retention_in_days = var.poller_log_retension_days
}

resource "aws_cloudwatch_dashboard" "log_legacy_tracking" {
  dashboard_name = "${var.project_name}-tracking"

  dashboard_body = jsondecode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title = "Poller heartbeat (successful cycles per 5 min)"
          region = var.aws_region   # Region in which the data is written in
          view = "timeSeries"
          stat = "Sum"
          period = 300
          metrics = [[local.tracking_namespace, "Heartbeat"]]
          yAxis = {left = { min = 0 }}
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title = "Failed cycles by reason"
          region = var.aws_region
          view = "timeSeries"
          stacked = true  # Why: so that total height = total failures and colour = cause
          stat = "Sum"
          period = 300
          metrics = [for r in local.poller_failure_reasons : [local.tracking_namespace, "FailedCycle", "Reason", r]]  # i.e Ns, MN, DM, DV
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title = "Records per cycle (backlog indicator)"
          region = var.aws_region
          view = "timeSeries"
          stat = "Maximum"
          period = 300
          metrics = [[local.tracking_namespace, "RecordsPerCycle"]]
          # Why a line at 50,000: a batch at the limit means the poller is still catching up
          annotations = {horizontal = [{label = "feed limit", value = 50000}]}
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title = "Ingest lag (seconds)"
          region = var.aws_region
          view = "timeSeries"
          stat = "Maximum"
          period = 300
          metric = [[local.tracking_namespace, "IngestLagSeconds"]]
          annotations = {horizontal = [{label = "target", value = 300}]}
        }
      }
    ]
  })
}