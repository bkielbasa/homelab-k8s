output "vault_oidc_client_id" {
  description = "Client ID for the Vault OIDC provider"
  value       = authentik_provider_oauth2.vault.client_id
}

output "vault_oidc_client_secret" {
  description = "Client secret for the Vault OIDC provider"
  value       = authentik_provider_oauth2.vault.client_secret
  sensitive   = true
}

output "vault_admins_group_name" {
  description = "Name of the Authentik vault-admins group"
  value       = authentik_group.vault_admins.name
}

output "argocd_oidc_client_secret" {
  description = "Client secret for the ArgoCD OIDC provider"
  value       = authentik_provider_oauth2.argocd.client_secret
  sensitive   = true
}

output "argocd_application_uuid" {
  description = "UUID of the ArgoCD Authentik application"
  value       = authentik_application.argocd.uuid
}

output "argocd_admins_policy_binding_id" {
  description = "ID of the ArgoCD admins policy binding"
  value       = authentik_policy_binding.argocd_admins_required.id
}

output "grafana_oidc_client_secret" {
  description = "Client secret for the Grafana OIDC provider"
  value       = authentik_provider_oauth2.grafana.client_secret
  sensitive   = true
}

output "kubernetes_oidc_client_secret" {
  description = "Client secret for the Kubernetes (Headlamp) OIDC provider"
  value       = authentik_provider_oauth2.kubernetes.client_secret
  sensitive   = true
}

# Per-service OIDC client secrets for services managed in the services module
output "jellyfin_oidc_client_secret" {
  description = "Client secret for the Jellyfin OIDC provider"
  value       = authentik_provider_oauth2.jellyfin.client_secret
  sensitive   = true
}

output "actualbudget_oidc_client_secret" {
  description = "Client secret for the ActualBudget OIDC provider"
  value       = authentik_provider_oauth2.actualbudget.client_secret
  sensitive   = true
}

output "freshrss_oidc_client_secret" {
  description = "Client secret for the FreshRSS OIDC provider (written to Vault by services module)"
  value       = authentik_provider_oauth2.freshrss.client_secret
  sensitive   = true
}
