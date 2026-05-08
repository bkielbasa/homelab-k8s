# Authentik group whose members can log into Jellyfin via SSO.
# Membership managed manually in the Authentik UI.
resource "authentik_group" "jellyfin_users" {
  name = "jellyfin-users"
}

resource "authentik_provider_oauth2" "jellyfin" {
  name               = "jellyfin"
  client_id          = "jellyfin"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://media.klimczak.xyz/sso/OID/redirect/authentik"
    },
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.scopes.ids,
    [authentik_property_mapping_provider_scope.groups.id],
  )
}

resource "authentik_application" "jellyfin" {
  name              = "Jellyfin"
  slug              = "jellyfin"
  protocol_provider = authentik_provider_oauth2.jellyfin.id
  meta_launch_url   = "https://media.klimczak.xyz/sso/OID/start/authentik"
}

# Sensitive output — used once when configuring the SSO plugin in Jellyfin's
# admin UI. Retrieve via:
#   terraform output -raw jellyfin_oidc_client_secret
output "jellyfin_oidc_client_secret" {
  value     = authentik_provider_oauth2.jellyfin.client_secret
  sensitive = true
}
