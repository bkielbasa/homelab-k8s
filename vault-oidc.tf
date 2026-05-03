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

  property_mappings = data.authentik_property_mapping_provider_scope.scopes.ids
}

resource "authentik_application" "vault" {
  name              = "Vault"
  slug              = "vault"
  protocol_provider = authentik_provider_oauth2.vault.id
  meta_launch_url   = "https://vault.klimczak.xyz"
}
