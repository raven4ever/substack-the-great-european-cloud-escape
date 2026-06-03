locals {
  app_url = aws_ecs_express_gateway_service.app.ingress_paths[0].endpoint
}

output "app_url" {
  description = "Public HTTPS endpoint of the ECS Express Mode service."
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
  description = "Direct link to the CloudWatch dashboard."
  value = format(
    "https://%s.console.aws.amazon.com/cloudwatch/home?region=%s#dashboards:name=%s",
    data.aws_region.current.id,
    data.aws_region.current.id,
    aws_cloudwatch_dashboard.app.dashboard_name,
  )
}
