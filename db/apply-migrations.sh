#!/usr/bin/env bash
set -Eeuo pipefail

for migration_file in /opt/smartdesk/migrations/*.sql; do
  echo "Applying SmartDesk migration: $(basename "$migration_file")"
  PGPASSWORD="$SMARTDESK_DB_PASSWORD" psql \
    --username "$SMARTDESK_DB_USER" \
    --dbname "$SMARTDESK_DB_NAME" \
    --set=ON_ERROR_STOP=1 \
    --file "$migration_file"
done
