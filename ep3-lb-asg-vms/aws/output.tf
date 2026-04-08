output "app_url" {
  value = format("http://%s", aws_lb.app.dns_name)
}
