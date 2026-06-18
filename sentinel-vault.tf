resource "kubernetes_service_account" "sentinel" {
  metadata {
    name      = "sentinel"
    namespace = kubernetes_namespace.sentinel.metadata[0].name
  }
}

resource "vault_policy" "sentinel" {
  name = "sentinel"

  policy = <<EOT
path "secret/data/sentinelsre/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/sentinelsre/*" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "sentinel" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "sentinel"
  bound_service_account_names      = ["sentinel"]
  bound_service_account_namespaces = ["sentinel"]
  token_ttl                        = 3600
  token_policies                   = ["default", vault_policy.sentinel.name]
}

resource "kubectl_manifest" "sentinel_vault_secret_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "vault-backend"
      namespace = kubernetes_namespace.sentinel.metadata[0].name
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
              role      = "sentinel"
              serviceAccountRef = {
                name = "sentinel"
              }
            }
          }
        }
      }
    }
  })

  depends_on = [
    helm_release.external-secrets,
    kubernetes_service_account.sentinel,
    vault_kubernetes_auth_backend_role.sentinel,
  ]
}

locals {
  sentinel_external_secrets = {
    "sentinel-db"        = "sentinelsre/db"
    "sentinel-anthropic" = "sentinelsre/anthropic"
  }
}

# Pull secret for the private ghcr.io image. The PAT lives in Vault at
# secret/sentinelsre/ghcr with keys `username` (GitHub user) and `password`
# (a PAT with read:packages); ESO templates it into a dockerconfigjson.
locals {
  sentinel_ghcr_dockerconfig = <<-EOT
{"auths":{"ghcr.io":{"username":"{{ .username }}","password":"{{ .password }}","auth":"{{ printf "%s:%s" .username .password | b64enc }}"}}}
EOT
}

resource "kubectl_manifest" "sentinel_ghcr_external_secret" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "sentinel-ghcr"
      namespace = kubernetes_namespace.sentinel.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "sentinel-ghcr"
        creationPolicy = "Owner"
        template = {
          type = "kubernetes.io/dockerconfigjson"
          data = {
            ".dockerconfigjson" = local.sentinel_ghcr_dockerconfig
          }
        }
      }
      data = [
        {
          secretKey = "username"
          remoteRef = {
            key      = "sentinelsre/ghcr"
            property = "username"
          }
        },
        {
          secretKey = "password"
          remoteRef = {
            key      = "sentinelsre/ghcr"
            property = "password"
          }
        },
      ]
    }
  })

  depends_on = [
    kubectl_manifest.sentinel_vault_secret_store,
  ]
}

resource "kubectl_manifest" "sentinel_external_secret" {
  for_each = local.sentinel_external_secrets

  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = each.key
      namespace = kubernetes_namespace.sentinel.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = each.key
        creationPolicy = "Owner"
      }
      dataFrom = [
        {
          extract = {
            key = each.value
          }
        },
      ]
    }
  })

  depends_on = [
    kubectl_manifest.sentinel_vault_secret_store,
  ]
}
