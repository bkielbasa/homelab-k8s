# Shared Authentik data sources and scope mappings used by all OIDC providers.
# Previously in vault-oidc.tf at the root; moved here since auth is the module
# that owns all Authentik provider resources.

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

# Built-in scope mappings for openid / profile / email / offline_access.
# offline_access is required so providers that need refresh tokens (Headlamp) can
# get them; harmless for providers that don't request it.
data "authentik_property_mapping_provider_scope" "scopes" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile",
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-offline_access",
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
