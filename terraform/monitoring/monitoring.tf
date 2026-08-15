# Read the Grafana OIDC client secret from Vault.
# Written there by terraform/auth after the Authentik provider is created.
data "vault_kv_secret_v2" "oidc_grafana" {
  mount = "secret"
  name  = "oidc/grafana"
}

resource "ovh_domain_zone_record" "grafana" {
  zone      = "klimczak.xyz"
  subdomain = "grafana"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "pihole_dns_record" "grafana" {
  domain = "grafana.klimczak.xyz"
  ip     = "192.168.1.30"
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  namespace  = "monitoring"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "70.4.1"

  values = [
    file("${path.module}/../../values/prometheus.yaml")
  ]

  set_sensitive = [
    {
      name  = "grafana.env.GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET"
      value = data.vault_kv_secret_v2.oidc_grafana.data["clientSecret"]
    },
  ]
}

resource "helm_release" "loki" {
  name       = "loki"
  namespace  = "monitoring"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"

  values = [
    file("${path.module}/../../values/loki.yaml")
  ]
}

resource "helm_release" "alloy" {
  name       = "alloy"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  namespace  = "monitoring"
  version    = "0.9.2"

  values = [
    file("${path.module}/../../values/alloy.yaml")
  ]

  depends_on = [
    helm_release.loki,
    helm_release.tempo
  ]
}

resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  namespace  = "monitoring"
  version    = "1.10.1"

  values = [
    file("${path.module}/../../values/tempo.yaml")
  ]

  depends_on = [
    helm_release.prometheus
  ]
}

resource "kubernetes_manifest" "linkerd_proxy_servicemonitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "linkerd-proxy"
      namespace = "monitoring"
      labels = {
        "app.kubernetes.io/name"      = "linkerd-proxy"
        "app.kubernetes.io/component" = "proxy"
      }
    }
    spec = {
      jobLabel = "linkerd-proxy"
      selector = {
        matchLabels = {
          "linkerd.io/control-plane-component" = "proxy"
        }
      }
      namespaceSelector = {
        any = true
      }
      endpoints = [
        {
          port     = "linkerd-admin"
          interval = "30s"
          path     = "/metrics"
          relabelings = [
            {
              sourceLabels = ["__meta_kubernetes_pod_container_name"]
              action       = "keep"
              regex        = "^linkerd-proxy$"
            },
            {
              sourceLabels = ["__meta_kubernetes_namespace"]
              targetLabel  = "namespace"
            },
            {
              sourceLabels = ["__meta_kubernetes_pod_name"]
              targetLabel  = "pod"
            },
            {
              sourceLabels = ["__meta_kubernetes_pod_label_linkerd_io_proxy_deployment"]
              targetLabel  = "deployment"
            }
          ]
        }
      ]
    }
  }
}
