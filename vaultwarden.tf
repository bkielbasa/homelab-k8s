resource "helm_release" "vaultwarden" {
  name             = "vaultwarden"
  namespace        = "vaultwarden"
  chart            = "vaultwarden"
  repository       = "https://guerzon.github.io/vaultwarden"
  version          = "0.34.3"
  create_namespace = true

  values = [
    file("values/vaultwarden-values.yaml")
  ]
}
