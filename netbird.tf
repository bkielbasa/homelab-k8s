resource "kubernetes_namespace" "netbird" {
  metadata {
    name        = "netbird"
    # NetBird management/signal speak long-lived gRPC; Linkerd injection
    # interferes with those streams. Keep injection off (no annotation).
    annotations = {}
  }
}

resource "helm_release" "netbird" {
  name       = "netbird"
  namespace  = kubernetes_namespace.netbird.metadata[0].name
  repository = "https://netbirdio.github.io/helms"
  chart      = "netbird"
  version    = "1.9.0"

  timeout = 600

  depends_on = [
    kubectl_manifest.netbird_external_secret,
  ]

  values = [
    file("values/netbird.yaml")
  ]
}

locals {
  netbird_router_image = yamldecode(file("values/netbird-router-image.yaml")).image
}

resource "kubernetes_manifest" "netbird_router_daemonset" {
  manifest = {
    apiVersion = "apps/v1"
    kind       = "DaemonSet"
    metadata = {
      name      = "netbird-router"
      namespace = kubernetes_namespace.netbird.metadata[0].name
      labels = {
        app = "netbird-router"
      }
    }
    spec = {
      selector = {
        matchLabels = { app = "netbird-router" }
      }
      template = {
        metadata = {
          labels = { app = "netbird-router" }
        }
        spec = {
          hostNetwork = true
          dnsPolicy   = "ClusterFirstWithHostNet"
          nodeSelector = {
            "kubernetes.io/hostname" = "laptop"
          }
          containers = [
            {
              name  = "netbird"
              image = "netbirdio/netbird:${local.netbird_router_image.tag}"
              securityContext = {
                privileged = false
                capabilities = {
                  add = ["NET_ADMIN", "SYS_MODULE"]
                }
              }
              env = [
                {
                  name  = "NB_MANAGEMENT_URL"
                  value = "https://netbird.klimczak.xyz"
                },
                {
                  name = "NB_SETUP_KEY"
                  valueFrom = {
                    secretKeyRef = {
                      name = "netbird-router"
                      key  = "setup_key"
                    }
                  }
                },
                {
                  name  = "NB_HOSTNAME"
                  value = "homelab-router"
                },
              ]
              volumeMounts = [
                {
                  name      = "netbird-config"
                  mountPath = "/etc/netbird"
                },
              ]
            },
          ]
          volumes = [
            {
              name = "netbird-config"
              emptyDir = {}
            },
          ]
        }
      }
    }
  }

  depends_on = [
    helm_release.netbird,
    kubectl_manifest.netbird_external_secret,
  ]
}
