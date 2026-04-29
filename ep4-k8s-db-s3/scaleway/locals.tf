locals {
  app_name         = "ep4-app"
  project          = "ep4-eks-db"
  app_sa_namespace = "myanimalz"
  app_sa_name      = "my-animalz"
  app_image_tag    = format("%s/my-animalz:latest", scaleway_registry_namespace.app.endpoint)
}
