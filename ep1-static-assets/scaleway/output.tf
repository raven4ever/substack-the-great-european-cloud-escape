output "website_url" {
  value = scaleway_object_bucket_website_configuration.website.website_endpoint
}
