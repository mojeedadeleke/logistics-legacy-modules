locals {
    # Why one list: it drives both the log groups and the "rds_log_export" setting,
    # so they can never disagree about which logs exist.
    # Kept alphabetical: the provider has had plan diffs when the order differs.
  rds_log_exports = ["postgresql", "upgrade"]
}