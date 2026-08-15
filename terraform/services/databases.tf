# Shared infrastructure databases.

resource "kubernetes_namespace" "mariadb" {
  metadata {
    name = "mariadb"
  }
}

resource "helm_release" "mariadb" {
  name       = "mariadb"
  namespace  = kubernetes_namespace.mariadb.metadata[0].name
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "mariadb"

  values = [
    file("${path.module}/../../values/mariadb.yaml")
  ]
}

resource "kubernetes_namespace" "postgresql" {
  metadata {
    name = "postgresql"
  }
}

resource "helm_release" "postgresql" {
  name      = "postgresql"
  namespace = kubernetes_namespace.postgresql.metadata[0].name
  chart     = "${path.module}/../../helm/postgresql"
}

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
    file("${path.module}/../../values/valkey.yaml")
  ]
}
