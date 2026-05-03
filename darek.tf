resource "helm_release" "darek" {
  name             = "darek"
  namespace        = "darek"
  chart            = "./helm/darek"
  create_namespace = true

  values = [
    file("values/darek.yaml")
  ]
}
