locals {
  app_name      = "ep5-shortner"
  project       = "ep5-shortner-nosql-observability"
  app_image_tag = format("%s:latest", aws_ecr_repository.app.repository_url)
}
