resource "docker_image" "app" {
  name = local.app_image_tag

  build {
    context    = format("%s/../app", path.module)
    dockerfile = "Dockerfile"
    tag        = [local.app_image_tag]

    label = {
      project = local.project
    }
  }

  triggers = {
    dockerfile_sha = filesha256(format("%s/../app/Dockerfile", path.module))
    pom_xml_sha    = filesha256(format("%s/../app/pom.xml", path.module))
  }
}

resource "docker_registry_image" "app" {
  name          = docker_image.app.name
  keep_remotely = true

  triggers = {
    image_id = docker_image.app.image_id
  }
}
