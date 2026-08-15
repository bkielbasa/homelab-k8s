# Read the ActualBudget OIDC client secret from Vault.
# Written there by terraform/auth after the Authentik provider is created.
data "vault_kv_secret_v2" "oidc_actualbudget" {
  mount = "secret"
  name  = "oidc/actualbudget"
}

resource "kubernetes_namespace" "actualbudget" {
  metadata {
    name = "actualbudget"
    annotations = {
      "linkerd.io/inject" = "enabled"
    }
  }
}

resource "helm_release" "actualbudget" {
  name       = "actualbudget"
  namespace  = kubernetes_namespace.actualbudget.metadata[0].name
  repository = "https://community-charts.github.io/helm-charts"
  chart      = "actualbudget"

  # Two values files: the image tag is auto-bumped by an external bot that
  # historically overwrites the entire file it touches. Keeping ingress and
  # other persistent config in a separate values file insulates them from
  # the bot.
  values = [
    file("${path.module}/../../values/actualbudget.yaml"),
    file("${path.module}/../../values/actualbudget-image.yaml"),
  ]

  set_sensitive = [
    {
      name  = "login.openid.clientSecret"
      value = data.vault_kv_secret_v2.oidc_actualbudget.data["clientSecret"]
    },
  ]
}
