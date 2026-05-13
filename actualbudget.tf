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
    file("values/actualbudget.yaml"),
    file("values/actualbudget-image.yaml"),
  ]
}
