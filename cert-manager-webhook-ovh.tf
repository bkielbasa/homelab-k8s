resource "kubernetes_secret" "ovh_credentials" {
  metadata {
    name      = "ovh-credentials"
    namespace = "cert-manager"
  }

  data = {
    applicationKey    = var.ovh_app_key
    applicationSecret = var.ovh_app_secret
    consumerKey       = var.ovh_consumer_key
  }

  type = "Opaque"
}

resource "helm_release" "cert_manager_webhook_ovh" {
  name       = "cert-manager-webhook-ovh"
  namespace  = "cert-manager"
  repository = "https://aureq.github.io/cert-manager-webhook-ovh/"
  chart      = "cert-manager-webhook-ovh"
  version    = "0.9.9"

  values = [
    yamlencode({
      groupName = "acme.klimczak.xyz"

      certManager = {
        namespace          = "cert-manager"
        serviceAccountName = "cert-manager"
      }

      issuers = [
        {
          name           = "letsencrypt-prod-dns"
          create         = true
          kind           = "ClusterIssuer"
          acmeServerUrl  = "https://acme-v02.api.letsencrypt.org/directory"
          email          = "bartek@klimczak.xyz"
          ovhEndpointName        = "ovh-eu"
          ovhAuthenticationMethod = "application"
          ovhAuthenticationRef = {
            applicationKeyRef = {
              name = "ovh-credentials"
              key  = "applicationKey"
            }
            applicationSecretRef = {
              name = "ovh-credentials"
              key  = "applicationSecret"
            }
            applicationConsumerKeyRef = {
              name = "ovh-credentials"
              key  = "consumerKey"
            }
          }
        },
        {
          name           = "letsencrypt-staging-dns"
          create         = true
          kind           = "ClusterIssuer"
          acmeServerUrl  = "https://acme-staging-v02.api.letsencrypt.org/directory"
          email          = "bartek@klimczak.xyz"
          ovhEndpointName        = "ovh-eu"
          ovhAuthenticationMethod = "application"
          ovhAuthenticationRef = {
            applicationKeyRef = {
              name = "ovh-credentials"
              key  = "applicationKey"
            }
            applicationSecretRef = {
              name = "ovh-credentials"
              key  = "applicationSecret"
            }
            applicationConsumerKeyRef = {
              name = "ovh-credentials"
              key  = "consumerKey"
            }
          }
        },
      ]
    })
  ]

  depends_on = [kubernetes_secret.ovh_credentials]
}
