# Vault/ESO glue for headlamp's OIDC client secret.
#
# Argo CD (argocd-apps/headlamp.yaml) manages the workload; this root only
# syncs the secret the chart reads via config.oidc.externalSecret
# (values/headlamp.yaml -> envFrom secretRef headlamp-oidc).
#
# Vault path secret/oidc/headlamp is written by terraform/auth/oidc-secrets.tf.

resource "kubernetes_service_account" "headlamp" {
  metadata {
    name      = "headlamp-sa"
    namespace = kubernetes_namespace.headlamp.metadata[0].name
  }
}

resource "vault_policy" "headlamp" {
  name = "headlamp"

  policy = <<EOT
path "secret/data/oidc/headlamp" {
  capabilities = ["read", "list"]
}
path "secret/metadata/oidc/headlamp" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "headlamp" {
  backend                          = "kubernetes"
  role_name                        = "headlamp"
  bound_service_account_names      = ["headlamp-sa"]
  bound_service_account_namespaces = ["headlamp"]
  token_ttl                        = 3600
  token_policies                   = ["default", vault_policy.headlamp.name]
}

resource "kubectl_manifest" "headlamp_vault_secret_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "vault-backend"
      namespace = kubernetes_namespace.headlamp.metadata[0].name
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
              role      = "headlamp"
              serviceAccountRef = {
                name = "headlamp-sa"
              }
            }
          }
        }
      }
    }
  })

  depends_on = [
    kubernetes_service_account.headlamp,
    vault_kubernetes_auth_backend_role.headlamp,
  ]
}

# The chart's externalSecret mode reads OIDC_* env keys from an existing
# Secret via envFrom, so this Secret carries the full OIDC config: only
# clientSecret is sensitive and comes from Vault; the rest is static config
# that used to live in chart values.
resource "kubectl_manifest" "headlamp_oidc_external_secret" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "headlamp-oidc"
      namespace = kubernetes_namespace.headlamp.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "headlamp-oidc"
        creationPolicy = "Owner"
        template = {
          # Static, non-secret OIDC config (same values the chart used to
          # template into its own secret). spec.data only accepts remoteRef
          # entries in external-secrets.io/v1, so statics go in the template.
          data = {
            OIDC_CLIENT_ID            = "kubernetes"
            OIDC_ISSUER_URL           = "https://authentik.klimczak.xyz/application/o/kubernetes/"
            OIDC_SCOPES               = "openid profile email groups offline_access"
            OIDC_CALLBACK_URL         = "https://headlamp.klimczak.xyz/oidc-callback"
            OIDC_VALIDATOR_CLIENT_ID  = "kubernetes"
            OIDC_VALIDATOR_ISSUER_URL = "https://authentik.klimczak.xyz/application/o/kubernetes/"
            # Fetched values only enter the rendered secret via the template
            # context — plain spec.data keys are NOT merged when target.template
            # is set.
            OIDC_CLIENT_SECRET = "{{ .OIDC_CLIENT_SECRET }}"
          }
        }
      }
      data = [
        {
          secretKey = "OIDC_CLIENT_SECRET"
          remoteRef = {
            key      = "oidc/headlamp"
            property = "clientSecret"
          }
        },
      ]
    }
  })

  depends_on = [
    kubectl_manifest.headlamp_vault_secret_store,
  ]
}
