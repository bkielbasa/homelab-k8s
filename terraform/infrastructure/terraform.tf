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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # State is provided by the external runner (infra-guy) via
  # ~infraguy_backend_override.tf.json. Keep this empty so the same module
  # works locally with `terraform init -backend-config=...`.
  backend "s3" {}
}
