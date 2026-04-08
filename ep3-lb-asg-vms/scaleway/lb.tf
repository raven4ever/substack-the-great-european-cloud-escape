resource "scaleway_lb_ip" "app" {
}

resource "scaleway_lb" "app" {
  name   = local.app_name
  ip_ids = [scaleway_lb_ip.app.id]
  type   = "LB-S"
  tags   = ["ep3-lb-asg-vms"]

  private_network {
    private_network_id = scaleway_vpc_private_network.app.id
  }
}

resource "scaleway_lb_backend" "app" {
  lb_id            = scaleway_lb.app.id
  name             = format("%s-backend", local.app_name)
  forward_protocol = "http"
  forward_port     = 80
  health_check_http {
    uri = "/health"
  }

  health_check_delay       = "10s"
  health_check_timeout     = "5s"
  health_check_max_retries = 2
}

resource "scaleway_lb_frontend" "app" {
  lb_id        = scaleway_lb.app.id
  name         = format("%s-frontend", local.app_name)
  backend_id   = scaleway_lb_backend.app.id
  inbound_port = 80
}
