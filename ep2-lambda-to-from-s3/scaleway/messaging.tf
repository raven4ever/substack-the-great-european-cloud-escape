# activate SQS for the project
resource "scaleway_mnq_sqs" "main" {}

# credentials for the function to consume messages
resource "scaleway_mnq_sqs_credentials" "function" {
  project_id = scaleway_mnq_sqs.main.project_id
  name       = "image-resizer-function"

  permissions {
    can_manage  = false
    can_receive = true
    can_publish = false
  }
}

# credentials for the uploader to publish messages
resource "scaleway_mnq_sqs_credentials" "publisher" {
  project_id = scaleway_mnq_sqs.main.project_id
  name       = "image-resizer-publisher"

  permissions {
    can_manage  = false
    can_receive = false
    can_publish = true
  }
}

# the queue that bridges uploads to the function
resource "scaleway_mnq_sqs_queue" "images" {
  project_id = scaleway_mnq_sqs.main.project_id
  name       = "image-resize-queue"
  access_key = scaleway_mnq_sqs_credentials.function.access_key
  secret_key = scaleway_mnq_sqs_credentials.function.secret_key
}
