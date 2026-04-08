resource "aws_vpc_ipam" "app" {
  operating_regions {
    region_name = data.aws_region.current.id
  }

  tags = {
    Name    = format("%s-ipam", local.app_name)
    Project = "ep3-lb-asg-vms"
  }
}

resource "aws_vpc_ipam_pool" "regional" {
  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam.app.private_default_scope_id
  locale         = data.aws_region.current.id

  allocation_min_netmask_length = 16
  allocation_max_netmask_length = 16

  tags = {
    Name    = format("%s-ipam-regional", local.app_name)
    Project = "ep3-lb-asg-vms"
  }
}

resource "aws_vpc_ipam_pool_cidr" "regional" {
  ipam_pool_id = aws_vpc_ipam_pool.regional.id
  cidr         = "10.0.0.0/8"
}
