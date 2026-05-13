resource "helm_release" "freshrss" {
  name             = "freshrss"
  namespace        = "freshrss"
  chart            = "./helm/freshrss"
  create_namespace = true

  values = [
    file("values/freshrss.yaml")
  ]

  set_sensitive = [
    {
      name  = "oidc.clientSecret"
      value = authentik_provider_oauth2.freshrss.client_secret
    },
  ]
}
