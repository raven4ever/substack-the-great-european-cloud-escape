resource "scaleway_iam_application" "function" {
  name        = "image-resizer-function"
  description = "IAM application for the image resizer function to access Object Storage"
}

resource "scaleway_iam_policy" "function_s3" {
  name           = "image-resizer-s3-access"
  description    = "Allow read/write access to Object Storage buckets"
  application_id = scaleway_iam_application.function.id

  rule {
    project_ids          = [data.scaleway_account_project.current.id]
    permission_set_names = ["ObjectStorageObjectsRead", "ObjectStorageObjectsWrite"]
  }
}

resource "scaleway_iam_api_key" "function" {
  application_id     = scaleway_iam_application.function.id
  description        = "API key for the image resizer function"
  default_project_id = data.scaleway_account_project.current.id
  expires_at         = timeadd(timestamp(), "8760h")
}
