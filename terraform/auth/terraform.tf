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
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2026.2"
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

  backend "s3" {
    bucket       = "homelab-terr"
    key          = "homelab-k8s/auth/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    profile      = "homelab"
    use_lockfile = true
  }
}
