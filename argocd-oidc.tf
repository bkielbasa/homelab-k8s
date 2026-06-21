# Authentik group whose members get admin access to Argo CD.
# Membership managed manually in the Authentik UI.
resource "authentik_group" "argocd_admins" {
  name = "argocd-admins"
}

resource "authentik_provider_oauth2" "argocd" {
  name               = "argocd"
  client_id          = "argocd"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://argo.klimczak.xyz/auth/callback"
    },
    # argocd CLI SSO login opens a local HTTP server on :8085.
    {
      matching_mode = "strict"
      url           = "http://localhost:8085/auth/callback"
    },
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.scopes.ids,
    [authentik_property_mapping_provider_scope.groups.id],
  )

  # No client_secret output: consumed directly by argocd.tf via set_sensitive.
}

resource "authentik_application" "argocd" {
  name              = "Argo CD"
  slug              = "argocd"
  protocol_provider = authentik_provider_oauth2.argocd.id
  meta_launch_url   = "https://argo.klimczak.xyz/"
  meta_icon         = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons@main/png/argo-cd.png"
}

# Only members of argocd-admins may launch/authenticate to the application.
resource "authentik_policy_binding" "argocd_admins_required" {
  target = authentik_application.argocd.uuid
  group  = authentik_group.argocd_admins.id
  order  = 0
}
