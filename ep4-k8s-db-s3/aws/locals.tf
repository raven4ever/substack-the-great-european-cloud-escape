locals {
  app_name              = "ep4-app"
  project               = "ep4-eks-db"
  app_sa_namespace      = "myanimalz"
  app_sa_name           = "my-animalz"
  oidc_issuer_url       = aws_eks_cluster.app.identity[0].oidc[0].issuer
  oidc_issuer_host_path = replace(local.oidc_issuer_url, "https://", "")
  app_image_tag         = format("%s:latest", aws_ecr_repository.app.repository_url)
}
