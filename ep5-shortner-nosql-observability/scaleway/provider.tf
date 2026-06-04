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

# Grafana → Cockpit endpoint per project. auth = Grafana SA token from var.
# Scaleway IAM keys are NOT Grafana credentials — create SA in Cockpit UI first.
provider "grafana" {
  url     = format("https://%s.dashboard.cockpit.scaleway.com", data.scaleway_account_project.current.id)
  auth    = var.grafana_auth
  retries = 5
}
