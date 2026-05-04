resource "scaleway_registry_namespace" "app" {
  name        = format("%s-registry", local.app_name)
  description = format("Container images for %s", local.project)
  is_public   = false
}

resource "scaleway_iam_application" "registry" {
  name = format("%s-registry-push", local.app_name)
  tags = [local.project]
}

resource "scaleway_iam_policy" "registry_push" {
  name           = format("%s-registry-push", local.app_name)
  application_id = scaleway_iam_application.registry.id

  rule {
    organization_id      = scaleway_iam_application.registry.organization_id
    permission_set_names = ["ContainerRegistryFullAccess"]
  }
}

resource "scaleway_iam_api_key" "registry" {
  application_id = scaleway_iam_application.registry.id
  description    = "Used by Terraform to push images to the Scaleway Container Registry"
  expires_at     = time_rotating.iam_keys.rotation_rfc3339
}
