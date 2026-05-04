# Authentik group whose members can log into Nextcloud.
resource "authentik_group" "nextcloud_users" {
  name = "nextcloud-users"
}

# Authentik group whose members get Nextcloud admin role.
resource "authentik_group" "nextcloud_admins" {
  name = "nextcloud-admins"
}

resource "authentik_provider_oauth2" "nextcloud" {
  name               = "nextcloud"
  client_id          = "nextcloud"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://klimczak.xyz/apps/user_oidc/code"
    },
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.scopes.ids,
    [authentik_property_mapping_provider_scope.groups.id],
  )
}

resource "authentik_application" "nextcloud" {
  name              = "Nextcloud"
  slug              = "nextcloud"
  protocol_provider = authentik_provider_oauth2.nextcloud.id
  meta_launch_url   = "https://klimczak.xyz/apps/user_oidc/login/1"
}
