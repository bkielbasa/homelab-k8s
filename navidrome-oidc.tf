# Authentik group whose members can log into Navidrome via SSO.
# Membership managed manually in the Authentik UI.
resource "authentik_group" "navidrome_users" {
  name = "navidrome-users"
}

resource "authentik_provider_oauth2" "navidrome" {
  name               = "navidrome"
  client_id          = "navidrome"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://audio.klimczak.xyz/auth/oidc/callback"
    },
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.scopes.ids,
    [authentik_property_mapping_provider_scope.groups.id],
  )
}

resource "authentik_application" "navidrome" {
  name              = "Navidrome"
  slug              = "navidrome"
  protocol_provider = authentik_provider_oauth2.navidrome.id
  meta_launch_url   = "https://audio.klimczak.xyz"
  meta_icon         = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons@main/png/navidrome.png"
}

resource "authentik_policy_binding" "navidrome_users_required" {
  target = authentik_application.navidrome.uuid
  group  = authentik_group.navidrome_users.id
  order  = 0
}
