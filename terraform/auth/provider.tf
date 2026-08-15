provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "kubectl" {
  config_path = "~/.kube/config"
}

provider "vault" {
  address = "https://vault.klimczak.xyz"
  token   = var.vault_token
}

data "vault_kv_secret_v2" "authentik_app" {
  mount = "secret"
  name  = "authentik/app"
}

provider "authentik" {
  url   = "https://authentik.klimczak.xyz"
  token = data.vault_kv_secret_v2.authentik_app.data["bootstrap_token"]
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
