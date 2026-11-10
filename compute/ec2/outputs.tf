output "log_legacy_ec2_id" {
  description = "The ID of the legacy infrastructure instance"
  value       = aws_instance.log_legacy_ec2.id
}

output "log_legacy_ec2_pub_eip" {
  description = "Public IPv4 address of the legacy instance, stable across stop/start"
  value = aws_eip.log_legacy_ec2_eip.public_ip
}

output "log_legacy_ec2_sg_id" {
  description = "Security group ID of the legacy instance, for the database module to allow traffic from it"
  value = aws_security_group.log_legacy_ec2_sg.id
}

output "log_legacy_dlm_policy_id" {
  description = "The ID of the Data Lifecycle Manager (DLM) that snapshots the documents volume"
  value = aws_dlm_lifecycle_policy.log_legacy_documents_volume_snapshots.id
}