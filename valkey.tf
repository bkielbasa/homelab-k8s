resource "helm_release" "valkey" {
  name       = "valkey"
  namespace  = "valkey"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "valkey"
  create_namespace = true
  version = "5.0.1"

  values = [
    file("values/valkey.yaml")
  ]
}
