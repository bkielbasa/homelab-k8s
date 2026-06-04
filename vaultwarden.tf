resource "helm_release" "vaultwarden" {
  name             = "vaultwarden"
  namespace        = "vaultwarden"
  chart            = "vaultwarden"
  repository       = "https://guerzon.github.io/vaultwarden"
  version          = "0.38.0"
  create_namespace = true

  values = [
    file("values/vaultwarden-values.yaml")
  ]
}
