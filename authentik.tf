resource "kubernetes_namespace" "authentik" {
  metadata {
    name = "authentik"
    annotations = {
      "linkerd.io/inject" = "enabled"
    }
  }
}
