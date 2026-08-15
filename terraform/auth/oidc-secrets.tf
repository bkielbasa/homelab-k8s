# Write all OIDC client secrets into Vault KV at a well-known path.
# Other standalone roots read them back via data "vault_kv_secret_v2".
# This decouples all modules from auth's Terraform outputs.
#
# Convention: secret/oidc/<service>  →  { clientSecret = "..." }

resource "vault_kv_secret_v2" "oidc_vault" {
  mount = "secret"
  name  = "oidc/vault"
  data_json = jsonencode({
    clientSecret = authentik_provider_oauth2.vault.client_secret
    clientId     = authentik_provider_oauth2.vault.client_id
    groupName    = authentik_group.vault_admins.name
  })
}

resource "vault_kv_secret_v2" "oidc_argocd" {
  mount = "secret"
  name  = "oidc/argocd"
  data_json = jsonencode({
    clientSecret = authentik_provider_oauth2.argocd.client_secret
  })
}

resource "vault_kv_secret_v2" "oidc_grafana" {
  mount = "secret"
  name  = "oidc/grafana"
  data_json = jsonencode({
    clientSecret = authentik_provider_oauth2.grafana.client_secret
  })
}

resource "vault_kv_secret_v2" "oidc_actualbudget" {
  mount = "secret"
  name  = "oidc/actualbudget"
  data_json = jsonencode({
    clientSecret = authentik_provider_oauth2.actualbudget.client_secret
  })
}

resource "vault_kv_secret_v2" "oidc_headlamp" {
  mount = "secret"
  name  = "oidc/headlamp"
  data_json = jsonencode({
    clientSecret = authentik_provider_oauth2.kubernetes.client_secret
  })
}

resource "vault_kv_secret_v2" "oidc_freshrss" {
  mount = "secret"
  name  = "oidc/freshrss"
  data_json = jsonencode({
    clientSecret = authentik_provider_oauth2.freshrss.client_secret
  })
}
