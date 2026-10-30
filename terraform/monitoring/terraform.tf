terraform {
  required_version = ">= 1.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    helm = {
      source = "hashicorp/helm"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
    ovh = {
      source  = "ovh/ovh"
      version = "2.7.0"
    }
    pihole = {
      source  = "ryanwholey/pihole"
      version = "2.0.0-beta.1"
    }
  }

  # State provided by infra-guy
  backend "s3" {}
}
