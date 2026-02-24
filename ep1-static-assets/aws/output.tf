output "bucket_website_url" {
  value = aws_s3_bucket_website_configuration.website.website_endpoint
}

output "cdn_website_url" {
  value = aws_cloudfront_distribution.main.domain_name
}
