# Why a local list of alarms: one place to add or remove a widget.
locals {
  dashboard_alarms = [
    {title = "Legacy EC2 system status check", arn = aws_cloudwatch_metric_alarm.log_legacy_ec2_system_status.arn},
    {title = "Legacy EC2 instance status check", arn = aws_cloudwatch_metric_alarm.log_legacy_ec2_instance_status.arn},
    {title = "Legacy EC2 CPU", arn = aws_cloudwatch_metric_alarm.log_legacy_ec2_cpu.arn},
    {title = "Legacy EC2 memory", arn = aws_cloudwatch_metric_alarm.log_legacy_memory.arn},
    {title = "Legacy documents disk", arn = aws_cloudwatch_metric_alarm.log_legacy_documents_disk_warning},
    {title = "Legacy R53 Web HTTPS health check", arn = aws_cloudwatch_metric_alarm.web_health},
    {title = "Legacy R53 DB-backed health check", arn = aws_cloudwatch_metric_alarm.db_backed_health},
    {title = "Legacy RDS free storage", arn = aws_cloudwatch_metric_alarm.rds_free_storage},
    {title = "Legacy RDS CPU", arn = aws_cloudwatch_metric_alarm.rds_cpu},
    {title = "Legacy RDS connections", arn = aws_cloudwatch_metric_alarm.rds_connections},
    {title = "Legacy EC2 root disk", arn = aws_cloudwatch_metric_alarm.log_legacy_root_disk},
    {title = "Legacy documents snapshot failed", arn = aws_cloudwatch_metric_alarm.log_legacy_documents_snapshot_failed},
    {title = "Legacy documents snapshots missing", arn = aws_cloudwatch_metric_alarm.log_legacy_documents_snapshot_missing},
  ]
}