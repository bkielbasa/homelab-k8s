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
    authentik_application.headlamp,
    authentik_outpost_provider_attachment.headlamp,
  ]

  values = [
    file("values/headlamp.yaml")
  ]
}
