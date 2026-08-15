# The navidrome workload (Helm chart) is managed by Argo CD — see
# argocd-apps/navidrome.yaml. Only the namespace stays in Terraform.
resource "kubernetes_namespace" "navidrome" {
  metadata {
    name = "navidrome"
  }
}
