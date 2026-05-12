resource "helm_release" "actualbudget" {
  name       = "actualbudget"
  namespace  = "actualbudget"
  repository = "https://community-charts.github.io/helm-charts"
  chart      = "actualbudget"
  create_namespace = true

  # Two values files: the image tag is auto-bumped by an external bot that
  # historically overwrites the entire file it touches. Keeping ingress and
  # other persistent config in a separate values file insulates them from
  # the bot.
  values = [
    file("values/actualbudget.yaml"),
    file("values/actualbudget-image.yaml"),
  ]
}
