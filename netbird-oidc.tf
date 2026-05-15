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

# Service-account user the NetBird management server uses to sync users/groups
# from Authentik via the IdP-manager (client_credentials + password grant).
# Permissions (view_user/view_group) must be granted manually in the Authentik UI
# — the Terraform provider doesn't expose them as of writing.
resource "random_password" "netbird_idp" {
  length  = 32
  special = false
}

resource "authentik_user" "netbird_idp" {
  username = "netbird-idp"
  name     = "NetBird IdP Manager"
  type     = "service_account"
  path     = "service-accounts"
  password = random_password.netbird_idp.result
}

output "netbird_idp_password" {
  value     = random_password.netbird_idp.result
  sensitive = true
}
