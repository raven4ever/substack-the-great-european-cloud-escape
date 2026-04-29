terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    random = {
      source = "hashicorp/random"
    }
    tls = {
      source = "hashicorp/tls"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
    helm = {
      source = "hashicorp/helm"
    }
    http = {
      source = "hashicorp/http"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "aws" {
}

provider "docker" {
  registry_auth {
    address  = replace(data.aws_ecr_authorization_token.token.proxy_endpoint, "https://", "")
    username = data.aws_ecr_authorization_token.token.user_name
    password = data.aws_ecr_authorization_token.token.password
  }
}

provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.app.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.app.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubernetes" {
  host                   = aws_eks_cluster.app.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.app.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}
