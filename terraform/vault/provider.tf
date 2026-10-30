provider "kubernetes" {}

provider "helm" {
  kubernetes = {}
}

provider "aws" {
  region = "eu-central-1"
}

provider "vault" {
  address = var.vault_addr
  token   = var.vault_token
}

provider "ovh" {
  endpoint           = "ovh-eu"
  application_key    = var.ovh_app_key
  application_secret = var.ovh_app_secret
  consumer_key       = var.ovh_consumer_key
}

provider "pihole" {
  url      = "http://192.168.1.29:8081"
  password = var.pihole_password
}
