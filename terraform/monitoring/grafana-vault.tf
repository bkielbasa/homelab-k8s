# Vault/ESO glue for Grafana's secrets in the monitoring namespace.
#
# Argo CD (argocd-apps/prometheus.yaml) manages kube-prometheus-stack; this
# root only syncs the Secret that values/prometheus.yaml pulls in via
# grafana.envFromSecrets:
#   - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET: Authentik OIDC login for Grafana
#     (previously helm_release.set_sensitive; Vault path written by
#     terraform/auth/oidc-secrets.tf).
#   - SMARTHOME_DB_PASSWORD: password for the smarthome-metrics datasource
#     provisioning ($SMARTHOME_DB_PASSWORD in values/prometheus.yaml).
#     Grafana's SQLite DB is an emptyDir, so the datasource has to stay
#     declarative. Same Vault secret the smarthome-metrics workload reads
#     (see terraform/services/smarthome-metrics.tf); Grafana needs its own
#     copy because a secretKeyRef cannot cross namespaces.

resource "kubernetes_service_account" "monitoring" {
  metadata {
    name      = "monitoring-sa"
    namespace = "monitoring"
  }
}

resource "vault_policy" "monitoring" {
  name = "monitoring"

  policy = <<EOT
path "secret/data/oidc/grafana" {
  capabilities = ["read", "list"]
}
path "secret/metadata/oidc/grafana" {
  capabilities = ["read", "list"]
}
path "secret/data/smarthome-metrics" {
  capabilities = ["read", "list"]
}
path "secret/metadata/smarthome-metrics" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "monitoring" {
  backend                          = "kubernetes"
  role_name                        = "monitoring"
  bound_service_account_names      = ["monitoring-sa"]
  bound_service_account_namespaces = ["monitoring"]
  token_ttl                        = 3600
  token_policies                   = ["default", vault_policy.monitoring.name]
}

resource "kubernetes_manifest" "monitoring_vault_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "vault-backend"
      namespace = "monitoring"
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
              role      = "monitoring"
              serviceAccountRef = {
                name = "monitoring-sa"
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
    kubernetes_service_account.monitoring,
    vault_kubernetes_auth_backend_role.monitoring,
  ]
}

resource "kubernetes_manifest" "grafana_env_external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "grafana-env"
      namespace = "monitoring"
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "grafana-env"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET"
          remoteRef = {
            key      = "oidc/grafana"
            property = "clientSecret"
          }
        },
        {
          secretKey = "SMARTHOME_DB_PASSWORD"
          remoteRef = {
            key      = "smarthome-metrics"
            property = "password"
          }
        },
      ]
    }
  }

  field_manager {
    force_conflicts = true
  }

  depends_on = [
    kubernetes_manifest.monitoring_vault_secret_store,
  ]
}

removed {
  from = kubectl_manifest.monitoring_vault_secret_store
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubectl_manifest.grafana_env_external_secret
  lifecycle {
    destroy = false
  }
}

import {
  to = kubernetes_manifest.monitoring_vault_secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=monitoring,name=vault-backend"
}

import {
  to = kubernetes_manifest.grafana_env_external_secret
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=monitoring,name=grafana-env"
}
