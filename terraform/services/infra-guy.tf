# The infra-guy workload is managed by Argo CD — see argocd-apps/infra-guy.yaml.
# This namespace and the Vault/External Secrets glue stay in Terraform.
resource "kubernetes_namespace" "infra_guy" {
  metadata {
    name = "infra-guy"
  }
}

resource "kubernetes_service_account" "infra_guy" {
  metadata {
    name      = "infra-guy-sa"
    namespace = kubernetes_namespace.infra_guy.metadata[0].name
  }
}

# infra-guy runs Terraform in-cluster; grant it cluster-admin so the
# external runner can manage cluster resources.
resource "kubernetes_cluster_role_binding" "infra_guy_cluster_admin" {
  metadata {
    name = "infra-guy-cluster-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "infra-guy-sa"
    namespace = kubernetes_namespace.infra_guy.metadata[0].name
  }
}

resource "vault_policy" "infra_guy" {
  name = "infra-guy"

  policy = <<EOT
path "secret/data/infra-guy" {
  capabilities = ["read", "list"]
}

path "secret/metadata/infra-guy" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "infra_guy" {
  backend                          = "kubernetes"
  role_name                        = "infra-guy"
  bound_service_account_names      = ["infra-guy-sa"]
  bound_service_account_namespaces = ["infra-guy"]
  token_ttl                        = 3600
  token_policies                   = ["default", vault_policy.infra_guy.name]
}

resource "kubectl_manifest" "infra_guy_vault_secret_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "vault-backend"
      namespace = kubernetes_namespace.infra_guy.metadata[0].name
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
              role      = "infra-guy"
              serviceAccountRef = {
                name = "infra-guy-sa"
              }
            }
          }
        }
      }
    }
  })

  depends_on = [
    kubernetes_service_account.infra_guy,
    vault_kubernetes_auth_backend_role.infra_guy,
  ]
}

# Fields: POSTGRES_PASSWORD, GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY, GITHUB_APP_WEBHOOK_SECRET, GITHUB_APP_CLIENT_ID, GITHUB_APP_CLIENT_SECRET.
resource "kubectl_manifest" "infra_guy_env_external_secret" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "infra-guy-env"
      namespace = kubernetes_namespace.infra_guy.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "vault-backend"
        kind = "SecretStore"
      }
      target = {
        name           = "infra-guy-env"
        creationPolicy = "Owner"
      }
      dataFrom = [
        {
          extract = {
            key = "infra-guy"
          }
        }
      ]
    }
  })

  depends_on = [
    kubectl_manifest.infra_guy_vault_secret_store
  ]
}
