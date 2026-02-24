resource "scaleway_edge_services_pipeline" "main" {
  name = "my-super-super-uber-scaleway-website-pipeline"
}

resource "scaleway_edge_services_backend_stage" "main" {
  pipeline_id = scaleway_edge_services_pipeline.main.id
  s3_backend_config {
    bucket_name   = scaleway_object_bucket.main.name
    bucket_region = data.scaleway_config.main.region
    is_website    = true
  }
}

resource "scaleway_edge_services_cache_stage" "main" {
  pipeline_id      = scaleway_edge_services_pipeline.main.id
  backend_stage_id = scaleway_edge_services_backend_stage.main.id
}

resource "scaleway_edge_services_dns_stage" "main" {
  pipeline_id = scaleway_edge_services_pipeline.main.id
}
