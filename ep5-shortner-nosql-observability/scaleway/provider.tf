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

# Grafana provider → per-project Cockpit endpoint. URL derived from project ID.
# auth = IAM API key secret (bearer). secret_key is apply-time computed →
# two-phase apply on first run (Makefile + dashboard.tf).
provider "grafana" {
  url  = format("https://%s.dashboard.cockpit.scaleway.com", data.scaleway_account_project.current.id)
  auth = scaleway_iam_api_key.grafana.secret_key
}
