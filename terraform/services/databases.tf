# Shared infrastructure databases.
#
# The workloads (Helm charts) are managed by Argo CD — see argocd-apps/
# mariadb.yaml, valkey.yaml, postgresql.yaml. Only the namespaces stay here.

resource "kubernetes_namespace" "mariadb" {
  metadata {
    name = "mariadb"
  }
}

resource "kubernetes_namespace" "postgresql" {
  metadata {
    name = "postgresql"
  }
}

resource "kubernetes_namespace" "valkey" {
  metadata {
    name = "valkey"
  }
}
