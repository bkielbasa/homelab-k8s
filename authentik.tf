resource "kubernetes_namespace" "authentik" {
  metadata {
    name = "authentik"
    annotations = {
      "linkerd.io/inject" = "enabled"
    }
  }
}

resource "helm_release" "authentik" {
  name       = "authentik"
  namespace  = kubernetes_namespace.authentik.metadata[0].name
  repository = "https://charts.goauthentik.io"
  chart      = "authentik"
  version    = "2026.2.2"

  timeout = 600

  depends_on = [
    kubectl_manifest.authentik_app_external_secret,
    kubectl_manifest.authentik_postgres_external_secret,
  ]

  values = [
    file("values/authentik.yaml")
  ]
}
