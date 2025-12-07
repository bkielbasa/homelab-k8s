resource "helm_release" "vault" {
  name       = "vault"
  namespace  = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = "0.31.0"
  create_namespace = true

  values = [
    file("values/vault.yaml")
  ]
}

resource "helm_release" "external-secrets" {
  name       = "external-secrets"
  namespace  = "external-secrets-system"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  create_namespace = true
  version = "0.20.3"

  values = [
    yamlencode({
      installCRDs = true
    })
  ]
}


