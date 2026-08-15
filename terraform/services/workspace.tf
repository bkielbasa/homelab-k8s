resource "kubernetes_namespace" "workspace" {
  metadata {
    name = "workspace"
  }
}

# Public DNS — mail.klimczak.xyz
resource "ovh_domain_zone_record" "workspace" {
  zone      = "klimczak.xyz"
  subdomain = "mail"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

# Public DNS — klimczak.xyz (apex)
resource "ovh_domain_zone_record" "workspace_apex" {
  zone      = "klimczak.xyz"
  subdomain = ""
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

# LAN DNS — Pi-hole
resource "pihole_dns_record" "workspace" {
  domain = "mail.klimczak.xyz"
  ip     = "192.168.1.30"
}

# LAN DNS — Pi-hole apex
resource "pihole_dns_record" "workspace_apex" {
  domain = "klimczak.xyz"
  ip     = "192.168.1.30"
}

# Database credentials stored in Vault and synced into a k8s Secret
# that the workspace Helm chart reads via databaseUrlSecret.
#
# Prerequisites (run once, manually):
#   vault kv put secret/workspace/db \
#     DATABASE_URL="postgres://workspace:PASS@postgresql.postgresql.svc.cluster.local:5432/workspace?sslmode=disable"
#
resource "vault_policy" "workspace" {
  name = "workspace"

  policy = <<EOT
path "secret/data/workspace/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/workspace/*" {
  capabilities = ["read", "list"]
}
EOT
}

resource "kubernetes_service_account" "workspace" {
  metadata {
    name      = "workspace"
    namespace = kubernetes_namespace.workspace.metadata[0].name
  }
}

resource "vault_kubernetes_auth_backend_role" "workspace" {
  backend                          = "kubernetes"
  role_name                        = "workspace"
  bound_service_account_names      = ["workspace"]
  bound_service_account_namespaces = ["workspace"]
  token_ttl                        = 3600
  token_policies                   = ["default", vault_policy.workspace.name]
}

resource "kubectl_manifest" "workspace_vault_secret_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "vault-backend"
      namespace = kubernetes_namespace.workspace.metadata[0].name
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
              role      = "workspace"
              serviceAccountRef = {
                name = "workspace"
              }
            }
          }
        }
      }
    }
  })

  depends_on = [
    kubernetes_service_account.workspace,
    vault_kubernetes_auth_backend_role.workspace,
  ]
}

resource "kubectl_manifest" "workspace_db_external_secret" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "workspace-db"
      namespace = kubernetes_namespace.workspace.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "workspace-db"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "DATABASE_URL"
          remoteRef = {
            key      = "workspace/db"
            property = "DATABASE_URL"
          }
        },
      ]
    }
  })

  depends_on = [
    kubectl_manifest.workspace_vault_secret_store,
  ]
}
