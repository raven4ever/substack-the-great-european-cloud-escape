resource "aws_vpc" "app" {
  ipv4_ipam_pool_id    = aws_vpc_ipam_pool.regional.id
  ipv4_netmask_length  = 16
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = format("%s-vpc", local.app_name)
    Project = local.project
  }

  depends_on = [aws_vpc_ipam_pool_cidr.regional]
}

resource "aws_internet_gateway" "app" {
  vpc_id = aws_vpc.app.id

  tags = {
    Name    = format("%s-igw", local.app_name)
    Project = local.project
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.app.id
  cidr_block              = cidrsubnet(aws_vpc.app.cidr_block, 8, 0)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name                     = format("%s-public-a", local.app_name)
    Project                  = local.project
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.app.id
  cidr_block              = cidrsubnet(aws_vpc.app.cidr_block, 8, 1)
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name                     = format("%s-public-b", local.app_name)
    Project                  = local.project
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = cidrsubnet(aws_vpc.app.cidr_block, 8, 2)
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name                              = format("%s-private-a", local.app_name)
    Project                           = local.project
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = cidrsubnet(aws_vpc.app.cidr_block, 8, 3)
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name                              = format("%s-private-b", local.app_name)
    Project                           = local.project
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app.id
  }

  tags = {
    Name    = format("%s-public-rt", local.app_name)
    Project = local.project
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name    = format("%s-nat-eip", local.app_name)
    Project = local.project
  }
}

resource "aws_nat_gateway" "app" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name    = format("%s-nat", local.app_name)
    Project = local.project
  }

  depends_on = [aws_internet_gateway.app]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.app.id
  }

  tags = {
    Name    = format("%s-private-rt", local.app_name)
    Project = local.project
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
