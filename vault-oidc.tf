# Authentik group whose members get admin access to Vault.
# Membership is managed manually in the Authentik UI; not in Terraform
# (would require importing existing users for a single-user homelab).
resource "authentik_group" "vault_admins" {
  name = "vault-admins"
}

# Authentik ships a self-signed cert used to sign ID tokens.
data "authentik_certificate_key_pair" "default" {
  name = "authentik Self-signed Certificate"
}

# Default authorization flow that ships with Authentik.
data "authentik_flow" "default_authorization_flow" {
  slug = "default-provider-authorization-implicit-consent"
}

# Default invalidation flow that ships with Authentik.
data "authentik_flow" "default_invalidation_flow" {
  slug = "default-provider-invalidation-flow"
}

# Built-in scope mappings for openid / profile / email.
data "authentik_property_mapping_provider_scope" "scopes" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile",
    "goauthentik.io/providers/oauth2/scope-email",
  ]
}

# Custom scope mapping that emits group memberships in the OIDC token.
# Required because the default profile scope uses request.user.groups.all()
# (Django's generic relation) which may not resolve Authentik groups correctly;
# ak_groups is the canonical accessor. Vault needs the "groups" claim to map
# vault-admins → vault-admin policy.
resource "authentik_property_mapping_provider_scope" "groups" {
  name       = "OAuth2 groups"
  scope_name = "groups"
  expression = <<-EOT
    return {
      "groups": [group.name for group in request.user.ak_groups.all()],
    }
  EOT
}

resource "authentik_provider_oauth2" "vault" {
  name               = "vault"
  client_id          = "vault"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://vault.klimczak.xyz/ui/vault/auth/oidc/oidc/callback"
    },
    {
      matching_mode = "strict"
      url           = "http://localhost:8250/oidc/callback"
    },
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.scopes.ids,
    [authentik_property_mapping_provider_scope.groups.id],
  )
}

resource "authentik_application" "vault" {
  name              = "Vault"
  slug              = "vault"
  protocol_provider = authentik_provider_oauth2.vault.id
  meta_launch_url   = "https://vault.klimczak.xyz"
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
  oidc_client_id     = authentik_provider_oauth2.vault.client_id
  oidc_client_secret = authentik_provider_oauth2.vault.client_secret
  default_role       = "default"
}

# Default role: gates access to vault-admins group, grants vault-admin policy.
resource "vault_jwt_auth_backend_role" "default" {
  backend         = vault_jwt_auth_backend.oidc.path
  role_name       = "default"
  role_type       = "oidc"
  user_claim      = "sub"
  groups_claim    = "groups"
  bound_audiences = [authentik_provider_oauth2.vault.client_id]

  bound_claims = {
    groups = authentik_group.vault_admins.name
  }

  allowed_redirect_uris = [
    "https://vault.klimczak.xyz/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback",
  ]

  token_policies = [vault_policy.vault_admin.name]
  token_ttl      = 3600
  token_max_ttl  = 28800
}
