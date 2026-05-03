resource "kubernetes_service_account" "authentik" {
  metadata {
    name      = "authentik"
    namespace = kubernetes_namespace.authentik.metadata[0].name
  }
}

resource "vault_policy" "authentik" {
  name = "authentik"

  policy = <<EOT
# Allow reading secrets for Authentik
path "secret/data/authentik/*" {
  capabilities = ["read", "list"]
}

# Allow reading metadata
path "secret/metadata/authentik/*" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "authentik" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "authentik"
  bound_service_account_names      = ["authentik"]
  bound_service_account_namespaces = ["authentik"]
  token_ttl                        = 3600
  token_policies                   = ["default", vault_policy.authentik.name]
}

resource "kubectl_manifest" "authentik_vault_secret_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "vault-backend"
      namespace = kubernetes_namespace.authentik.metadata[0].name
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
              role      = "authentik"
              serviceAccountRef = {
                name = "authentik"
              }
            }
          }
        }
      }
    }
  })

  depends_on = [
    helm_release.external-secrets,
    kubernetes_service_account.authentik,
    vault_kubernetes_auth_backend_role.authentik,
  ]
}

resource "kubectl_manifest" "authentik_app_external_secret" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "authentik-app"
      namespace = kubernetes_namespace.authentik.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "authentik-app"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "AUTHENTIK_SECRET_KEY"
          remoteRef = {
            key      = "authentik/app"
            property = "secret_key"
          }
        },
        {
          secretKey = "AUTHENTIK_BOOTSTRAP_PASSWORD"
          remoteRef = {
            key      = "authentik/app"
            property = "bootstrap_password"
          }
        },
        {
          secretKey = "AUTHENTIK_BOOTSTRAP_TOKEN"
          remoteRef = {
            key      = "authentik/app"
            property = "bootstrap_token"
          }
        },
      ]
    }
  })

  depends_on = [
    kubectl_manifest.authentik_vault_secret_store,
  ]
}

resource "kubectl_manifest" "authentik_postgres_external_secret" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "authentik-postgres"
      namespace = kubernetes_namespace.authentik.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "authentik-postgres"
        creationPolicy = "Owner"
      }
      dataFrom = [
        {
          extract = {
            key = "authentik/postgres"
          }
        },
      ]
    }
  })

  depends_on = [
    kubectl_manifest.authentik_vault_secret_store,
  ]
}
