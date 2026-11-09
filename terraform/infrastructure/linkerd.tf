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

resource "kubernetes_namespace" "linkerd" {
  metadata {
    name = "linkerd"
  }
}

resource "helm_release" "linkerd_crds" {
  name       = "linkerd-crds"
  repository = "https://helm.linkerd.io/stable"
  chart      = "linkerd-crds"
  namespace  = kubernetes_namespace.linkerd.metadata[0].name
}

resource "helm_release" "linkerd_control_plane" {
  name       = "linkerd-control-plane"
  repository = "https://helm.linkerd.io/stable"
  chart      = "linkerd-control-plane"
  namespace  = "linkerd"

  timeout    = 600
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

resource "kubernetes_namespace" "linkerd_viz" {
  metadata {
    name = "linkerd-viz"
  }
}

resource "helm_release" "linkerd_viz" {
  name       = "linkerd-viz"
  repository = "https://helm.linkerd.io/stable"
  chart      = "linkerd-viz"
  namespace  = kubernetes_namespace.linkerd_viz.metadata[0].name

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

# Linkerd monitoring removed: control plane is currently broken on NixOS
# nodes (missing ip_tables kernel module), so these targets never become
# healthy. Re-add once linkerd is fixed or replaced.
