terraform {
  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
    }
    random = {
      source = "hashicorp/random"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    time = {
      source = "hashicorp/time"
    }
    local = {
      source = "hashicorp/local"
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

provider "helm" {
  kubernetes = {
    host                   = scaleway_k8s_cluster.app.kubeconfig[0].host
    token                  = scaleway_k8s_cluster.app.kubeconfig[0].token
    cluster_ca_certificate = base64decode(scaleway_k8s_cluster.app.kubeconfig[0].cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = scaleway_k8s_cluster.app.kubeconfig[0].host
  token                  = scaleway_k8s_cluster.app.kubeconfig[0].token
  cluster_ca_certificate = base64decode(scaleway_k8s_cluster.app.kubeconfig[0].cluster_ca_certificate)
}
