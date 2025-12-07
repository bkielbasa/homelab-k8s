resource "helm_release" "mariadb" {
  name       = "mariadb"
  namespace  = kubernetes_namespace.mariadb.metadata[0].name
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "mariadb"

  values = [
    file("values/mariadb.yaml")
  ]
}

resource "kubernetes_namespace" "mariadb" {
  metadata {
    name = "mariadb"
  }
}
