resource "aws_security_group" "vpce" {
  name        = format("%s-vpce", local.app_name)
  description = "HTTPS from VPC CIDR to interface VPC endpoints"
  vpc_id      = aws_vpc.app.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.app.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = format("%s-vpce-sg", local.app_name)
    Project = local.project
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.app.id
  service_name      = format("com.amazonaws.%s.dynamodb", data.aws_region.current.id)
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name    = format("%s-dynamodb-gateway", local.app_name)
    Project = local.project
  }
}

# S3 gateway endpoint is required for ECR layer pulls — ECR stores image layers in S3.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.app.id
  service_name      = format("com.amazonaws.%s.s3", data.aws_region.current.id)
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name    = format("%s-s3-gateway", local.app_name)
    Project = local.project
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.app.id
  service_name        = format("com.amazonaws.%s.ecr.api", data.aws_region.current.id)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce.id]
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name    = format("%s-ecr-api", local.app_name)
    Project = local.project
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.app.id
  service_name        = format("com.amazonaws.%s.ecr.dkr", data.aws_region.current.id)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce.id]
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name    = format("%s-ecr-dkr", local.app_name)
    Project = local.project
  }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.app.id
  service_name        = format("com.amazonaws.%s.logs", data.aws_region.current.id)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce.id]
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name    = format("%s-logs", local.app_name)
    Project = local.project
  }
}

resource "aws_vpc_endpoint" "xray" {
  vpc_id              = aws_vpc.app.id
  service_name        = format("com.amazonaws.%s.xray", data.aws_region.current.id)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce.id]
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name    = format("%s-xray", local.app_name)
    Project = local.project
  }
}
