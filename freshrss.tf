resource "helm_release" "freshrss" {
  name             = "freshrss"
  namespace        = "freshrss"
  chart            = "./helm/freshrss"
  create_namespace = true

  values = [
    file("values/freshrss.yaml")
  ]
}
