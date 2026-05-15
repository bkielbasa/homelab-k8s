# Authentik group whose members can use NetBird VPN.
# Membership managed manually in the Authentik UI.
resource "authentik_group" "netbird_users" {
  name = "netbird-users"
}

# Built-in scope mapping that grants Authentik REST API access on the
# access_token issued for OAuth flows. Required so NetBird's IdP-manager
# can list users/groups via /api/v3/core/*.
data "authentik_property_mapping_provider_scope" "api_access" {
  scope_name = "goauthentik.io/api"
}

resource "authentik_provider_oauth2" "netbird" {
  name               = "netbird"
  client_id          = "netbird"
  client_type        = "confidential"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    # NetBird dashboard (hash-fragment SPA routes used by oidc-client-ts)
    {
      matching_mode = "strict"
      url           = "https://netbird.klimczak.xyz/#callback"
    },
    {
      matching_mode = "strict"
      url           = "https://netbird.klimczak.xyz/#silent-callback"
    },
    # NetBird CLI device-flow callback (random ephemeral port)
    {
      matching_mode = "regex"
      url           = "http://localhost:[0-9]+"
    },
    {
      matching_mode = "regex"
      url           = "http://127.0.0.1:[0-9]+"
    },
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.scopes.ids,
    [
      authentik_property_mapping_provider_scope.groups.id,
      data.authentik_property_mapping_provider_scope.api_access.id,
    ],
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
# from Authentik via the IdP-manager.
#
# Despite the chart's env-var name (`IDP_SERVICE_ACCOUNT_PASSWORD`), Authentik's
# `client_credentials` + username/password flow expects the value to be an
# Authentik **App Password (token)**, NOT a regular login password.
#
# Permissions (view_user/view_group) must be granted manually in the Authentik
# UI — the Terraform provider doesn't expose them as of writing.
data "authentik_group" "admins" {
  name = "authentik Admins"
}

resource "authentik_user" "netbird_idp" {
  username = "netbird-idp"
  name     = "NetBird IdP Manager"
  type     = "service_account"
  path     = "service-accounts"
  # Required for Authentik's client_credentials grant: the service-account user
  # must have access to the application (via netbird-users → policy binding).
  # The authentik Admins group is the brute-force grant needed for
  # NetBird's IdP-manager to call /api/v3/core/users/ and groups APIs — the
  # role-based permissions weren't enough; revisit when a narrower role works.
  groups = [
    authentik_group.netbird_users.id,
    data.authentik_group.admins.id,
  ]
}

resource "authentik_token" "netbird_idp" {
  identifier   = "netbird-idp-token"
  user         = authentik_user.netbird_idp.id
  description  = "App password used by NetBird IdP-manager (client_credentials grant)"
  expiring     = false
  intent       = "app_password"
  retrieve_key = true
}

output "netbird_idp_password" {
  value     = authentik_token.netbird_idp.key
  sensitive = true
}
