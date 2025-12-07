resource "kubernetes_service_account" "nextcloud" {
  metadata {
    name      = "nextcloud-sa"
    namespace = kubernetes_namespace.nextcloud.metadata[0].name
  }
}

resource "vault_policy" "nextcloud" {
  name = "nextcloud"

  policy = <<EOT
# Allow reading secrets for Nextcloud
path "secret/data/nextcloud/*" {
  capabilities = ["read", "list"]
}

# Allow reading metadata
path "secret/metadata/nextcloud/*" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "nextcloud" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "nextcloud"
  bound_service_account_names      = ["nextcloud-sa"]
  bound_service_account_namespaces = ["nextcloud"]
  token_ttl                        = 3600
  token_policies                   = ["default", vault_policy.nextcloud.name]
}

resource "kubectl_manifest" "nextcloud_postgres_external_secret" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "nextcloud-postgres-secret"
      namespace = kubernetes_namespace.nextcloud.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "nextcloud-postgres"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "db-name"
          remoteRef = {
            key      = "nextcloud/postgres"
            property = "database"
          }
        },
        {
          secretKey = "db-host"
          remoteRef = {
            key      = "nextcloud/postgres"
            property = "host"
          }
        },
        {
          secretKey = "db-password"
          remoteRef = {
            key      = "nextcloud/postgres"
            property = "password"
          }
        },
        {
          secretKey = "db-username"
          remoteRef = {
            key      = "nextcloud/postgres"
            property = "username"
          }
        }
      ]
    }
  })

  depends_on = [
    kubectl_manifest.vault_secret_store
  ]
}

resource "kubectl_manifest" "vault_secret_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "vault-backend"
      namespace = kubernetes_namespace.nextcloud.metadata[0].name
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
              role      = "nextcloud"
              serviceAccountRef = {
                name = "nextcloud-sa"
              }
            }
          }
        }
      }
    }
  })

  depends_on = [
    helm_release.external-secrets
  ]
}

resource "kubectl_manifest" "nextcloud_admin_external_secret" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "nextcloud-admin-secret"
      namespace = kubernetes_namespace.nextcloud.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "nextcloud-admin"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "nextcloud-username"
          remoteRef = {
            key      = "nextcloud/admin"
            property = "username"
          }
        },
        {
          secretKey = "nextcloud-password"
          remoteRef = {
            key      = "nextcloud/admin"
            property = "password"
          }
        }
      ]
    }
  })

  depends_on = [
    kubectl_manifest.vault_secret_store
  ]
}

resource "kubectl_manifest" "nextcloud_session_external_secret" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "nextcloud-session-secret"
      namespace = kubernetes_namespace.nextcloud.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "nextcloud-session"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "token"
          remoteRef = {
            key      = "nextcloud/session"
            property = "token"
          }
        }
      ]
    }
  })

  depends_on = [
    kubectl_manifest.vault_secret_store
  ]
}
