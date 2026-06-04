resource "aws_iam_role" "execution" {
  name               = format("%s-execution", local.app_name)
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name    = format("%s-execution", local.app_name)
    Project = local.project
  }
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = format("%s-task", local.app_name)
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name    = format("%s-task", local.app_name)
    Project = local.project
  }
}

resource "aws_iam_role_policy" "app_task" {
  name   = format("%s-task-inline", local.app_name)
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.app_task_inline.json
}

# Express infra role. ECS assumes it to provision ALB + SGs + autoscaling.
resource "aws_iam_role" "infrastructure" {
  name               = format("%s-infrastructure", local.app_name)
  assume_role_policy = data.aws_iam_policy_document.ecs_infrastructure_assume_role.json

  tags = {
    Name    = format("%s-infrastructure", local.app_name)
    Project = local.project
  }
}

resource "aws_iam_role_policy_attachment" "infrastructure_express" {
  role       = aws_iam_role.infrastructure.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices"
}
