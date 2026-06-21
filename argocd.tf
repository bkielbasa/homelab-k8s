resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "9.6.0"

  # Multi-component chart on RPi hardware; allow extra startup time like authentik.
  timeout = 600

  values = [
    file("values/argocd.yaml")
  ]

  # Inject the Authentik OIDC client secret into argocd-secret. The dotted key
  # `oidc.argocd.clientSecret` is referenced by oidc.config in values/argocd.yaml;
  # dots in the key are escaped so Helm writes one key rather than nesting.
  set_sensitive = [
    {
      name  = "configs.secret.extra.oidc\\.argocd\\.clientSecret"
      value = authentik_provider_oauth2.argocd.client_secret
    },
  ]

  # Pull the rest of the Argo CD stack into this resource's dependency closure so
  # `terraform apply -target=helm_release.argocd` installs everything in one shot:
  # both DNS records (public OVH + local Pi-hole) and the Authentik application +
  # group + policy binding (the latter transitively covers the group and app).
  depends_on = [
    authentik_application.argocd,
    authentik_policy_binding.argocd_admins_required,
    ovh_domain_zone_record.argocd,
    pihole_dns_record.argocd,
  ]
}
