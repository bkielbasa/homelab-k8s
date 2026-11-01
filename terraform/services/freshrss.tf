# The freshrss workload (Helm chart) is managed by Argo CD — see
# argocd-apps/freshrss.yaml. This namespace + the Vault/ESO glue stay in Terraform.

# Read the FreshRSS OIDC client secret from Vault (written by terraform/auth).
# Then re-publish it at the path the ESO ExternalSecret expects (freshrss/oidc).
data "vault_kv_secret_v2" "oidc_freshrss" {
  mount = "secret"
  name  = "oidc/freshrss"
}

resource "vault_kv_secret_v2" "freshrss_oidc" {
  mount = "secret"
  name  = "freshrss/oidc"
  data_json = jsonencode({
    clientSecret = data.vault_kv_secret_v2.oidc_freshrss.data["clientSecret"]
  })
}

resource "vault_policy" "freshrss" {
  name = "freshrss"

  policy = <<EOT
path "secret/data/freshrss/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/freshrss/*" {
  capabilities = ["read", "list"]
}
EOT
}

# Bound to the chart-managed `freshrss-sa` ServiceAccount (the chart owns the SA;
# referenced here by name only so ownership stays with the workload / Argo CD).
resource "vault_kubernetes_auth_backend_role" "freshrss" {
  backend                          = "kubernetes"
  role_name                        = "freshrss"
  bound_service_account_names      = ["freshrss-sa"]
  bound_service_account_namespaces = ["freshrss"]
  token_ttl                        = 3600
  token_policies                   = ["default", vault_policy.freshrss.name]
}

resource "kubernetes_manifest" "freshrss_vault_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "vault-backend"
      namespace = "freshrss"
    }
    spec = {
      provider = {
        vault = {
          server  = "http://vault.vault.svc.cluster.local:8200"
          path    = "secret"
          version = "v2"
          auth = {
            kubernetes = {
              mountPath = "kubernetes"
              role      = "freshrss"
              serviceAccountRef = {
                name = "freshrss-sa"
              }
            }
          }
        }
      }
    }
  }

  field_manager {
    force_conflicts = true
  }

  depends_on = [
    vault_kubernetes_auth_backend_role.freshrss,
  ]
}

resource "kubernetes_manifest" "freshrss_oidc_external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "freshrss-oidc"
      namespace = "freshrss"
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "freshrss-oidc"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "clientSecret"
          remoteRef = {
            key      = "freshrss/oidc"
            property = "clientSecret"
          }
        },
      ]
    }
  }

  field_manager {
    force_conflicts = true
  }

  depends_on = [
    kubernetes_manifest.freshrss_vault_secret_store,
    vault_kv_secret_v2.freshrss_oidc,
  ]
}
