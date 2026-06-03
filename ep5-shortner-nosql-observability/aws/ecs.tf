# Choice: aws_ecs_express_gateway_service.
# Express Mode (provider v6.23.0+) provisions the cluster-managed ALB,
# security groups, target group, autoscaling, and a public HTTPS endpoint
# on our behalf, removing ~10 resources of vanilla-Fargate boilerplate.
# That is exactly the abstraction layer this article is about, so we use
# it. Fargate launch type is implicit — Express Mode does not run on EC2.

resource "aws_ecs_cluster" "app" {
  name = format("%s-cluster", local.app_name)

  tags = {
    Name    = format("%s-cluster", local.app_name)
    Project = local.project
  }
}

resource "aws_ecs_express_gateway_service" "app" {
  service_name            = local.app_name
  cluster                 = aws_ecs_cluster.app.name
  execution_role_arn      = aws_iam_role.execution.arn
  task_role_arn           = aws_iam_role.task.arn
  infrastructure_role_arn = aws_iam_role.infrastructure.arn
  cpu                     = "512"
  memory                  = "1024"
  health_check_path       = "/health"
  wait_for_steady_state   = true

  primary_container {
    image          = format("%s@%s", aws_ecr_repository.app.repository_url, docker_registry_image.app.sha256_digest)
    container_port = 8080

    aws_logs_configuration {
      log_group         = aws_cloudwatch_log_group.app.name
      log_stream_prefix = "app"
    }

    environment {
      name  = "PORT"
      value = "8080"
    }

    environment {
      name  = "STORAGE_KIND"
      value = "dynamodb"
    }

    environment {
      name  = "DYNAMODB_TABLE"
      value = aws_dynamodb_table.links.name
    }

    environment {
      name  = "DYNAMODB_REGION"
      value = data.aws_region.current.region
    }

    environment {
      name  = "AWS_REGION"
      value = data.aws_region.current.region
    }

    environment {
      name  = "DEFAULT_TTL"
      value = var.default_ttl
    }

    environment {
      name  = "TRACE_EXPORTER"
      value = "xray"
    }

    environment {
      name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
      value = format("https://xray.%s.amazonaws.com/v1/traces", data.aws_region.current.region)
    }

    environment {
      name  = "LOG_LEVEL"
      value = var.log_level
    }

    environment {
      name  = "APP_NAME"
      value = local.app_name
    }

    environment {
      name  = "APP_VERSION"
      value = var.app_version
    }

    environment {
      name  = "HEARTBEAT_INTERVAL"
      value = var.heartbeat_interval
    }

    environment {
      name  = "HEARTBEAT_PAYLOAD_KB"
      value = var.heartbeat_payload_kb
    }

    environment {
      name  = "CHAOS_RATE"
      value = var.chaos_rate
    }
  }

  network_configuration {
    subnets = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  }

  scaling_target {
    auto_scaling_metric       = "AVERAGE_CPU"
    auto_scaling_target_value = 50
    min_task_count            = 1
    max_task_count            = 3
  }

  tags = {
    Name    = format("%s-service", local.app_name)
    Project = local.project
  }

  depends_on = [
    aws_iam_role_policy_attachment.execution_managed,
    aws_iam_role_policy_attachment.infrastructure_express,
    aws_iam_role_policy.app_task,
    aws_vpc_endpoint.dynamodb,
    aws_vpc_endpoint.s3,
    aws_vpc_endpoint.ecr_api,
    aws_vpc_endpoint.ecr_dkr,
    aws_vpc_endpoint.logs,
    aws_vpc_endpoint.xray,
  ]
}
