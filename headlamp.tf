resource "kubernetes_namespace" "headlamp" {
  metadata {
    name = "headlamp"
    annotations = {
      "linkerd.io/inject" = "enabled"
    }
  }
}

resource "helm_release" "headlamp" {
  name       = "headlamp"
  namespace  = kubernetes_namespace.headlamp.metadata[0].name
  repository = "https://kubernetes-sigs.github.io/headlamp/"
  chart      = "headlamp"
  version    = "0.39.0"

  timeout = 600

  depends_on = [
    kubernetes_namespace.headlamp,
    authentik_provider_oauth2.headlamp,
  ]

  values = [
    file("values/headlamp.yaml")
  ]

  set_sensitive = [
    {
      name  = "config.oidc.clientSecret"
      value = authentik_provider_oauth2.headlamp.client_secret
    },
  ]
}
