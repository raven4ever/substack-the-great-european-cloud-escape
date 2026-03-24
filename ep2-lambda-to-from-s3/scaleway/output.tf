output "input_bucket" {
  value = scaleway_object_bucket.input.name
}

output "output_bucket" {
  value = scaleway_object_bucket.output.name
}

output "function_endpoint" {
  value = scaleway_function.resizer.domain_name
}

output "sqs_endpoint" {
  value = scaleway_mnq_sqs.main.endpoint
}

output "sqs_queue_url" {
  value = scaleway_mnq_sqs_queue.images.url
}

output "sqs_publisher_access_key" {
  value     = scaleway_mnq_sqs_credentials.publisher.access_key
  sensitive = true
}

output "sqs_publisher_secret_key" {
  value     = scaleway_mnq_sqs_credentials.publisher.secret_key
  sensitive = true
}
