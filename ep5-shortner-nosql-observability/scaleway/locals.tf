locals {
  app_name       = "ep5-shortner"
  project        = "ep5-shortner-nosql-observability"
  app_image_repo = format("%s/%s", scaleway_registry_namespace.app.endpoint, local.app_name)
  app_image_tag  = format("%s:latest", local.app_image_repo)
}
