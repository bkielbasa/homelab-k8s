# The darek workload (Helm chart) is managed by Argo CD — see
# argocd-apps/darek.yaml. This namespace + the Vault/ESO glue in
# darek-vault.tf stay in Terraform.
resource "kubernetes_namespace" "darek" {
  metadata {
    name = "darek"
    annotations = {
      "linkerd.io/inject" = "enabled"
    }
  }
}
