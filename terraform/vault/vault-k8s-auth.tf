# Enable and configure the Kubernetes auth method in Vault.
# All other roots (auth, services) reference this backend by path ("kubernetes")
# and assume it already exists — apply vault root first on a fresh cluster.

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
