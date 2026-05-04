# Authentik group whose members can log into Headlamp.
# Membership is managed manually in the Authentik UI.
resource "authentik_group" "headlamp_users" {
  name = "headlamp-users"
}

resource "authentik_provider_oauth2" "headlamp" {
  name               = "headlamp"
  client_id          = "headlamp"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://headlamp.klimczak.xyz/oidc-callback"
    },
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.scopes.ids,
    [authentik_property_mapping_provider_scope.groups.id],
  )
}

resource "authentik_application" "headlamp" {
  name              = "Headlamp"
  slug              = "headlamp"
  protocol_provider = authentik_provider_oauth2.headlamp.id
  meta_launch_url   = "https://headlamp.klimczak.xyz"
}
