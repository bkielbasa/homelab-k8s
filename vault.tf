resource "helm_release" "vault" {
  name             = "vault"
  namespace        = "vault"
  chart            = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  version          = "0.28.0"
  create_namespace = true

  values = [
    file("values/vault-values.yaml")
  ]
} 