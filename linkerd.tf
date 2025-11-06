resource "tls_private_key" "trustanchor_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "trustanchor_cert" {
  private_key_pem = tls_private_key.trustanchor_key.private_key_pem

  subject {
    common_name = "root.linkerd.cluster.local"
  }

  validity_period_hours = 87600 # 10 years
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

resource "tls_private_key" "issuer_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "issuer_req" {
  private_key_pem = tls_private_key.issuer_key.private_key_pem

  subject {
    common_name = "identity.linkerd.cluster.local"
  }
}

resource "tls_locally_signed_cert" "issuer_cert" {
  cert_request_pem   = tls_cert_request.issuer_req.cert_request_pem
  ca_private_key_pem = tls_private_key.trustanchor_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.trustanchor_cert.cert_pem

  validity_period_hours = 8760 # 1 year
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

resource "helm_release" "linkerd_crds" {
  name             = "linkerd-crds"
  repository       = "https://helm.linkerd.io/stable"
  chart            = "linkerd-crds"
  namespace        = "linkerd"
  create_namespace = true
}

resource "helm_release" "linkerd_control_plane" {
  name       = "linkerd-control-plane"
  repository = "https://helm.linkerd.io/stable"
  chart      = "linkerd-control-plane"
  namespace  = "linkerd"

  depends_on = [helm_release.linkerd_crds]

  values = [
    yamlencode({
      identityTrustAnchorsPEM = tls_self_signed_cert.trustanchor_cert.cert_pem
      identity = {
        issuer = {
          tls = {
            crtPEM = tls_locally_signed_cert.issuer_cert.cert_pem
            keyPEM = tls_private_key.issuer_key.private_key_pem
          }
        }
      }
    })
  ]
}

resource "helm_release" "linkerd_viz" {
  name             = "linkerd-viz"
  repository       = "https://helm.linkerd.io/stable"
  chart            = "linkerd-viz"
  namespace        = "linkerd-viz"
  create_namespace = true

  depends_on = [helm_release.linkerd_control_plane]

  values = [
    yamlencode({
      prometheus = {
        enabled = false
      }
      prometheusUrl = "http://prometheus-kube-prometheus-prometheus.monitoring:9090"
      
      # Let Linkerd create ServiceMonitors with correct selectors
      installNamespace = false
      dashboard = {
        enforcedHostRegexp = ".*"
      }
    })
  ]
}

resource "kubernetes_manifest" "linkerd_proxy_podmonitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      name      = "linkerd-proxy"
      namespace = "monitoring"  # Put it in monitoring namespace where Prometheus is
      labels = {
        "release" = "prometheus"
      }
    }
    spec = {
      selector = {
        matchExpressions = [
          {
            key      = "linkerd.io/control-plane-ns"
            operator = "Exists"
          }
        ]
      }
      namespaceSelector = {
        any = true  # Scrape from all namespaces
      }
      podMetricsEndpoints = [
        {
          port     = "linkerd-admin"
          interval = "30s"
          path     = "/metrics"
          relabelings = [
            {
              sourceLabels = ["__meta_kubernetes_pod_container_name"]
              action       = "keep"
              regex        = "linkerd-proxy"
            },
            {
              sourceLabels = ["__meta_kubernetes_namespace"]
              targetLabel  = "namespace"
            },
            {
              sourceLabels = ["__meta_kubernetes_pod_name"]
              targetLabel  = "pod"
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.linkerd_control_plane]
}

# PodMonitor for Linkerd control plane
resource "kubernetes_manifest" "linkerd_control_plane_podmonitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      name      = "linkerd-control-plane"
      namespace = "monitoring"
      labels = {
        "release" = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "linkerd.io/control-plane-ns" = "linkerd"
        }
      }
      namespaceSelector = {
        matchNames = ["linkerd"]
      }
      podMetricsEndpoints = [
        {
          port     = "admin-http"
          interval = "30s"
          path     = "/metrics"
        }
      ]
    }
  }

  depends_on = [helm_release.linkerd_control_plane]
}
