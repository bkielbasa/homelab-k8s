resource "helm_release" "prometheus" {
  name       = "prometheus"
  namespace  = "monitoring"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "70.4.1"

  values = [
    file("values/prometheus.yaml")
  ]
}

# resource "helm_release" "loki" {
#   name       = "loki"
#   namespace  = "monitoring"
#   repository = "https://grafana.github.io/helm-charts"
#   chart      = "loki-stack"
#   version    = "2.10.2"

#   values = [
#     file("values/loki.yaml")
#   ]

#   depends_on = [helm_release.prometheus]
# }

