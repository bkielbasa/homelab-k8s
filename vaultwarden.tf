resource "kubernetes_namespace" "vaultwarden" {
  metadata {
    name = "vaultwarden"
  }
}

resource "helm_release" "vaultwarden" {
  name       = "vaultwarden"
  namespace  = kubernetes_namespace.vaultwarden.metadata[0].name
  chart      = "vaultwarden"
  repository = "https://guerzon.github.io/vaultwarden"
  version    = "0.38.0"

  values = [
    file("values/vaultwarden-values.yaml")
  ]
}
