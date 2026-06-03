resource "aws_cloudwatch_log_group" "app" {
  name              = format("/ecs/%s", local.app_name)
  retention_in_days = 7

  tags = {
    Name    = format("%s-logs", local.app_name)
    Project = local.project
  }
}
