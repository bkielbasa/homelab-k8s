resource "kubernetes_namespace" "postgresql" {
  metadata {
    name = "postgresql"
  }
}

resource "helm_release" "postgresql" {
  name      = "postgresql"
  namespace = kubernetes_namespace.postgresql.metadata[0].name
  chart     = "./helm/postgresql"
}
