# The qbittorrent workload (Helm chart) is managed by Argo CD — see
# argocd-apps/qbittorrent.yaml. Only the namespace stays in Terraform.
resource "kubernetes_namespace" "qbittorrent" {
  metadata {
    name = "qbittorrent"
  }
}
