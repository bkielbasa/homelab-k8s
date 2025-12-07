resource "helm_release" "uptime-kuma" {
  name       = "uptime-kuma"
  namespace  = kubernetes_namespace.uptime-kuma.metadata[0].name
  repository = "https://helm.irsigler.cloud"
  chart      = "uptime-kuma"
  version    = "2.24.0"

  values = [
    file("values/uptime-kuma.yaml")
  ]

    depends_on = [
      ovh_domain_zone_record.uptime-kuma,
      helm_release.mariadb
    ]
}

resource "kubernetes_namespace" "uptime-kuma" {
  metadata {
    name = "uptime-kuma"
  }
}
