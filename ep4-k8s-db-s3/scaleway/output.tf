resource "null_resource" "wait_for_lb" {
  triggers = {
    release    = helm_release.app.id
    kubeconfig = format("%s/.kube/config-ep4-scw", abspath(path.module))
    namespace  = local.app_sa_namespace
    service    = format("%s-my-animalz", local.app_sa_name)
  }

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p $(dirname ${self.triggers.kubeconfig})
      cat > ${self.triggers.kubeconfig} <<'KUBECONFIG'
      ${scaleway_k8s_cluster.app.kubeconfig[0].config_file}
      KUBECONFIG
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

output "curl_commands" {
  value = {
    list_animals            = format("curl -sS http://%s/api/animals", data.kubernetes_service_v1.app.status[0].load_balancer[0].ingress[0].hostname)
    list_species            = format("curl -sS http://%s/api/species", data.kubernetes_service_v1.app.status[0].load_balancer[0].ingress[0].hostname)
    list_animals_by_species = format("curl -sS http://%s/api/species/1/animals", data.kubernetes_service_v1.app.status[0].load_balancer[0].ingress[0].hostname)
    upload_random_image     = format("curl -sS -X POST http://%s/api/images/random", data.kubernetes_service_v1.app.status[0].load_balancer[0].ingress[0].hostname)
  }
}
