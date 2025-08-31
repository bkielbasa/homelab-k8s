resource "helm_release" "homepage" {
  name             = "homepage"
  namespace        = "homepage"
  chart            = "./helm/homepage"
  create_namespace = true

  values = [
    file("./helm/homepage/values.yaml")
  ]
}
