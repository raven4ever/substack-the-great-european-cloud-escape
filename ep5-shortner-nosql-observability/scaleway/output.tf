locals {
  app_url = scaleway_container.app.public_endpoint
}

output "app_url" {
  description = "Public HTTPS URL for the URL-shortener container."
  value       = local.app_url
}

output "curl_commands" {
  description = "Sample curl invocations exercising the deployed shortener."
  value = {
    home     = format("curl -sS %s/", local.app_url)
    redirect = format("curl -sSI %s/r/<slug>", local.app_url)
    health   = format("curl -sS %s/health", local.app_url)
    metrics  = format("curl -sS %s/metrics", local.app_url)
  }
}

output "dashboard_url" {
  description = "Direct link to the Cockpit Grafana dashboard."
  value       = format("%s/d/%s", data.scaleway_cockpit_grafana.main.grafana_url, grafana_dashboard.app.uid)
}
