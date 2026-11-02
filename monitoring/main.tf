resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
  # Uses default SNS policy
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol = "email"
  endpoint = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "log_legacy_ec2_system_status" {
  alarm_name = "${var.project_name}-ec2-system-status"
  namespace = "AWS/EC2"
  metric_name = "StatusCheckFailed_System"
  dimensions = {instanceId = var.log_legacy_ec2_id}
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
  dimensions = {instanceId = var.log_legacy_ec2_id}
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
  dimensions = {instanceId = var.log_legacy_ec2_id}
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
  tags = {Name = "${var.project_name}-web_heath_check"}
}

resource "aws_cloudwatch_metric_alarm" "web_health" {
  alarm_name = "${var.project_name}-r53-web-health"
  namespace = "AWS/Route53"
  metric_name = "HealthCheckStatus"
  dimensions = {HeathCheckId = aws_route53_health_check.web.id}
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
  dimensions = {healthCheckId = aws_route53_health_check.db_backed.id}
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
  metric_name = "CPUUtilization"
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
  name = "${var.project_name}-rds=events"
  sns_topic = aws_sns_topic.alerts.arn
  source_type = "db-instance"
  source_ids = [var.log_legacy_db_instance_identifier]
  event_categories = ["availability", "failure", "low storage", "maintenance", "recovery"]
}