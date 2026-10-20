# The jellyfin workload (Helm chart) is managed by Argo CD — see
# argocd-apps/jellyfin.yaml. Only the namespace stays in Terraform. The
# config/media PVCs (root-level jellyfin-*-pvc/pv.yaml) are managed outside
# Terraform entirely.
resource "kubernetes_namespace" "jellyfin" {
  metadata {
    name = "jellyfin"
  }
}
