# ---------------------------------------------------------------------------
# Workspace
# ---------------------------------------------------------------------------

resource "authentik_group" "workspace_users" {
  name = "workspace-users"
}

resource "authentik_provider_oauth2" "workspace" {
  name               = "workspace"
  client_id          = "workspace"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://cloudlift.run/login/sso/callback"
    },
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.scopes.ids,
    [authentik_property_mapping_provider_scope.groups.id],
  )
}

resource "authentik_application" "workspace" {
  name              = "Workspace"
  slug              = "workspace"
  protocol_provider = authentik_provider_oauth2.workspace.id
  meta_launch_url   = "https://mail.cloudlift.run/"
  meta_icon         = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons@main/png/manjaro.png"
}

resource "authentik_policy_binding" "workspace_users_required" {
  target = authentik_application.workspace.uuid
  group  = authentik_group.workspace_users.id
  order  = 0
}