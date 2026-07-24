resource "kubernetes_namespace" "vault" {
  metadata {
    name = "vault"
  }
}

resource "helm_release" "vault" {
  name       = "vault"
  namespace  = kubernetes_namespace.vault.metadata[0].name
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = "0.31.0"

  values = [
    file("values/vault.yaml")
  ]

  # Pods reference vault-unseal-aws Secret via extraSecretEnvironmentVars.
  # The Secret must exist before the StatefulSet rolls or the new pod fails
  # to start.
  depends_on = [kubernetes_secret.vault_unseal_aws]
}

resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets-system"
  }
}

resource "helm_release" "external-secrets" {
  name       = "external-secrets"
  namespace  = kubernetes_namespace.external_secrets.metadata[0].name
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "0.20.3"

  values = [
    yamlencode({
      installCRDs = true
    })
  ]
}


