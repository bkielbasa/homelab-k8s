# The ecommerce workload (Helm chart) is managed by Argo CD — see
# argocd-apps/ecommerce.yaml. This namespace + the Vault/ESO glue stay in
# Terraform.
#
# Prerequisites (run once, manually):
#   ./psql_create_db.sh ecommerce
#   vault kv put secret/ecommerce \
#     DATABASE_URL="postgres://ecommerce:PASS@postgresql.postgresql.svc.cluster.local:5432/ecommerce?sslmode=disable"
#
resource "kubernetes_namespace" "ecommerce" {
  metadata {
    name = "ecommerce"
  }
}

# The chart references this SA (serviceAccount.create = false) so the Vault
# Kubernetes auth role below binds to a name Terraform owns.
resource "kubernetes_service_account" "ecommerce" {
  metadata {
    name      = "ecommerce-sa"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
  }
}

resource "vault_policy" "ecommerce" {
  name = "ecommerce"

  policy = <<EOT
# Allow reading secrets for ecommerce
path "secret/data/ecommerce" {
  capabilities = ["read", "list"]
}

# Allow reading metadata
path "secret/metadata/ecommerce" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "ecommerce" {
  backend                          = "kubernetes"
  role_name                        = "ecommerce"
  bound_service_account_names      = ["ecommerce-sa"]
  bound_service_account_namespaces = ["ecommerce"]
  token_ttl                        = 3600
  token_policies                   = ["default", vault_policy.ecommerce.name]
}

resource "kubectl_manifest" "ecommerce_vault_secret_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "vault-backend"
      namespace = kubernetes_namespace.ecommerce.metadata[0].name
    }
    spec = {
      provider = {
        vault = {
          server  = "https://vault.klimczak.xyz"
          path    = "secret"
          version = "v2"
          auth = {
            kubernetes = {
              mountPath = "kubernetes"
              role      = "ecommerce"
              serviceAccountRef = {
                name = "ecommerce-sa"
              }
            }
          }
        }
      }
    }
  })

  depends_on = [
    kubernetes_service_account.ecommerce,
    vault_kubernetes_auth_backend_role.ecommerce,
  ]
}

# Pulls every field of `secret/data/ecommerce` into a K8s Secret named
# `ecommerce-env`. The chart feeds it to the container via envFrom, so each
# Vault field becomes an env var of the same name (DATABASE_URL today; a
# session secret or SMTP password later needs no chart change).
resource "kubectl_manifest" "ecommerce_db_external_secret" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "ecommerce-db"
      namespace = kubernetes_namespace.ecommerce.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "ecommerce-env"
        creationPolicy = "Owner"
      }
      dataFrom = [
        {
          extract = {
            key = "ecommerce"
          }
        }
      ]
    }
  })

  depends_on = [
    kubectl_manifest.ecommerce_vault_secret_store
  ]
}
