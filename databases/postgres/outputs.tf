output "log_legacy_db_address" {
  description = "Hostname of the legacy RDS instance. Used to configure the application's database connection"
  # Why: the host alone, not endpoint (host:port), because the app config takes host and port separately and the root already owns the port.
  value = aws_db_instance.log_legacy_db_instance.address
}

output "log_legacy_db_engine_version_actual" {
  description = "Engine version RDS is actually running, which can differ from the requested version if minor upgrades are applied automatically"
  # Why: the provider exports this separately from engine_version, so it shows drift without opening the console.
  value = aws_db_instance.log_legacy_db_instance.engine_version_actual
}