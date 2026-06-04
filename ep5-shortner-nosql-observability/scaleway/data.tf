# Resolves provider-configured project. Cockpit source + token bind to its ID.
# Legacy `scaleway_cockpit` data source deprecated → per-region resources in cockpit.tf.
data "scaleway_account_project" "current" {}

# Provider-resolved region (env / provider config). No deps, always available.
data "scaleway_config" "current" {}
