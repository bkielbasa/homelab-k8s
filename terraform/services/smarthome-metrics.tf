# The smarthome-metrics workload (Helm chart) is managed by Argo CD — see
# argocd-apps/smarthome-metrics.yaml. This namespace + the Vault/ESO glue stay in Terraform.
resource "kubernetes_namespace" "smarthome_metrics" {
  metadata {
    name = "smarthome"
  }
}

resource "kubernetes_service_account" "smarthome_metrics" {
  metadata {
    name      = "smarthome-metrics-sa"
    namespace = kubernetes_namespace.smarthome_metrics.metadata[0].name
  }
}

resource "vault_policy" "smarthome_metrics" {
  name = "smarthome-metrics"

  policy = <<EOT
# Allow reading secrets for smarthome-metrics
path "secret/data/smarthome-metrics" {
  capabilities = ["read", "list"]
}

# Allow reading metadata
path "secret/metadata/smarthome-metrics" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "smarthome_metrics" {
  backend                          = "kubernetes"
  role_name                        = "smarthome-metrics"
  bound_service_account_names      = ["smarthome-metrics-sa"]
  bound_service_account_namespaces = ["smarthome"]
  token_ttl                        = 3600
  token_policies                   = ["default", vault_policy.smarthome_metrics.name]
}

resource "kubectl_manifest" "smarthome_metrics_vault_secret_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "vault-backend"
      namespace = kubernetes_namespace.smarthome_metrics.metadata[0].name
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
              role      = "smarthome-metrics"
              serviceAccountRef = {
                name = "smarthome-metrics-sa"
              }
            }
          }
        }
      }
    }
  })

  depends_on = [
    kubernetes_service_account.smarthome_metrics,
    vault_kubernetes_auth_backend_role.smarthome_metrics,
  ]
}

# Pulls every field of `secret/data/smarthome-metrics` into a K8s Secret named
# `smarthome-metrics-env`. The chart reads DATABASE_URL out of it via
# database.urlSecretKey. A secretKeyRef cannot cross namespaces, so the
# credentials have to be materialised in smarthome rather than read in place
# from the postgresql namespace.
#
# Prerequisites (run once, manually):
#   vault kv put secret/smarthome-metrics \
#     DATABASE_URL="postgres://homelabmetrics:PASS@postgresql.postgresql.svc.cluster.local:5432/homelabmetrics?sslmode=disable"
#
resource "kubectl_manifest" "smarthome_metrics_db_external_secret" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "smarthome-metrics-db"
      namespace = kubernetes_namespace.smarthome_metrics.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "smarthome-metrics-env"
        creationPolicy = "Owner"
      }
      dataFrom = [
        {
          extract = {
            key = "smarthome-metrics"
          }
        }
      ]
    }
  })

  depends_on = [
    kubectl_manifest.smarthome_metrics_vault_secret_store
  ]
}
