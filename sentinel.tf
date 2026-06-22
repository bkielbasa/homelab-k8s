# The sentinel workload (Helm chart) is managed by Argo CD — see
# argocd-apps/sentinel.yaml. This namespace + the Vault/ESO glue in
# sentinel-vault.tf stay in Terraform.
resource "kubernetes_namespace" "sentinel" {
  metadata {
    name = "sentinel"
  }
}
