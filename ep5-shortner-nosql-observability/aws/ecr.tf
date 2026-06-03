resource "aws_ecr_repository" "app" {
  name                 = local.app_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    Name    = format("%s-ecr", local.app_name)
    Project = local.project
  }
}
