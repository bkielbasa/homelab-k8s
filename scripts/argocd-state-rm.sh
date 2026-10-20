#!/usr/bin/env bash
# Drop the helm_release objects that moved to Argo CD from Terraform state.
#
# Run this BEFORE `terraform apply` on the affected roots (see
# docs/argocd-migration.md). Without it, the apply would execute
# `helm uninstall` for each removed helm_release block, deleting the running
# workloads — including chart-managed PVCs.
#
# Idempotent: already-removed resources are skipped. Remote (S3) state, so
# this needs the same credentials as a normal apply.
set -euo pipefail
cd "$(dirname "$0")/.."

rm_state() {
  local dir=$1 res=$2
  # Capture state list first: `state list | grep -q` + `pipefail` misreports
  # "absent" when grep exits early and terraform dies of SIGPIPE.
  local list
  list=$(terraform -chdir="$dir" state list 2>/dev/null || true)
  if printf '%s\n' "$list" | grep -Fxq "$res"; then
    terraform -chdir="$dir" state rm "$res"
    echo "removed: $dir -> $res"
  else
    echo "absent:  $dir -> $res"
  fi
}

# terraform/services
rm_state terraform/services helm_release.mariadb
rm_state terraform/services helm_release.postgresql
rm_state terraform/services helm_release.valkey
rm_state terraform/services helm_release.jellyfin
rm_state terraform/services helm_release.vaultwarden
rm_state terraform/services helm_release.headlamp
rm_state terraform/services helm_release.actualbudget

# terraform/monitoring
rm_state terraform/monitoring helm_release.prometheus
rm_state terraform/monitoring helm_release.loki
rm_state terraform/monitoring helm_release.alloy
rm_state terraform/monitoring helm_release.tempo

echo "Done. The releases keep running until Argo CD adopts them."
