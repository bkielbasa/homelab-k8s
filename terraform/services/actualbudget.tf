# The actualbudget workload (Helm chart) is managed by Argo CD — see
# argocd-apps/actualbudget.yaml. The OIDC client secret is no longer injected
# via helm_release.set_sensitive: it is synced from Vault into the
# actualbudget-oidc Secret by ExternalSecret — see actualbudget-vault.tf.
resource "kubernetes_namespace" "actualbudget" {
  metadata {
    name = "actualbudget"
    annotations = {
      "linkerd.io/inject" = "enabled"
    }
  }
}
