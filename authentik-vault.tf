resource "kubernetes_service_account" "authentik" {
  metadata {
    name      = "authentik"
    namespace = kubernetes_namespace.authentik.metadata[0].name
  }
}

resource "vault_policy" "authentik" {
  name = "authentik"

  policy = <<EOT
# Allow reading secrets for Authentik
path "secret/data/authentik/*" {
  capabilities = ["read", "list"]
}

# Allow reading metadata
path "secret/metadata/authentik/*" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "authentik" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "authentik"
  bound_service_account_names      = ["authentik"]
  bound_service_account_namespaces = ["authentik"]
  token_ttl                        = 3600
  token_policies                   = ["default", vault_policy.authentik.name]
}
