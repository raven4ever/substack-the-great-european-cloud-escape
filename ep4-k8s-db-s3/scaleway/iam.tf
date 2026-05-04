resource "scaleway_iam_application" "app" {
  name = format("%s-app", local.app_name)
  tags = [local.project]
}

resource "scaleway_iam_policy" "app_object_storage" {
  name           = format("%s-app-object-storage", local.app_name)
  application_id = scaleway_iam_application.app.id

  rule {
    organization_id      = scaleway_iam_application.app.organization_id
    permission_set_names = ["ObjectStorageFullAccess"]
  }
}

resource "time_rotating" "iam_keys" {
  rotation_years = 1
}

resource "scaleway_iam_api_key" "app" {
  application_id = scaleway_iam_application.app.id
  description    = "Used by the my-animalz Spring Boot pod to access Scaleway Object Storage"
  expires_at     = time_rotating.iam_keys.rotation_rfc3339
}
