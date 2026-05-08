resource "kubernetes_namespace" "jellyfin" {
  metadata {
    name = "jellyfin"
  }
}

resource "helm_release" "jellyfin" {
  name       = "jellyfin"
  namespace  = kubernetes_namespace.jellyfin.metadata[0].name
  repository = "https://jellyfin.github.io/jellyfin-helm"
  chart      = "jellyfin"
  version    = "3.2.0"

  values = [
    file("values/jellyfin.yaml")
  ]
}
