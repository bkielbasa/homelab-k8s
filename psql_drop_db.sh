#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
NAMESPACE="postgresql"
POD=$(kubectl get pods -n postgresql -o name | head -n1 | cut -d'/' -f2)
KCTL="kubectl"  # or "kubectl"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <username>"
  exit 1
fi

USER_NAME="$1"
DB_NAME="$USER_NAME"

# postgres identifier check
if [[ ! "$USER_NAME" =~ ^[a-z_][a-z0-9_]*$ ]]; then
  echo "Error: username must match ^[a-z_][a-z0-9_]*$"
  exit 1
fi

# helper: run psql inside the pod (non-interactive)
psql_in_pod() {
  # Usage: psql_in_pod -d <db> -c "<SQL>"
  "$KCTL" exec -n "$NAMESPACE" "$POD" -- psql -v ON_ERROR_STOP=1 "$@"
}

# Confirm before destructive action
read -r -p "Drop database \"$DB_NAME\" and role \"$USER_NAME\"? [y/N] " ANSWER
if [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# 1) Terminate active connections to the DB so it can be dropped
psql_in_pod -d postgres -c "
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();
" >/dev/null

# 2) Drop the database
psql_in_pod -d postgres -c "DROP DATABASE IF EXISTS \"$DB_NAME\""

# 3) Drop the role
psql_in_pod -d postgres -c "DROP ROLE IF EXISTS \"$USER_NAME\""

echo
echo "=== PostgreSQL user & database removed ==="
echo "User:       $USER_NAME"
echo "Database:   $DB_NAME"
