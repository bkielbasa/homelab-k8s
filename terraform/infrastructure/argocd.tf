# Read the ArgoCD OIDC client secret from Vault.
# Written there by terraform/auth after the Authentik provider is created.
data "vault_kv_secret_v2" "oidc_argocd" {
  mount = "secret"
  name  = "oidc/argocd"
}


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
    file("${path.module}/../../values/argocd.yaml")
  ]

  # Inject the Authentik OIDC client secret into argocd-secret. The dotted key
  # `oidc.argocd.clientSecret` is referenced by oidc.config in values/argocd.yaml;
  # dots in the key are escaped so Helm writes one key rather than nesting.
  set_sensitive = [
    {
      name  = "configs.secret.extra.oidc\\.argocd\\.clientSecret"
      value = data.vault_kv_secret_v2.oidc_argocd.data["clientSecret"]
    },
  ]

  depends_on = [
    ovh_domain_zone_record.argocd,
    pihole_dns_record.argocd,
  ]
}

resource "ovh_domain_zone_record" "argocd" {
  zone      = "klimczak.xyz"
  subdomain = "argo"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "pihole_dns_record" "argocd" {
  domain = "argo.klimczak.xyz"
  ip     = "192.168.1.30"
}

# App-of-apps: every Application manifest in argocd-apps/*.yaml is applied to
# the cluster from git (and pruned when its file is removed). This replaces
# the manual `kubectl apply argocd-apps/` step — see docs/improvements.md #7.
#
# NOTE: ApplicationSet's git *directory* generator only produces path
# parameters from a single static spec.template, so it cannot drive a
# directory of full Application manifests with per-app sources — the
# app-of-apps Application is the right primitive for that.
resource "kubernetes_manifest" "homelab_apps" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "homelab-apps"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      sources = [
        {
          repoURL        = "https://github.com/bkielbasa/homelab-k8s"
          targetRevision = "master"
          path           = "argocd-apps"
        }
      ]
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd,
  ]
}
