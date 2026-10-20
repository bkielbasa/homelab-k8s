# The headlamp workload (Helm chart) is managed by Argo CD — see
# argocd-apps/headlamp.yaml. The OIDC client secret is no longer injected via
# helm_release.set_sensitive: it is synced from Vault into the headlamp-oidc
# Secret by ExternalSecret — see headlamp-vault.tf.
resource "kubernetes_namespace" "headlamp" {
  metadata {
    name = "headlamp"
    annotations = {
      "linkerd.io/inject" = "enabled"
    }
  }
}
