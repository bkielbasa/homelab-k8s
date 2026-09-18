# ---------------------------------------------------------------------------
# Workspace
# ---------------------------------------------------------------------------

resource "authentik_group" "workspace_users" {
  name = "workspace-users"
}

# For single-operator Authentik there is no email-verification source, so the
# managed email scope mapping always returns email_verified=False — and the
# app correctly refuses an "unverified" address. This custom scope mapping
# asserts verified on behalf of the IdP: the operator vouches for the
# directory. We remove the managed email mapping from this provider's scope
# list so both don't claim the same "email" scope.
resource "authentik_property_mapping_provider_scope" "workspace_email" {
  name       = "workspace-email-verified"
  scope_name = "email"
  expression = <<-EOF
    return {
        "email": request.user.email,
        "email_verified": True,
    }
  EOF
}

data "authentik_property_mapping_provider_scope" "email_default" {
  managed = "goauthentik.io/providers/oauth2/scope-email"
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
    [
      for id in data.authentik_property_mapping_provider_scope.scopes.ids :
      id if id != data.authentik_property_mapping_provider_scope.email_default.id
    ],
    [
      authentik_property_mapping_provider_scope.workspace_email.id,
      authentik_property_mapping_provider_scope.groups.id,
    ],
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