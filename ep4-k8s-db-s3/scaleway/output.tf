resource "local_file" "kubeconfig" {
  filename        = format("%s/.kube/config", abspath(path.module))
  content         = scaleway_k8s_cluster.app.kubeconfig[0].config_file
  file_permission = "0600"
}

resource "null_resource" "wait_for_lb" {
  triggers = {
    release    = helm_release.app.id
    kubeconfig = local_file.kubeconfig.filename
    namespace  = local.app_sa_namespace
    service    = format("%s-my-animalz", local.app_sa_name)
  }

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = self.triggers.kubeconfig
    }
    command = format(
      "kubectl wait --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' service/%s -n %s --timeout=5m",
      self.triggers.service,
      self.triggers.namespace
    )
  }
}

data "kubernetes_service_v1" "app" {
  metadata {
    name      = format("%s-my-animalz", local.app_sa_name)
    namespace = local.app_sa_namespace
  }

  depends_on = [null_resource.wait_for_lb]
}

output "curl_commands" {
  value = {
    list_animals            = format("curl -sS http://%s/api/animals", data.kubernetes_service_v1.app.status[0].load_balancer[0].ingress[0].hostname)
    list_species            = format("curl -sS http://%s/api/species", data.kubernetes_service_v1.app.status[0].load_balancer[0].ingress[0].hostname)
    list_animals_by_species = format("curl -sS http://%s/api/species/1/animals", data.kubernetes_service_v1.app.status[0].load_balancer[0].ingress[0].hostname)
    upload_random_image     = format("curl -sS -X POST http://%s/api/images/random", data.kubernetes_service_v1.app.status[0].load_balancer[0].ingress[0].hostname)
  }
}
