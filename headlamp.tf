resource "kubernetes_namespace" "headlamp" {
  metadata {
    name = "headlamp"
    annotations = {
      "linkerd.io/inject" = "enabled"
    }
  }
}

resource "helm_release" "headlamp" {
  name       = "headlamp"
  namespace  = kubernetes_namespace.headlamp.metadata[0].name
  repository = "https://kubernetes-sigs.github.io/headlamp/"
  chart      = "headlamp"
  version    = "0.41.0"

  timeout = 600

  depends_on = [
    authentik_application.headlamp,
    authentik_outpost_provider_attachment.headlamp,
    authentik_provider_oauth2.kubernetes,
  ]

  values = [
    file("values/headlamp.yaml")
  ]

  set_sensitive = [
    {
      name  = "config.oidc.clientSecret"
      value = authentik_provider_oauth2.kubernetes.client_secret
    },
  ]
}

# Routes /outpost.goauthentik.io/* on headlamp.klimczak.xyz directly to the
# Authentik server pod so the protected host can serve start/callback/sign-out
# pages. Required because Authentik's outpost only recognizes a flow when the
# Host header matches the ProxyProvider's external_host (headlamp.klimczak.xyz).
resource "kubernetes_ingress_v1" "headlamp_outpost" {
  metadata {
    name      = "headlamp-outpost"
    namespace = "authentik"
    annotations = {
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
      "cert-manager.io/cluster-issuer"           = "letsencrypt-prod-dns"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "headlamp.klimczak.xyz"
      http {
        path {
          path      = "/outpost.goauthentik.io"
          path_type = "Prefix"
          backend {
            service {
              name = "authentik-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    tls {
      hosts       = ["headlamp.klimczak.xyz"]
      secret_name = "headlamp-tls"
    }
  }
}
