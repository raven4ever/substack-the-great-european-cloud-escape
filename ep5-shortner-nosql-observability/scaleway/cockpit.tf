resource "scaleway_cockpit_source" "traces" {
  name           = format("%s-traces", local.app_name)
  type           = "traces"
  retention_days = 7
  project_id     = data.scaleway_account_project.current.id
}

resource "scaleway_cockpit_token" "app" {
  name       = format("%s-otlp-push", local.app_name)
  project_id = data.scaleway_account_project.current.id

  scopes {
    write_traces = true
  }
}
