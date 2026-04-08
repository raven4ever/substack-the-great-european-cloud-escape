resource "scaleway_instance_security_group" "app" {
  name                    = format("%s-sg", local.app_name)
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"

  inbound_rule {
    action   = "accept"
    protocol = "TCP"
    port     = 80
  }

  tags = ["ep3-lb-asg-vms"]
}

resource "scaleway_autoscaling_instance_template" "app" {
  name                = format("%s-template", local.app_name)
  commercial_type     = local.instance_type
  image_id            = data.scaleway_marketplace_image.ubuntu.id
  security_group_id   = scaleway_instance_security_group.app.id
  private_network_ids = [scaleway_vpc_private_network.app.id]
  cloud_init          = data.cloudinit_config.app.rendered
  tags                = ["ep3-lb-asg-vms"]

  volumes {
    name        = "as-volume"
    volume_type = "sbs"
    boot        = true
    perf_iops   = 5000
    from_empty {
      size = 20
    }
  }
}

resource "scaleway_autoscaling_instance_group" "app" {
  name        = local.app_name
  template_id = scaleway_autoscaling_instance_template.app.id
  tags        = ["ep3-lb-asg-vms"]

  capacity {
    min_replicas   = 1
    max_replicas   = 3
    cooldown_delay = 120
  }

  load_balancer {
    id                 = scaleway_lb.app.id
    backend_ids        = [scaleway_lb_backend.app.id]
    private_network_id = scaleway_vpc_private_network.app.id
  }

  delete_servers_on_destroy = true

  depends_on = [scaleway_vpc_gateway_network.app]
}

resource "scaleway_autoscaling_instance_policy" "scale_out" {
  instance_group_id = scaleway_autoscaling_instance_group.app.id
  name              = format("%s-scale-out", local.app_name)
  action            = "scale_up"
  type              = "flat_count"
  value             = 1
  priority          = 1

  metric {
    name               = "cpu-high"
    managed_metric     = "managed_metric_instance_cpu"
    operator           = "operator_greater_than"
    aggregate          = "aggregate_average"
    sampling_range_min = 1
    threshold          = 50
  }
}

resource "scaleway_autoscaling_instance_policy" "scale_in" {
  instance_group_id = scaleway_autoscaling_instance_group.app.id
  name              = format("%s-scale-in", local.app_name)
  action            = "scale_down"
  type              = "flat_count"
  value             = 1
  priority          = 2

  metric {
    name               = "cpu-low"
    managed_metric     = "managed_metric_instance_cpu"
    operator           = "operator_less_than"
    aggregate          = "aggregate_average"
    sampling_range_min = 2
    threshold          = 30
  }
}
