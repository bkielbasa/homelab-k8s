# The darek workload (Helm chart) is managed by Argo CD — see
# argocd-apps/darek.yaml. This namespace + the Vault/ESO glue stay in Terraform.
resource "kubernetes_namespace" "darek" {
  metadata {
    name = "darek"
    annotations = {
      "linkerd.io/inject" = "enabled"
    }
  }
}

resource "kubernetes_service_account" "darek" {
  metadata {
    name      = "darek-sa"
    namespace = kubernetes_namespace.darek.metadata[0].name
  }
}

resource "vault_policy" "darek" {
  name = "darek"

  policy = <<EOT
# Allow reading secrets for darek
path "secret/data/darek" {
  capabilities = ["read", "list"]
}

# Allow reading metadata
path "secret/metadata/darek" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "darek" {
  backend                          = "kubernetes"
  role_name                        = "darek"
  bound_service_account_names      = ["darek-sa"]
  bound_service_account_namespaces = ["darek"]
  token_ttl                        = 3600
  token_policies                   = ["default", vault_policy.darek.name]
}

resource "kubectl_manifest" "darek_vault_secret_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "vault-backend"
      namespace = kubernetes_namespace.darek.metadata[0].name
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
              role      = "darek"
              serviceAccountRef = {
                name = "darek-sa"
              }
            }
          }
        }
      }
    }
  })

  depends_on = [
    kubernetes_service_account.darek,
    vault_kubernetes_auth_backend_role.darek,
  ]
}

# Pulls every field of `secret/data/darek` into a K8s Secret named `darek-env`.
resource "kubectl_manifest" "darek_env_external_secret" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "darek-env"
      namespace = kubernetes_namespace.darek.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "darek-env"
        creationPolicy = "Owner"
      }
      dataFrom = [
        {
          extract = {
            key = "darek"
          }
        }
      ]
    }
  })

  depends_on = [
    kubectl_manifest.darek_vault_secret_store
  ]
}
