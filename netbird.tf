resource "kubernetes_namespace" "netbird" {
  metadata {
    name        = "netbird"
    # NetBird management/signal speak long-lived gRPC; Linkerd injection
    # interferes with those streams. Keep injection off (no annotation).
    annotations = {}
  }
}
