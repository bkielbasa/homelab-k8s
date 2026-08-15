# OIDC providers for all application services.
# The Authentik providers live here (auth module); the helm releases and
# Vault/ESO wiring live in the services module.

# ---------------------------------------------------------------------------
# Jellyfin
# ---------------------------------------------------------------------------

resource "authentik_group" "jellyfin_users" {
  name = "jellyfin-users"
}

resource "authentik_group" "jellyfin_admins" {
  name = "jellyfin-admins"
}

resource "authentik_provider_oauth2" "jellyfin" {
  name               = "jellyfin"
  client_id          = "jellyfin"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://media.klimczak.xyz/sso/OID/redirect/authentik"
    },
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.scopes.ids,
    [authentik_property_mapping_provider_scope.groups.id],
  )
}

resource "authentik_application" "jellyfin" {
  name              = "Jellyfin"
  slug              = "jellyfin"
  protocol_provider = authentik_provider_oauth2.jellyfin.id
  meta_launch_url   = "https://media.klimczak.xyz/sso/OID/start/authentik"
  meta_icon         = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons@main/png/jellyfin.png"
}

# ---------------------------------------------------------------------------
# ActualBudget
# ---------------------------------------------------------------------------

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
  meta_icon         = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons@main/png/actual-budget.png"
}

# ---------------------------------------------------------------------------
# Darek
# ---------------------------------------------------------------------------

resource "authentik_group" "darek_users" {
  name = "darek-users"
}

resource "authentik_provider_oauth2" "darek" {
  name               = "darek"
  client_id          = "darek"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://darek.klimczak.xyz/auth/callback"
    },
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.scopes.ids,
    [authentik_property_mapping_provider_scope.groups.id],
  )
}

resource "authentik_application" "darek" {
  name              = "Darek"
  slug              = "darek"
  protocol_provider = authentik_provider_oauth2.darek.id
  meta_launch_url   = "https://darek.klimczak.xyz/"
  meta_icon         = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons@main/png/openid.png"
}

# ---------------------------------------------------------------------------
# FreshRSS
# ---------------------------------------------------------------------------

resource "authentik_group" "freshrss_users" {
  name = "freshrss-users"
}

resource "authentik_provider_oauth2" "freshrss" {
  name               = "freshrss"
  client_id          = "freshrss"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://rss.klimczak.xyz:443/i/oidc/"
    },
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.scopes.ids,
    [authentik_property_mapping_provider_scope.groups.id],
  )
}

resource "authentik_application" "freshrss" {
  name              = "FreshRSS"
  slug              = "freshrss"
  protocol_provider = authentik_provider_oauth2.freshrss.id
  meta_launch_url   = "https://rss.klimczak.xyz/"
  meta_icon         = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons@main/png/freshrss.png"
}

# ---------------------------------------------------------------------------
# Navidrome
# ---------------------------------------------------------------------------

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
