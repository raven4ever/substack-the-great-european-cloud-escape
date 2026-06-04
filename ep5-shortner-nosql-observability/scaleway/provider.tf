terraform {
  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
    random = {
      source = "hashicorp/random"
    }
    time = {
      source = "hashicorp/time"
    }
    local = {
      source = "hashicorp/local"
    }
    grafana = {
      source = "grafana/grafana"
    }
  }
}

provider "scaleway" {
}

provider "docker" {
  registry_auth {
    address  = split("/", scaleway_registry_namespace.app.endpoint)[0]
    username = "nologin"
    password = scaleway_iam_api_key.registry.secret_key
  }
}

# Grafana → Cockpit. Anonymous mode + X-Auth-Token = Scaleway IAM secret.
# Scaleway's IAM proxy auths; Grafana itself doesn't validate creds.
# Pattern per scaleway_cockpit_grafana data source docs.
provider "grafana" {
  url  = trimsuffix(data.scaleway_cockpit_grafana.main.grafana_url, "/")
  auth = "anonymous"

  http_headers = {
    "X-Auth-Token" = scaleway_iam_api_key.grafana.secret_key
  }

  retries = 5
}
