resource "aws_dynamodb_table" "links" {
  name         = format("%s-links", local.app_name)
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "slug"

  attribute {
    name = "slug"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = false
  }

  tags = {
    Name    = format("%s-links", local.app_name)
    Project = local.project
  }
}
