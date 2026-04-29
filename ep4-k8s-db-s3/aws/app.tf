resource "helm_release" "app" {
  name             = local.app_sa_name
  chart            = format("%s/../helm", path.module)
  namespace        = local.app_sa_namespace
  create_namespace = true
  upgrade_install  = true
  force_update     = true

  set = [
    {
      name  = "image.repository"
      value = aws_ecr_repository.app.repository_url
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
      name  = "serviceAccount.roleArn"
      value = aws_iam_role.app.arn
    },
    {
      name  = "env.datasource.url"
      value = format("jdbc:postgresql://%s/%s", aws_db_instance.app.endpoint, aws_db_instance.app.db_name)
    },
    {
      name  = "env.datasource.username"
      value = aws_db_instance.app.username
    },
    {
      name  = "env.datasource.password"
      value = random_password.db_master.result
    },
    {
      name  = "env.app.bucketName"
      value = aws_s3_bucket.animal_images.bucket
    },
    {
      name  = "service.type"
      value = "LoadBalancer"
    },
    {
      name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "external"
    },
    {
      name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type"
      value = "ip"
    },
    {
      name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
      value = "internet-facing"
    },
  ]

  depends_on = [
    helm_release.aws_load_balancer_controller,
    docker_registry_image.app,
  ]
}

resource "null_resource" "wait_for_lb" {
  triggers = {
    release    = helm_release.app.id
    kubeconfig = format("%s/.kube/config-ep4", abspath(path.module))
    namespace  = local.app_sa_namespace
    service    = format("%s-my-animalz", local.app_sa_name)
    cluster    = aws_eks_cluster.app.name
    region     = data.aws_region.current.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig \
        --name ${self.triggers.cluster} \
        --region ${self.triggers.region} \
        --kubeconfig ${self.triggers.kubeconfig}
      KUBECONFIG=${self.triggers.kubeconfig} \
        kubectl wait --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
        service/${self.triggers.service} -n ${self.triggers.namespace} --timeout=5m
    EOT
  }
}

data "kubernetes_service_v1" "app" {
  metadata {
    name      = format("%s-my-animalz", local.app_sa_name)
    namespace = local.app_sa_namespace
  }

  depends_on = [null_resource.wait_for_lb]
}
