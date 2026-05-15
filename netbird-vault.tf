resource "kubernetes_service_account" "netbird" {
  metadata {
    name      = "netbird"
    namespace = kubernetes_namespace.netbird.metadata[0].name
  }
}

resource "vault_policy" "netbird" {
  name = "netbird"

  policy = <<EOT
path "secret/data/netbird/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/netbird/*" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "netbird" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "netbird"
  bound_service_account_names      = ["netbird"]
  bound_service_account_namespaces = ["netbird"]
  token_ttl                        = 3600
  token_policies                   = ["default", vault_policy.netbird.name]
}

resource "kubectl_manifest" "netbird_vault_secret_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "vault-backend"
      namespace = kubernetes_namespace.netbird.metadata[0].name
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
              role      = "netbird"
              serviceAccountRef = {
                name = "netbird"
              }
            }
          }
        }
      }
    }
  })

  depends_on = [
    helm_release.external-secrets,
    kubernetes_service_account.netbird,
    vault_kubernetes_auth_backend_role.netbird,
  ]
}
