resource "random_password" "db_master" {
  length  = 24
  special = false
}

resource "scaleway_rdb_instance" "app" {
  name           = format("%s-postgres", local.app_name)
  node_type      = "DB-DEV-S"
  engine         = "PostgreSQL-17"
  is_ha_cluster  = false
  disable_backup = true
  user_name      = "masteruser"
  password       = random_password.db_master.result

  private_network {
    pn_id       = scaleway_vpc_private_network.app.id
    enable_ipam = true
  }

  tags = [local.project]
}

resource "scaleway_rdb_database" "app" {
  instance_id = scaleway_rdb_instance.app.id
  name        = "demo"
}
