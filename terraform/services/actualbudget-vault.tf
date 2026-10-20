# Vault/ESO glue for actualbudget's OIDC client secret.
#
# Argo CD (argocd-apps/actualbudget.yaml) manages the workload; this root only
# syncs the secret the chart reads via login.openid.existingSecret
# (values/actualbudget.yaml -> actualbudget-oidc).
#
# Vault path secret/oidc/actualbudget is written by terraform/auth/oidc-secrets.tf.

resource "kubernetes_service_account" "actualbudget" {
  metadata {
    name      = "actualbudget-sa"
    namespace = kubernetes_namespace.actualbudget.metadata[0].name
  }
}

resource "vault_policy" "actualbudget" {
  name = "actualbudget"

  policy = <<EOT
path "secret/data/oidc/actualbudget" {
  capabilities = ["read", "list"]
}
path "secret/metadata/oidc/actualbudget" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "actualbudget" {
  backend                          = "kubernetes"
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
    kubernetes_service_account.actualbudget,
    vault_kubernetes_auth_backend_role.actualbudget,
  ]
}

# clientId is public but also lives here so the chart has a single source for
# both OIDC credentials (it skips rendering its own copy when existingSecret
# is set).
resource "kubectl_manifest" "actualbudget_oidc_external_secret" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "actualbudget-oidc"
      namespace = kubernetes_namespace.actualbudget.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "actualbudget-oidc"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "clientSecret"
          remoteRef = {
            key      = "oidc/actualbudget"
            property = "clientSecret"
          }
        },
        { secretKey = "clientId", value = "actualbudget" },
      ]
    }
  })

  depends_on = [
    kubectl_manifest.actualbudget_vault_secret_store,
  ]
}
