# Authentik group whose members can log into ActualBudget via SSO.
# Membership managed manually in the Authentik UI.
resource "authentik_group" "actualbudget_users" {
  name = "actualbudget-users"
}

resource "authentik_provider_oauth2" "actualbudget" {
  name               = "actualbudget"
  client_id          = "actualbudget"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://budget.klimczak.xyz/openid/callback"
    },
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.scopes.ids,
    [authentik_property_mapping_provider_scope.groups.id],
  )
}

resource "authentik_application" "actualbudget" {
  name              = "ActualBudget"
  slug              = "actualbudget"
  protocol_provider = authentik_provider_oauth2.actualbudget.id
  meta_launch_url   = "https://budget.klimczak.xyz/"
}
