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
