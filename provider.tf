provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "kubectl" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

provider "ovh" {
  endpoint      = "ovh-eu"
  application_key    = var.ovh_app_key
  application_secret = var.ovh_app_secret
  consumer_key       = var.ovh_consumer_key
}

data "ovh_me" "myaccount" {}

data "ovh_order_cart" "mycart" {
  ovh_subsidiary = data.ovh_me.myaccount.ovh_subsidiary
}

provider "vault" {
  address = "https://vault.klimczak.xyz"
  token = var.vault_token
}

# Enable Kubernetes auth method in Vault
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

# Get Kubernetes info for Vault configuration
data "kubernetes_service_account" "vault_auth" {
  metadata {
    name      = "vault"
    namespace = "vault"
  }
}

# Configure Kubernetes auth backend
resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  backend            = vault_auth_backend.kubernetes.path
  kubernetes_host    = "https://kubernetes.default.svc:443"
  
  disable_local_ca_jwt = false

  lifecycle {
    ignore_changes = [
      kubernetes_ca_cert,
      token_reviewer_jwt
    ]
  }
}

# Data source for the service account token (if using older K8s)
data "kubernetes_secret" "vault_token" {
  metadata {
    name      = "vault-token"
    namespace = "vault"
  }
}
