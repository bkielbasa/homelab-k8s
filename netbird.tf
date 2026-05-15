resource "kubernetes_namespace" "netbird" {
  metadata {
    name        = "netbird"
    # NetBird management/signal speak long-lived gRPC; Linkerd injection
    # interferes with those streams. Keep injection off (no annotation).
    annotations = {}
  }
}

resource "helm_release" "netbird" {
  name       = "netbird"
  namespace  = kubernetes_namespace.netbird.metadata[0].name
  repository = "https://netbirdio.github.io/helms"
  chart      = "netbird"
  version    = "1.9.0"

  timeout = 600

  depends_on = [
    kubectl_manifest.netbird_external_secret,
  ]

  values = [
    file("values/netbird.yaml")
  ]
}
