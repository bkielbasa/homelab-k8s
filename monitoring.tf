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

resource "helm_release" "loki" {
  name       = "loki"
  namespace  = "monitoring"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"

  values = [
    file("values/loki.yaml")
  ]
}

resource "helm_release" "alloy" {
  name       = "alloy"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  namespace  = "monitoring"
  version    = "0.9.2"
  
  values = [
    file("values/alloy.yaml")
  ]

  depends_on = [
    helm_release.loki
  ]
}
