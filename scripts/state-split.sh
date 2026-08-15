#!/usr/bin/env bash
# Split the single combined Terraform state into 5 separate backend states.
#
# Run from the repo root. Requires AWS credentials (homelab profile) and
# all providers to be accessible.
#
# The current state lives at: homelab-k8s/terraform.tfstate
# After this script:
#   homelab-k8s/terraform.tfstate    → root only (apex DNS, netbird)
#   homelab-k8s/vault/terraform.tfstate
#   homelab-k8s/auth/terraform.tfstate
#   homelab-k8s/infrastructure/terraform.tfstate
#   homelab-k8s/monitoring/terraform.tfstate
#   homelab-k8s/services/terraform.tfstate

set -euo pipefail
cd "$(dirname "$0")/.."

ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Pulling current state from S3..."
terraform state pull > "$TMP/current.tfstate"

# Helper: move a resource from source tfstate to a target directory's backend.
# We use `terraform state mv` with explicit -state/-state-out flags, then
# push the resulting state to the remote backend.
move_to() {
  local src="$TMP/current.tfstate"
  local target_dir="$1"
  shift
  local resources=("$@")

  local out="$TMP/$(basename $target_dir).tfstate"
  # Seed the output state if it doesn't exist yet
  if [ ! -f "$out" ]; then
    cp "$src" "$TMP/empty.tfstate"
    terraform -chdir="$target_dir" state pull > "$out" 2>/dev/null || echo '{"version":4,"terraform_version":"1.0.0","serial":0,"lineage":"","outputs":{},"resources":[]}' > "$out"
  fi

  for res in "${resources[@]}"; do
    echo "  mv $res → $target_dir"
    terraform state mv \
      -state="$src" \
      -state-out="$out" \
      "$res" "$res" 2>&1 | grep -v "^$" || true
  done
}

echo ""
echo "=== Splitting state ==="

# --- vault ---
echo "--- vault ---"
cd "$ROOT/terraform/vault" && terraform state pull > "$TMP/vault.tfstate" 2>/dev/null || true; cd "$ROOT"

VAULT_RESOURCES=(
  "module.vault.helm_release.vault"
  "module.vault.helm_release.external_secrets"
  "module.vault.kubernetes_namespace.vault"
  "module.vault.kubernetes_namespace.external_secrets"
  "module.vault.kubernetes_secret.vault_unseal_aws"
  "module.vault.aws_kms_key.vault_unseal"
  "module.vault.aws_kms_alias.vault_unseal"
  "module.vault.aws_iam_user.vault_unseal"
  "module.vault.aws_iam_user_policy.vault_unseal"
  "module.vault.aws_iam_access_key.vault_unseal"
  "module.vault.vault_policy.vault_admin"
  "module.vault.vault_jwt_auth_backend.oidc"
  "module.vault.vault_jwt_auth_backend_role.default"
  "module.vault.ovh_domain_zone_record.vault"
  "module.vault.pihole_dns_record.vault"
  "vault_auth_backend.kubernetes"
  "vault_kubernetes_auth_backend_config.kubernetes"
)

# --- auth ---
echo "--- auth ---"
AUTH_RESOURCES=(
  "module.auth.authentik_property_mapping_provider_scope.groups"
  "module.auth.authentik_group.vault_admins"
  "module.auth.authentik_provider_oauth2.vault"
  "module.auth.authentik_application.vault"
  "module.auth.authentik_group.argocd_admins"
  "module.auth.authentik_provider_oauth2.argocd"
  "module.auth.authentik_application.argocd"
  "module.auth.authentik_policy_binding.argocd_admins_required"
  "module.auth.authentik_group.grafana_admins"
  "module.auth.authentik_provider_oauth2.grafana"
  "module.auth.authentik_application.grafana"
  "module.auth.authentik_group.kubernetes_admins"
  "module.auth.authentik_provider_oauth2.kubernetes"
  "module.auth.authentik_application.kubernetes"
  "module.auth.authentik_policy_binding.kubernetes_admins_required"
  "module.auth.kubernetes_cluster_role_binding.oidc_kubernetes_admins"
  "module.auth.kubernetes_namespace.authentik"
  "module.auth.helm_release.authentik"
  "module.auth.kubernetes_service_account.authentik"
  "module.auth.vault_policy.authentik"
  "module.auth.vault_kubernetes_auth_backend_role.authentik"
  "module.auth.kubectl_manifest.authentik_vault_secret_store"
  "module.auth.kubectl_manifest.authentik_app_external_secret"
  "module.auth.kubectl_manifest.authentik_postgres_external_secret"
  "module.auth.ovh_domain_zone_record.authentik"
  "module.auth.pihole_dns_record.authentik"
  "module.auth.authentik_group.jellyfin_users"
  "module.auth.authentik_group.jellyfin_admins"
  "module.auth.authentik_provider_oauth2.jellyfin"
  "module.auth.authentik_application.jellyfin"
  "module.auth.authentik_group.actualbudget_users"
  "module.auth.authentik_provider_oauth2.actualbudget"
  "module.auth.authentik_application.actualbudget"
  "module.auth.authentik_group.darek_users"
  "module.auth.authentik_provider_oauth2.darek"
  "module.auth.authentik_application.darek"
  "module.auth.authentik_group.freshrss_users"
  "module.auth.authentik_provider_oauth2.freshrss"
  "module.auth.authentik_application.freshrss"
  "module.auth.authentik_group.navidrome_users"
  "module.auth.authentik_provider_oauth2.navidrome"
  "module.auth.authentik_application.navidrome"
  "module.auth.authentik_policy_binding.navidrome_users_required"
)

# --- infrastructure ---
echo "--- infrastructure ---"
INFRA_RESOURCES=(
  "module.infrastructure.kubernetes_namespace.metallb"
  "module.infrastructure.helm_release.metallb"
  "module.infrastructure.kubernetes_manifest.metallb_ip_pool"
  "module.infrastructure.kubernetes_manifest.metallb_l2_adv"
  "module.infrastructure.kubernetes_namespace.ingress_nginx"
  "module.infrastructure.helm_release.nginx_ingress"
  "module.infrastructure.kubernetes_secret.ovh_credentials"
  "module.infrastructure.helm_release.cert_manager_webhook_ovh"
  "module.infrastructure.tls_private_key.trustanchor_key"
  "module.infrastructure.tls_self_signed_cert.trustanchor_cert"
  "module.infrastructure.tls_private_key.issuer_key"
  "module.infrastructure.tls_cert_request.issuer_req"
  "module.infrastructure.tls_locally_signed_cert.issuer_cert"
  "module.infrastructure.kubernetes_namespace.linkerd"
  "module.infrastructure.helm_release.linkerd_crds"
  "module.infrastructure.helm_release.linkerd_control_plane"
  "module.infrastructure.kubernetes_namespace.linkerd_viz"
  "module.infrastructure.helm_release.linkerd_viz"
  "module.infrastructure.kubernetes_manifest.linkerd_proxy_podmonitor"
  "module.infrastructure.kubernetes_manifest.linkerd_control_plane_podmonitor"
  "module.infrastructure.kubernetes_storage_class_v1.qnap_nfs"
  "module.infrastructure.kubernetes_namespace.argocd"
  "module.infrastructure.helm_release.argocd"
  "module.infrastructure.ovh_domain_zone_record.argocd"
  "module.infrastructure.pihole_dns_record.argocd"
)

# --- monitoring ---
echo "--- monitoring ---"
MONITORING_RESOURCES=(
  "module.monitoring.helm_release.prometheus"
  "module.monitoring.helm_release.loki"
  "module.monitoring.helm_release.alloy"
  "module.monitoring.helm_release.tempo"
  "module.monitoring.kubernetes_manifest.linkerd_proxy_servicemonitor"
  "module.monitoring.pihole_dns_record.grafana"
)

# --- services ---
echo "--- services ---"
SERVICES_RESOURCES=(
  "module.services.kubernetes_namespace.jellyfin"
  "module.services.helm_release.jellyfin"
  "module.services.ovh_domain_zone_record.jellyfin"
  "module.services.pihole_dns_record.jellyfin"
  "module.services.kubernetes_namespace.actualbudget"
  "module.services.helm_release.actualbudget"
  "module.services.pihole_dns_record.budget-board"
  "module.services.kubernetes_namespace.vaultwarden"
  "module.services.helm_release.vaultwarden"
  "module.services.pihole_dns_record.pass"
  "module.services.kubernetes_namespace.headlamp"
  "module.services.helm_release.headlamp"
  "module.services.ovh_domain_zone_record.headlamp"
  "module.services.pihole_dns_record.headlamp"
  "module.services.kubernetes_namespace.darek"
  "module.services.kubernetes_service_account.darek"
  "module.services.vault_policy.darek"
  "module.services.vault_kubernetes_auth_backend_role.darek"
  "module.services.kubectl_manifest.darek_vault_secret_store"
  "module.services.kubectl_manifest.darek_env_external_secret"
  "module.services.ovh_domain_zone_record.darek"
  "module.services.pihole_dns_record.darek"
  "module.services.vault_kv_secret_v2.freshrss_oidc"
  "module.services.vault_policy.freshrss"
  "module.services.vault_kubernetes_auth_backend_role.freshrss"
  "module.services.kubectl_manifest.freshrss_vault_secret_store"
  "module.services.kubectl_manifest.freshrss_oidc_external_secret"
  "module.services.pihole_dns_record.freshrss"
  "module.services.kubernetes_namespace.sentinel"
  "module.services.kubernetes_service_account.sentinel"
  "module.services.vault_policy.sentinel"
  "module.services.vault_kubernetes_auth_backend_role.sentinel"
  "module.services.kubectl_manifest.sentinel_vault_secret_store"
  "module.services.kubectl_manifest.sentinel_ghcr_external_secret"
  'module.services.kubectl_manifest.sentinel_external_secret["sentinel-anthropic"]'
  'module.services.kubectl_manifest.sentinel_external_secret["sentinel-db"]'
  "module.services.ovh_domain_zone_record.sentinel"
  "module.services.pihole_dns_record.sentinel"
  "module.services.kubernetes_namespace.navidrome"
  "module.services.ovh_domain_zone_record.navidrome"
  "module.services.pihole_dns_record.navidrome"
  "module.services.kubernetes_namespace.mariadb"
  "module.services.helm_release.mariadb"
  "module.services.kubernetes_namespace.postgresql"
  "module.services.helm_release.postgresql"
  "module.services.kubernetes_namespace.valkey"
  "module.services.helm_release.valkey"
)

# -----------------------------------------------------------------------
# Phase 1: pull current combined state, mv resources into per-component
#          local .tfstate files using the new (non-module) addresses.
# -----------------------------------------------------------------------

pull_and_mv() {
  local component="$1"
  local target_dir="$2"
  shift 2
  local resources=("$@")

  local tmp_state="$TMP/${component}.tfstate"

  # Start with an empty state for this component
  echo '{"version":4,"terraform_version":"1.12.0","serial":1,"lineage":"","outputs":{},"resources":[]}' > "$tmp_state"

  for res in "${resources[@]}"; do
    # Strip the module.X. prefix to get the bare address for the new root
    local new_addr
    new_addr=$(echo "$res" | sed 's/^module\.[^.]*\.//')
    echo "  $res  →  $new_addr"
    terraform state mv \
      -state="$TMP/current.tfstate" \
      -state-out="$tmp_state" \
      "$res" "$new_addr" 2>&1 | grep -v "^Acquiring\|^Releasing\|^$" || true
  done

  echo "  Pushing $component state..."
  cd "$target_dir"
  terraform state push "$tmp_state"
  cd "$ROOT"
}

pull_and_mv vault    "$ROOT/terraform/vault"          "${VAULT_RESOURCES[@]}"
pull_and_mv auth     "$ROOT/terraform/auth"           "${AUTH_RESOURCES[@]}"
pull_and_mv infra    "$ROOT/terraform/infrastructure" "${INFRA_RESOURCES[@]}"
pull_and_mv monitor  "$ROOT/terraform/monitoring"     "${MONITORING_RESOURCES[@]}"
pull_and_mv services "$ROOT/terraform/services"       "${SERVICES_RESOURCES[@]}"

# -----------------------------------------------------------------------
# Phase 2: push the trimmed root state (only apex DNS + netbird remain)
# -----------------------------------------------------------------------
echo ""
echo "--- root (apex DNS only) ---"
terraform state push "$TMP/current.tfstate"

echo ""
echo "State split complete."
echo "Verify with: terraform -chdir=terraform/vault plan"
echo "             terraform -chdir=terraform/auth plan"
echo "             terraform -chdir=terraform/infrastructure plan"
echo "             terraform -chdir=terraform/monitoring plan"
echo "             terraform -chdir=terraform/services plan"
