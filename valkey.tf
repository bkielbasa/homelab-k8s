resource "kubernetes_namespace" "valkey" {
  metadata {
    name = "valkey"
  }
}

resource "helm_release" "valkey" {
  name       = "valkey"
  namespace  = kubernetes_namespace.valkey.metadata[0].name
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "valkey"
  version    = "5.0.1"

  timeout = 600

  values = [
    file("values/valkey.yaml")
  ]
}
