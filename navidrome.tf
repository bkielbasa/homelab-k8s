resource "kubernetes_namespace" "navidrome" {
  metadata {
    name = "navidrome"
  }
}
