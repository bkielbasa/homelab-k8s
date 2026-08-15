# Vault OIDC auth backend — configured against Authentik.
# The OIDC credentials are written to Vault KV by the auth root
# (terraform/auth) at secret/oidc/vault. We read them back here
# so this root has no dependency on auth's Terraform state.

data "vault_kv_secret_v2" "oidc_vault" {
  mount = "secret"
  name  = "oidc/vault"
}

# Full-access policy for human Vault admins authenticated via Authentik.
resource "vault_policy" "vault_admin" {
  name = "vault-admin"

  policy = <<EOT
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}

# OIDC auth method backed by Authentik.
resource "vault_jwt_auth_backend" "oidc" {
  type               = "oidc"
  path               = "oidc"
  oidc_discovery_url = "https://authentik.klimczak.xyz/application/o/vault/"
  oidc_client_id     = data.vault_kv_secret_v2.oidc_vault.data["clientId"]
  oidc_client_secret = data.vault_kv_secret_v2.oidc_vault.data["clientSecret"]
  default_role       = "default"
}

# Default role: gates access to vault-admins group, grants vault-admin policy.
resource "vault_jwt_auth_backend_role" "default" {
  backend         = vault_jwt_auth_backend.oidc.path
  role_name       = "default"
  role_type       = "oidc"
  user_claim      = "sub"
  groups_claim    = "groups"
  bound_audiences = [data.vault_kv_secret_v2.oidc_vault.data["clientId"]]
  oidc_scopes     = ["openid", "profile", "email", "groups"]

  bound_claims = {
    groups = data.vault_kv_secret_v2.oidc_vault.data["groupName"]
  }

  allowed_redirect_uris = [
    "https://vault.klimczak.xyz/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback",
  ]

  token_policies = [vault_policy.vault_admin.name]
  token_ttl      = 3600
  token_max_ttl  = 28800
}
