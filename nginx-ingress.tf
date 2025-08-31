resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  namespace  = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.7.1"

  create_namespace = true

  values = [
    yamlencode({
      controller = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "metallb.universe.tf/address-pool" = "nginx-ip-pool"
          }
        }
        hostNetwork = true
        config = {
          "ssl-redirect" = "true"
          "force-ssl-redirect" = "true"
          "ssl-protocols" = "TLSv1.2 TLSv1.3"
          "ssl-ciphers" = "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384"
          "client-max-body-size" = "500m"
        }
      }
    })
  ]
} 