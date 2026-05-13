resource "kubernetes_service_account" "actualbudget" {
  metadata {
    name      = "actualbudget-sa"
    namespace = kubernetes_namespace.actualbudget.metadata[0].name
  }
}

resource "vault_policy" "actualbudget" {
  name = "actualbudget"

  policy = <<EOT
path "secret/data/actualbudget/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/actualbudget/*" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "actualbudget" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "actualbudget"
  bound_service_account_names      = ["actualbudget-sa"]
  bound_service_account_namespaces = ["actualbudget"]
  token_ttl                        = 3600
  token_policies                   = ["default", vault_policy.actualbudget.name]
}

resource "kubectl_manifest" "actualbudget_vault_secret_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "vault-backend"
      namespace = kubernetes_namespace.actualbudget.metadata[0].name
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
              role      = "actualbudget"
              serviceAccountRef = {
                name = "actualbudget-sa"
              }
            }
          }
        }
      }
    }
  })

  depends_on = [
    helm_release.external-secrets,
    kubernetes_service_account.actualbudget,
    vault_kubernetes_auth_backend_role.actualbudget,
  ]
}

# Pulls `secret/data/actualbudget/gocardless` from Vault into a k8s Secret
# with keys matching the env vars that actualbudget reads at startup.
# Vault key layout (set manually):
#   vault kv put secret/actualbudget/gocardless secret_id=... secret_key=...
resource "kubectl_manifest" "actualbudget_gocardless_external_secret" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "actualbudget-gocardless"
      namespace = kubernetes_namespace.actualbudget.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "actualbudget-gocardless"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "ACTUAL_GOCARDLESS_SECRET_ID"
          remoteRef = {
            key      = "actualbudget/gocardless"
            property = "secret_id"
          }
        },
        {
          secretKey = "ACTUAL_GOCARDLESS_SECRET_KEY"
          remoteRef = {
            key      = "actualbudget/gocardless"
            property = "secret_key"
          }
        }
      ]
    }
  })

  depends_on = [
    kubectl_manifest.actualbudget_vault_secret_store,
  ]
}

# Patch the helm-managed Deployment to add envFrom referencing the Secret
# produced by the ExternalSecret. Server-side apply with our own field
# manager so subsequent helm upgrades don't strip the addition.
# `optional: true` keeps the pod starting even if the Vault secret hasn't
# been populated yet.
resource "kubectl_manifest" "actualbudget_envfrom_patch" {
  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "actualbudget"
      namespace = kubernetes_namespace.actualbudget.metadata[0].name
    }
    spec = {
      template = {
        spec = {
          containers = [
            {
              name = "actualbudget"
              envFrom = [
                {
                  secretRef = {
                    name     = "actualbudget-gocardless"
                    optional = true
                  }
                }
              ]
            }
          ]
        }
      }
    }
  })

  server_side_apply = true
  force_conflicts   = true

  depends_on = [
    helm_release.actualbudget,
    kubectl_manifest.actualbudget_gocardless_external_secret,
  ]
}
