# OIDC for kube-apiserver via Authentik.
# kube-apiserver validates tokens issued by this provider; Headlamp and kubectl
# use it for the login dance. Group membership in `kubernetes-admins` maps to
# cluster-admin via the ClusterRoleBinding below.

resource "authentik_group" "kubernetes_admins" {
  name = "kubernetes-admins"
}

resource "authentik_provider_oauth2" "kubernetes" {
  name               = "kubernetes"
  client_id          = "kubernetes"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://headlamp.klimczak.xyz/oidc-callback"
    },
    # kubectl oidc-login plugin opens a local HTTP server.
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
    [authentik_property_mapping_provider_scope.groups.id],
  )
}

resource "authentik_application" "kubernetes" {
  name              = "Kubernetes"
  slug              = "kubernetes"
  protocol_provider = authentik_provider_oauth2.kubernetes.id
  meta_launch_url   = "https://headlamp.klimczak.xyz"
  meta_icon         = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons@main/png/kubernetes.png"
}

resource "authentik_policy_binding" "kubernetes_admins_required" {
  target = authentik_application.kubernetes.uuid
  group  = authentik_group.kubernetes_admins.id
  order  = 0
}

# RBAC: bind the OIDC-prefixed group from kube-apiserver to cluster-admin.
# kube-apiserver injects oidc:<group> for tokens authenticated via this provider.
resource "kubernetes_cluster_role_binding" "oidc_kubernetes_admins" {
  metadata {
    name = "oidc-kubernetes-admins"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = "oidc:kubernetes-admins"
  }
}
