resource "kubernetes_namespace" "sentinel" {
  metadata {
    name = "sentinel"
  }
}

resource "helm_release" "sentinel" {
  name      = "sentinel"
  namespace = kubernetes_namespace.sentinel.metadata[0].name
  chart     = "./helm/sentinel-sre"

  values = [
    file("values/sentinel-sre.yaml")
  ]

  # The ANTHROPIC_API_KEY / DATABASE_URL Secrets are synced by External
  # Secrets; make sure they exist before the Deployment rolls.
  depends_on = [
    kubectl_manifest.sentinel_external_secret,
    kubectl_manifest.sentinel_ghcr_external_secret,
  ]
}
