# Why one local: these strings must match the poller's code character for character.
# A typo here (or there) gives an empty graph, not an error.
locals {
    tracking_namespace = "Logistics/Tracking"

    # Why a fixed list: the poller only ever emits these four reasons, so each gets its own series
    poller_failure_reasons = ["auth", "ratelimit", "network", "db"]
}