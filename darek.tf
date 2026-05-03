resource "kubernetes_namespace" "darek" {
  metadata {
    name = "darek"
    annotations = {
      "linkerd.io/inject" = "enabled"
    }
  }
}

resource "helm_release" "darek" {
  name      = "darek"
  namespace = kubernetes_namespace.darek.metadata[0].name
  chart     = "./helm/darek"

  depends_on = [
    kubectl_manifest.darek_env_external_secret,
  ]

  values = [
    file("values/darek.yaml")
  ]
}
