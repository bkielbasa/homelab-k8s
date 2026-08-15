# Read the Kubernetes/Headlamp OIDC client secret from Vault.
# Written there by terraform/auth after the Authentik provider is created.
data "vault_kv_secret_v2" "oidc_headlamp" {
  mount = "secret"
  name  = "oidc/headlamp"
}

resource "kubernetes_namespace" "headlamp" {
  metadata {
    name = "headlamp"
    annotations = {
      "linkerd.io/inject" = "enabled"
    }
  }
}

resource "helm_release" "headlamp" {
  name       = "headlamp"
  namespace  = kubernetes_namespace.headlamp.metadata[0].name
  repository = "https://kubernetes-sigs.github.io/headlamp/"
  chart      = "headlamp"
  version    = "0.41.0"

  timeout = 600

  values = [
    file("${path.module}/../../values/headlamp.yaml")
  ]

  set_sensitive = [
    {
      name  = "config.oidc.clientSecret"
      value = data.vault_kv_secret_v2.oidc_headlamp.data["clientSecret"]
    },
  ]
}
