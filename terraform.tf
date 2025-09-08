terraform {
  required_version = ">= 1.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
    }

    pihole = {
      source = "ryanwholey/pihole"
      version = "2.0.0-beta.1"
    }

    ovh = {
      source = "ovh/ovh"
      version = "2.7.0"
    }
  }

  # S3 backend configuration for state storage
  backend "s3" {
    bucket         = "homelab-terr"
    key            = "homelab-k8s/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "homelab-k8s-terraform-locks"  # Optional: for state locking
  }
} 
