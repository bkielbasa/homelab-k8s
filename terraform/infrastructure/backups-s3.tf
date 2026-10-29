# S3 credentials for database backups (CNPG + mariadb-operator)
# Put AWS credentials in Vault at:
#   secret/data/backups/s3  (keys: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, BUCKET_NAME, ENDPOINT_URL or just use AWS S3)
# 
# These are synced via ExternalSecret to namespaces used by backup jobs.

resource "kubernetes_namespace" "cnpg_backup" {
  metadata {
    name = "cnpg-backup"
    annotations = {
      "linkerd.io/inject" = "enabled"
    }
  }
}

resource "kubernetes_namespace" "mariadb_backup" {
  metadata {
    name = "mariadb-backup"
    annotations = {
      "linkerd.io/inject" = "enabled"
    }
  }
}

resource "kubernetes_service_account" "cnpg_backup" {
  metadata {
    name      = "backup-sa"
    namespace = kubernetes_namespace.cnpg_backup.metadata[0].name
  }
}

resource "kubernetes_service_account" "mariadb_backup" {
  metadata {
    name      = "backup-sa"
    namespace = kubernetes_namespace.mariadb_backup.metadata[0].name
  }
}

resource "vault_policy" "backups_s3" {
  name = "backups-s3"

  policy = <<EOT
path "secret/data/backups/s3" {
  capabilities = ["read", "list"]
}
path "secret/metadata/backups/s3" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "cnpg_backup" {
  backend                          = "kubernetes"
  role_name                        = "cnpg-backup"
  bound_service_account_names      = ["backup-sa"]
  bound_service_account_namespaces = [kubernetes_namespace.cnpg_backup.metadata[0].name]
  token_ttl                        = 3600
  token_policies                   = ["default", vault_policy.backups_s3.name]
}

resource "vault_kubernetes_auth_backend_role" "mariadb_backup" {
  backend                          = "kubernetes"
  role_name                        = "mariadb-backup"
  bound_service_account_names      = ["backup-sa"]
  bound_service_account_namespaces = [kubernetes_namespace.mariadb_backup.metadata[0].name]
  token_ttl                        = 3600
  token_policies                   = ["default", vault_policy.backups_s3.name]
}

resource "kubernetes_manifest" "cnpg_backup_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "vault-backend"
      namespace = kubernetes_namespace.cnpg_backup.metadata[0].name
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
              role      = "cnpg-backup"
              serviceAccountRef = {
                name = "backup-sa"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_account.cnpg_backup,
    vault_kubernetes_auth_backend_role.cnpg_backup,
  ]
}

resource "kubernetes_manifest" "mariadb_backup_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "vault-backend"
      namespace = kubernetes_namespace.mariadb_backup.metadata[0].name
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
              role      = "mariadb-backup"
              serviceAccountRef = {
                name = "backup-sa"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_account.mariadb_backup,
    vault_kubernetes_auth_backend_role.mariadb_backup,
  ]
}

# Sync S3 credentials to cnpg-backup namespace as 'aws-creds'
resource "kubernetes_manifest" "cnpg_s3_external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "aws-creds"
      namespace = kubernetes_namespace.cnpg_backup.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "aws-creds"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "ACCESS_KEY_ID"
          remoteRef = {
            key      = "backups/s3"
            property = "AWS_ACCESS_KEY_ID"
          }
        },
        {
          secretKey = "SECRET_ACCESS_KEY"
          remoteRef = {
            key      = "backups/s3"
            property = "AWS_SECRET_ACCESS_KEY"
          }
        }
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.cnpg_backup_secret_store,
  ]
}

# Sync S3 credentials to mariadb-backup namespace as 'aws-creds'
resource "kubernetes_manifest" "mariadb_s3_external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "aws-creds"
      namespace = kubernetes_namespace.mariadb_backup.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "aws-creds"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "ACCESS_KEY_ID"
          remoteRef = {
            key      = "backups/s3"
            property = "AWS_ACCESS_KEY_ID"
          }
        },
        {
          secretKey = "SECRET_ACCESS_KEY"
          remoteRef = {
            key      = "backups/s3"
            property = "AWS_SECRET_ACCESS_KEY"
          }
        }
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.mariadb_backup_secret_store,
  ]
}

removed {
  from = kubectl_manifest.cnpg_backup_secret_store
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubectl_manifest.mariadb_backup_secret_store
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubectl_manifest.cnpg_s3_external_secret
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubectl_manifest.mariadb_s3_external_secret
  lifecycle {
    destroy = false
  }
}

import {
  to = kubernetes_manifest.cnpg_backup_secret_store
  id = "cnpg-backup/vault-backend"
}

import {
  to = kubernetes_manifest.mariadb_backup_secret_store
  id = "mariadb-backup/vault-backend"
}

import {
  to = kubernetes_manifest.cnpg_s3_external_secret
  id = "cnpg-backup/aws-creds"
}

import {
  to = kubernetes_manifest.mariadb_s3_external_secret
  id = "mariadb-backup/aws-creds"
}
