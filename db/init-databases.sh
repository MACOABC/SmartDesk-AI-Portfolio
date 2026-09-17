#!/usr/bin/env bash
set -Eeuo pipefail

required_variables=(
  POSTGRES_USER
  POSTGRES_DB
  N8N_DB_NAME
  N8N_DB_USER
  N8N_DB_PASSWORD
  SMARTDESK_DB_NAME
  SMARTDESK_DB_USER
  SMARTDESK_DB_PASSWORD
)

for variable_name in "${required_variables[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    echo "Required environment variable ${variable_name} is not set." >&2
    exit 1
  fi
done

if [[ "$POSTGRES_USER" == "$N8N_DB_USER" || "$POSTGRES_USER" == "$SMARTDESK_DB_USER" ]]; then
  echo "Application roles must differ from the PostgreSQL bootstrap role." >&2
  exit 1
fi

if [[ "$N8N_DB_USER" == "$SMARTDESK_DB_USER" ]]; then
  echo "n8n and SmartDesk must use different database roles." >&2
  exit 1
fi

if [[ "$POSTGRES_DB" == "$N8N_DB_NAME" || "$POSTGRES_DB" == "$SMARTDESK_DB_NAME" ]]; then
  echo "Application databases must differ from the PostgreSQL bootstrap database." >&2
  exit 1
fi

if [[ "$N8N_DB_NAME" == "$SMARTDESK_DB_NAME" ]]; then
  echo "n8n and SmartDesk must use different databases." >&2
  exit 1
fi

psql \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --set=ON_ERROR_STOP=1 <<'EOSQL'
\getenv n8n_db N8N_DB_NAME
\getenv n8n_user N8N_DB_USER
\getenv n8n_password N8N_DB_PASSWORD
\getenv smartdesk_db SMARTDESK_DB_NAME
\getenv smartdesk_user SMARTDESK_DB_USER
\getenv smartdesk_password SMARTDESK_DB_PASSWORD

SELECT format('CREATE ROLE %I LOGIN', :'n8n_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'n8n_user')
\gexec

SELECT format('ALTER ROLE %I WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD %L', :'n8n_user', :'n8n_password')
\gexec

SELECT format('CREATE ROLE %I LOGIN', :'smartdesk_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'smartdesk_user')
\gexec

SELECT format('ALTER ROLE %I WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD %L', :'smartdesk_user', :'smartdesk_password')
\gexec

SELECT format('CREATE DATABASE %I OWNER %I', :'n8n_db', :'n8n_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'n8n_db')
\gexec

SELECT format('ALTER DATABASE %I OWNER TO %I', :'n8n_db', :'n8n_user')
\gexec

SELECT format('REVOKE ALL PRIVILEGES ON DATABASE %I FROM PUBLIC', :'n8n_db')
\gexec

SELECT format('GRANT CONNECT, TEMPORARY ON DATABASE %I TO %I', :'n8n_db', :'n8n_user')
\gexec

SELECT format('CREATE DATABASE %I OWNER %I', :'smartdesk_db', :'smartdesk_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'smartdesk_db')
\gexec

SELECT format('ALTER DATABASE %I OWNER TO %I', :'smartdesk_db', :'smartdesk_user')
\gexec

SELECT format('REVOKE ALL PRIVILEGES ON DATABASE %I FROM PUBLIC', :'smartdesk_db')
\gexec

SELECT format('GRANT CONNECT, TEMPORARY ON DATABASE %I TO %I', :'smartdesk_db', :'smartdesk_user')
\gexec
EOSQL
