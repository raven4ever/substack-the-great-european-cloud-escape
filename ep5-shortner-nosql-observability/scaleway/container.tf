resource "scaleway_container_namespace" "app" {
  name        = format("%s-ns", local.app_name)
  description = format("Serverless container namespace for %s", local.project)
  tags        = [local.project]
}

resource "scaleway_container" "app" {
  name         = local.app_name
  namespace_id = scaleway_container_namespace.app.id

  # Pull by digest so a new image build always rolls the deployment. Pinning to
  # `:latest` would silently keep the old revision after a rebuild.
  registry_image = format("%s@%s", local.app_image_repo, docker_registry_image.app.sha256_digest)

  port      = 8080
  min_scale = 1
  max_scale = 3

  https_connections_only = true

  # VPC integration for Serverless Containers is GA; the namespace-level
  # `activate_vpc_integration` flag is now always-true and deprecated, so we
  # only need `private_network_id` here. The container reaches Mongo via its
  # PN-attached endpoint without traffic leaving the VPC.
  private_network_id = scaleway_vpc_private_network.app.id

  environment_variables = {
    STORAGE_KIND                = "mongodb"
    MONGODB_DATABASE            = "shortner"
    MONGODB_COLLECTION          = "links"
    DEFAULT_TTL                 = var.default_ttl
    TRACE_EXPORTER              = "otlp"
    OTEL_EXPORTER_OTLP_ENDPOINT = scaleway_cockpit_source.traces.push_url
    LOG_LEVEL                   = var.log_level
    APP_NAME                    = local.app_name
    APP_VERSION                 = var.app_version
    PORT                        = "8080"
    HEARTBEAT_INTERVAL          = var.heartbeat_interval
    HEARTBEAT_PAYLOAD_KB        = var.heartbeat_payload_kb
    CHAOS_RATE                  = var.chaos_rate
  }

  # Secrets: the Mongo URI carries the master password and the OTLP headers
  # carry the Cockpit bearer token. Neither may surface in plain env vars.
  secret_environment_variables = {
    MONGODB_URI = format(
      "mongodb://%s:%s@%s:%d",
      scaleway_mongodb_instance.app.user_name,
      random_password.db_master.result,
      scaleway_mongodb_instance.app.private_network[0].dns_records[0],
      scaleway_mongodb_instance.app.private_network[0].port,
    )
    OTEL_EXPORTER_OTLP_HEADERS = format("Authorization=Bearer %s", scaleway_cockpit_token.app.secret_key)
  }

  tags = [local.project]

  depends_on = [
    docker_registry_image.app,
  ]
}
