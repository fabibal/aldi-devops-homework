terraform {
  required_version = ">= 1.5"

  required_providers { # new
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-homework" # new
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "kind-homework" # new
  }
}
