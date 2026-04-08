output "app_url" {
  value = format("http://%s", scaleway_lb_ip.app.ip_address)
}
