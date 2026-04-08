terraform {
  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
    }
    cloudinit = {
      source = "hashicorp/cloudinit"
    }
  }
}

provider "scaleway" {
}
