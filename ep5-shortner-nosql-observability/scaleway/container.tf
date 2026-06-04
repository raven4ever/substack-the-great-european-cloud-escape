resource "scaleway_container_namespace" "app" {
  name        = format("%s-ns", local.app_name)
  description = format("Serverless container namespace for %s", local.project)
  tags        = [local.project]
}

resource "scaleway_container" "app" {
  name         = local.app_name
  namespace_id = scaleway_container_namespace.app.id

  # TEMP: by tag (was @digest). Digest reference returns "image not found"
  # in registry — likely push pushes only manifest. Re-evaluate later.
  image = local.app_image_tag

  port      = 8080
  min_scale = 1
  max_scale = 3

  https_connections_only = true

  # PN attachment → Mongo reachable without leaving VPC.
  # Namespace-level activate_vpc_integration deprecated, always-true now.
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
    HEARTBEAT_INTERVAL          = var.heartbeat_interval
    HEARTBEAT_PAYLOAD_KB        = var.heartbeat_payload_kb
    CHAOS_RATE                  = var.chaos_rate
  }

  # MONGODB_URI = master password. OTLP_HEADERS = Cockpit bearer. No plain env.
  secret_environment_variables = {
    # Scaleway resource IDs are <region>/<uuid>. Mongo private endpoint hostname
    # format: <instance_uuid>.<pn_uuid>.internal — region prefix stripped.
    MONGODB_URI = format(
      "mongodb+srv://%s:%s@%s.%s.internal",
      scaleway_mongodb_instance.app.user_name,
      random_password.db_master.result,
      trimprefix(scaleway_mongodb_instance.app.id, format("%s/", data.scaleway_config.current.region)),
      trimprefix(scaleway_vpc_private_network.app.id, format("%s/", data.scaleway_config.current.region)),
    )
    MONGODB_TLS_CA             = scaleway_mongodb_instance.app.tls_certificate
    OTEL_EXPORTER_OTLP_HEADERS = format("Authorization=Bearer %s", scaleway_cockpit_token.app.secret_key)
  }

  tags = [local.project]

  depends_on = [
    docker_registry_image.app,
  ]
}
