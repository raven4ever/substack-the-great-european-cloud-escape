resource "scaleway_vpc_private_network" "app" {
  name = format("%s-pn", local.app_name)
  tags = [local.project]
}
