resource "aws_ecr_repository" "app" {
  name                 = "my-animalz"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    Name    = "my-animalz"
    Project = local.project
  }
}
