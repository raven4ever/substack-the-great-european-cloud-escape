resource "random_password" "db_master" {
  length  = 24
  special = false
}

resource "scaleway_mongodb_instance" "app" {
  name                         = format("%s-mongo", local.app_name)
  version                      = "7.0.12"
  node_type                    = "MGDB-PLAY2-NANO"
  node_number                  = 1
  user_name                    = "shortner"
  password                     = random_password.db_master.result
  volume_size_in_gb            = 5
  is_snapshot_schedule_enabled = false

  # PN attached → container reaches Mongo without leaving VPC.
  private_network {
    pn_id = scaleway_vpc_private_network.app.id
  }

  tags = [local.project]
}
