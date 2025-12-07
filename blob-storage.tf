resource "helm_release" "blob-storage" {
  name             = "blob-storage"
  chart            = "./helm/blob-storage"
  namespace  = kubernetes_namespace.blob-storage.metadata[0].name

  depends_on = [
    kubernetes_namespace.blob-storage,
    ovh_domain_zone_record.blob-storage,
    pihole_dns_record.blob-storage
  ]

  values = [
    file("values/blob-storage.yaml")
  ]
}

resource "kubernetes_namespace" "blob-storage" {
  metadata {
    name = "blob-storage"
      annotations = {
        "linkerd.io/inject" = "enabled"
      }
  }

}
