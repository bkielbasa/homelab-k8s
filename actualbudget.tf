resource "helm_release" "actualbudget" {
  name       = "actualbudget"
  namespace  = "actualbudget"
  repository = "https://community-charts.github.io/helm-charts"
  chart      = "actualbudget"
  create_namespace = true

  values = [
    file("values/actualbudget.yaml")
  ]
}
