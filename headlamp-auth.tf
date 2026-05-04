# Authentik group whose members can sign into Headlamp via forward-auth.
# Membership is managed manually in the Authentik UI.
resource "authentik_group" "headlamp_users" {
  name = "headlamp-users"
}

# ProxyProvider in forward_single mode for Headlamp.
# nginx-ingress forward-auth hits the embedded outpost; Authentik validates the
# session cookie and either passes the request through or redirects to login.
resource "authentik_provider_proxy" "headlamp" {
  name               = "headlamp"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  external_host      = "https://headlamp.klimczak.xyz"
  mode               = "forward_single"
}

# Application linked to the proxy provider.
# Same slug as the previous OIDC-backed application so the app library entry
# is reused.
resource "authentik_application" "headlamp" {
  name              = "Headlamp"
  slug              = "headlamp"
  protocol_provider = authentik_provider_proxy.headlamp.id
  meta_launch_url   = "https://headlamp.klimczak.xyz"
}

# Policy: only members of headlamp-users may authenticate to this app.
resource "authentik_policy_binding" "headlamp_user_required" {
  target = authentik_application.headlamp.uuid
  group  = authentik_group.headlamp_users.id
  order  = 0
}

# Look up the existing embedded outpost by name.
data "authentik_outpost" "embedded" {
  name = "authentik Embedded Outpost"
}

# Attach the headlamp proxy provider to the embedded outpost so it can serve
# forward-auth requests. Using outpost_provider_attachment avoids overwriting
# the embedded outpost's full provider list (which Authentik manages itself).
resource "authentik_outpost_provider_attachment" "headlamp" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.headlamp.id
}
