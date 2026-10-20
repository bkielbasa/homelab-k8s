# The vaultwarden workload (Helm chart) is managed by Argo CD — see
# argocd-apps/vaultwarden.yaml. Only the namespace stays in Terraform.
resource "kubernetes_namespace" "vaultwarden" {
  metadata {
    name = "vaultwarden"
  }
}
