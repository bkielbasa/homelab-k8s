terraform {
  required_version = ">= 1.0"

  required_providers {
    pihole = {
      source  = "ryanwholey/pihole"
      version = "2.0.0-beta.1"
    }

    ovh = {
      source  = "ovh/ovh"
      version = "2.7.0"
    }
  }

  # Root state: apex DNS records and netbird pre-created records only.
  backend "s3" {
    bucket       = "homelab-terr"
    key          = "homelab-k8s/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    profile      = "homelab"
    use_lockfile = true
  }
}
