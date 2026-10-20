# Grafana's OIDC client secret and the smarthome-metrics DB password are
# synced from Vault into the grafana-env Secret by ExternalSecret — see
# grafana-vault.tf. The workloads (prometheus/loki/alloy/tempo) are managed
# by Argo CD — see argocd-apps/*.yaml. This root keeps the DNS records and
# the linkerd-proxy ServiceMonitor.

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
