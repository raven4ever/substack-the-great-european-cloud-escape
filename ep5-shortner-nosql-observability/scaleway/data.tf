# Resolves provider-configured project. Cockpit source + token bind to its ID.
# Legacy `scaleway_cockpit` data source deprecated → per-region resources in cockpit.tf.
data "scaleway_account_project" "current" {}
