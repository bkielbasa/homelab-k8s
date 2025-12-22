resource "helm_release" "nextcloud" {
  name             = "nextcloud"
  namespace        = kubernetes_namespace.nextcloud.metadata[0].name
  repository = "https://nextcloud.github.io/helm/"
  chart      = "nextcloud"
  version    = "8.5.0"

  depends_on = [
    kubectl_manifest.nextcloud_postgres_external_secret,
    kubectl_manifest.nextcloud_admin_external_secret
  ]

  values = [
    file("values/nextcloud.yaml")
  ]
}

resource "kubernetes_namespace" "nextcloud" {
  metadata {
    name = "nextcloud"
      annotations = {
        "linkerd.io/inject" = "enabled"
      }
  }
}

