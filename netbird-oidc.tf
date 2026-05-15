# Authentik group whose members can use NetBird VPN.
# Membership managed manually in the Authentik UI.
resource "authentik_group" "netbird_users" {
  name = "netbird-users"
}

resource "authentik_provider_oauth2" "netbird" {
  name               = "netbird"
  client_id          = "netbird"
  client_type        = "confidential"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://netbird.klimczak.xyz/auth/callback"
    },
    {
      matching_mode = "strict"
      url           = "https://netbird.klimczak.xyz/peers"
    },
    {
      matching_mode = "strict"
      url           = "http://localhost:53000"
    },
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.scopes.ids,
    [authentik_property_mapping_provider_scope.groups.id],
  )
}

resource "authentik_application" "netbird" {
  name              = "Netbird"
  slug              = "netbird"
  protocol_provider = authentik_provider_oauth2.netbird.id
  meta_launch_url   = "https://netbird.klimczak.xyz/"
  meta_icon         = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons@main/png/netbird.png"
}

resource "authentik_policy_binding" "netbird_users_required" {
  target = authentik_application.netbird.uuid
  group  = authentik_group.netbird_users.id
  order  = 0
}
