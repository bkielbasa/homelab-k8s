# Authentik group whose members can log into darek via SSO.
# Membership managed manually in the Authentik UI.
resource "authentik_group" "darek_users" {
  name = "darek-users"
}

resource "authentik_provider_oauth2" "darek" {
  name               = "darek"
  client_id          = "darek"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://darek.klimczak.xyz/auth/callback"
    },
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.scopes.ids,
    [authentik_property_mapping_provider_scope.groups.id],
  )
}

resource "authentik_application" "darek" {
  name              = "Darek"
  slug              = "darek"
  protocol_provider = authentik_provider_oauth2.darek.id
  meta_launch_url   = "https://darek.klimczak.xyz/"
  meta_icon         = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons@main/png/openid.png"
}
