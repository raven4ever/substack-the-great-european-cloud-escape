resource "helm_release" "app" {
  name             = local.app_sa_name
  chart            = format("%s/../helm", path.module)
  namespace        = local.app_sa_namespace
  create_namespace = true
  upgrade_install  = true

  set = [
    {
      name  = "image.repository"
      value = format("%s/my-animalz", scaleway_registry_namespace.app.endpoint)
    },
    {
      name  = "image.tag"
      value = "latest"
    },
    {
      name  = "serviceAccount.name"
      value = local.app_sa_name
    },
    {
      name  = "env.datasource.url"
      value = format(
        "jdbc:postgresql://%s:%d/%s",
        scaleway_rdb_instance.app.private_network[0].ip,
        scaleway_rdb_instance.app.private_network[0].port,
        scaleway_rdb_database.app.name,
      )
    },
    {
      name  = "env.datasource.username"
      value = scaleway_rdb_instance.app.user_name
    },
    {
      name  = "env.datasource.password"
      value = random_password.db_master.result
    },
    {
      name  = "env.app.bucketName"
      value = scaleway_object_bucket.animal_images.name
    },
    {
      name  = "service.type"
      value = "LoadBalancer"
    },
    {
      name  = "service.annotations.service\\.beta\\.kubernetes\\.io/scw-loadbalancer-use-hostname"
      value = "true"
    },
    {
      name  = "extraEnv[0].name"
      value = "SPRING_CLOUD_AWS_CREDENTIALS_ACCESS_KEY"
    },
    {
      name  = "extraEnv[0].value"
      value = scaleway_iam_api_key.app.access_key
    },
    {
      name  = "extraEnv[1].name"
      value = "SPRING_CLOUD_AWS_CREDENTIALS_SECRET_KEY"
    },
    {
      name  = "extraEnv[1].value"
      value = scaleway_iam_api_key.app.secret_key
    },
    {
      name  = "extraEnv[2].name"
      value = "SPRING_CLOUD_AWS_S3_ENDPOINT"
    },
    {
      name  = "extraEnv[2].value"
      value = "https://s3.fr-par.scw.cloud"
    },
    {
      name  = "extraEnv[3].name"
      value = "SPRING_CLOUD_AWS_S3_REGION"
    },
    {
      name  = "extraEnv[3].value"
      value = "fr-par"
    },
    {
      name  = "extraEnv[4].name"
      value = "SPRING_CLOUD_AWS_S3_PATH_STYLE_ACCESS_ENABLED"
    },
    {
      name  = "extraEnv[4].value"
      value = "true"
    },
  ]

  depends_on = [
    scaleway_k8s_pool.app,
    docker_registry_image.app,
  ]
}
