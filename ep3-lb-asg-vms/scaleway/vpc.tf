resource "scaleway_vpc" "app" {
  name = format("%s-vpc", local.app_name)
  tags = ["ep3-lb-asg-vms"]
}

resource "scaleway_vpc_private_network" "app" {
  name   = format("%s-pn", local.app_name)
  vpc_id = scaleway_vpc.app.id
  tags   = ["ep3-lb-asg-vms"]

  ipv4_subnet {
    subnet = "10.0.0.0/24"
  }
}

# --- IPAM ---

resource "scaleway_ipam_ip" "gateway" {
  source {
    private_network_id = scaleway_vpc_private_network.app.id
  }

  tags = ["ep3-lb-asg-vms"]
}

# --- Public Gateway (NAT equivalent) ---

resource "scaleway_vpc_public_gateway_ip" "app" {}

resource "scaleway_vpc_public_gateway" "app" {
  name  = format("%s-pgw", local.app_name)
  type  = "VPC-GW-S"
  ip_id = scaleway_vpc_public_gateway_ip.app.id
  tags  = ["ep3-lb-asg-vms"]
}

resource "scaleway_vpc_gateway_network" "app" {
  gateway_id         = scaleway_vpc_public_gateway.app.id
  private_network_id = scaleway_vpc_private_network.app.id
  enable_masquerade  = true

  ipam_config {
    push_default_route = true
    ipam_ip_id         = scaleway_ipam_ip.gateway.id
  }
}
