# Authentik group whose members can log into FreshRSS via SSO.
# Membership managed manually in the Authentik UI.
resource "authentik_group" "freshrss_users" {
  name = "freshrss-users"
}

resource "authentik_provider_oauth2" "freshrss" {
  name               = "freshrss"
  client_id          = "freshrss"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://rss.klimczak.xyz/i/oidc/"
    },
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.scopes.ids,
    [authentik_property_mapping_provider_scope.groups.id],
  )
}

resource "authentik_application" "freshrss" {
  name              = "FreshRSS"
  slug              = "freshrss"
  protocol_provider = authentik_provider_oauth2.freshrss.id
  meta_launch_url   = "https://rss.klimczak.xyz/"
}
