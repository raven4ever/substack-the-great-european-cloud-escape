resource "scaleway_k8s_cluster" "app" {
  name                        = format("%s-cluster", local.app_name)
  version                     = "1.35.3"
  cni                         = "cilium"
  private_network_id          = scaleway_vpc_private_network.app.id
  delete_additional_resources = true

  tags = [local.project]
}

resource "scaleway_k8s_pool" "app" {
  cluster_id = scaleway_k8s_cluster.app.id
  name       = format("%s-pool", local.app_name)
  node_type  = "DEV1-M"
  size       = 2
  min_size   = 1
  max_size   = 3

  autoscaling         = true
  autohealing         = true
  container_runtime   = "containerd"
  wait_for_pool_ready = true

  tags = [local.project]
}
