# The Cockpit "project" is the Scaleway project the provider is configured for.
# We resolve it explicitly so cockpit.tf binds its source + token to a known
# project ID rather than relying on provider-level defaults.
#
# Note: the legacy `scaleway_cockpit` data source is deprecated; the per-region
# Cockpit datasource (traces, logs, metrics) is now a first-class resource and
# lives in cockpit.tf, not here.
data "scaleway_account_project" "current" {
  name = "default"
}
