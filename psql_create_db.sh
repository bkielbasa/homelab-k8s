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

# strong random password (alphanumeric only, so it's safe in DSN/URL strings)
if command -v openssl >/dev/null 2>&1; then
  PASSWORD="$(LC_ALL=C tr -dc 'A-Za-z0-9' < <(openssl rand -base64 96) | head -c 40)"
else
  PASSWORD="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 40)"
fi

# helper: run psql inside the pod (non-interactive)
psql_in_pod() {
  # Usage: psql_in_pod -d <db> -c "<SQL>"
  # Add -U <user> if needed for your image/auth.
  "$KCTL" exec -n "$NAMESPACE" "$POD" -- psql -v ON_ERROR_STOP=1 "$@"
}

# 1) Create/alter role with password
psql_in_pod -d postgres -c "
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$USER_NAME') THEN
    EXECUTE format('CREATE ROLE %I WITH LOGIN PASSWORD %L', '$USER_NAME', '$PASSWORD');
  ELSE
    EXECUTE format('ALTER ROLE %I WITH PASSWORD %L', '$USER_NAME', '$PASSWORD');
  END IF;
END
\$\$;
"

# 2) Create DB if missing; ensure ownership
if ! psql_in_pod -Aqt -d postgres -c "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -qx 1; then
  psql_in_pod -d postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$USER_NAME\""
else
  psql_in_pod -d postgres -c "ALTER DATABASE \"$DB_NAME\" OWNER TO \"$USER_NAME\""
fi

# 3) Grant privileges on DB
psql_in_pod -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$USER_NAME\""
psql_in_pod -d postgres -c "GRANT CONNECT ON DATABASE \"$DB_NAME\" TO \"$USER_NAME\""

# 4) Schema + default privileges in the DB
psql_in_pod -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO \"$USER_NAME\""
psql_in_pod -d "$DB_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO \"$USER_NAME\""
psql_in_pod -d "$DB_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO \"$USER_NAME\""
psql_in_pod -d "$DB_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO \"$USER_NAME\""

HOST="postgresql.postgresql.svc.cluster.local"
PORT="5432"

echo
echo "=== PostgreSQL user & database created/updated ==="
echo "User:       $USER_NAME"
echo "Database:   $DB_NAME"
echo "Password:   $PASSWORD"
echo "Host:       $HOST"
echo "Port:       $PORT"

echo
echo "Go DSN (keyword/value, lib/pq & pgx):"
echo "  host=$HOST port=$PORT user=$USER_NAME password=$PASSWORD dbname=$DB_NAME sslmode=disable"
echo
echo "Go DSN (URL):"
echo "  postgres://$USER_NAME:$PASSWORD@$HOST:$PORT/$DB_NAME?sslmode=disable"

echo
echo "Store this password securely."

