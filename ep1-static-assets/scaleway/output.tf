output "bucket_website_url" {
  value = scaleway_object_bucket_website_configuration.website.website_endpoint
}

output "cdn_website_url" {
  value = scaleway_edge_services_dns_stage.main.default_fqdn
}
