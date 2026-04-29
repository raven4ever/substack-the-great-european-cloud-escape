

output "curl_commands" {
  value = {
    list_animals            = format("curl -sS http://%s/api/animals", data.kubernetes_service_v1.app.status[0].load_balancer[0].ingress[0].hostname)
    list_species            = format("curl -sS http://%s/api/species", data.kubernetes_service_v1.app.status[0].load_balancer[0].ingress[0].hostname)
    list_animals_by_species = format("curl -sS http://%s/api/species/1/animals", data.kubernetes_service_v1.app.status[0].load_balancer[0].ingress[0].hostname)
    upload_random_image     = format("curl -sS -X POST http://%s/api/images/random", data.kubernetes_service_v1.app.status[0].load_balancer[0].ingress[0].hostname)
  }
}
