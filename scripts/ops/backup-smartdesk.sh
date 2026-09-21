#!/usr/bin/env bash
set -Eeuo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
project_dir="${SMARTDESK_PROJECT_DIR:-$root_dir}"
backup_dir="${SMARTDESK_BACKUP_DIR:-$project_dir/backups}"
retention_days="${SMARTDESK_BACKUP_RETENTION_DAYS:-14}"
recipient_cert="${SMARTDESK_BACKUP_RECIPIENT_CERT:-}"
run_restore_drill="${SMARTDESK_RESTORE_DRILL:-0}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_name="smartdesk-$timestamp"

if [[ "$backup_dir" != /* || "$backup_dir" == "/" ]]; then
  echo "backup_configuration=FAIL reason=unsafe_backup_directory" >&2
  exit 2
fi
if [[ ! "$retention_days" =~ ^[0-9]+$ ]] || (( retention_days < 1 )); then
  echo "backup_configuration=FAIL reason=invalid_retention" >&2
  exit 2
fi

install -d -m 700 "$backup_dir"
stage_dir="$(mktemp -d "$backup_dir/.${backup_name}.stage.XXXXXX")"
plain_archive="$backup_dir/$backup_name.tar.gz"
cleanup() {
  rm -rf -- "$stage_dir"
}
trap cleanup EXIT
umask 077

cd "$project_dir"
set -a
# shellcheck disable=SC1091
source ./.env
set +a

compose=(docker compose --project-directory "$project_dir" --file "$project_dir/compose.yaml")

if [[ "$("${compose[@]}" ps --status running --services | sort | paste -sd, -)" != "caddy,n8n,postgres" ]]; then
  echo "backup_precheck=FAIL reason=critical_service_not_running" >&2
  exit 1
fi

"${compose[@]}" exec -T postgres pg_dump \
  --username "$POSTGRES_USER" --dbname "$SMARTDESK_DB_NAME" \
  --format=custom --compress=6 --no-password >"$stage_dir/smartdesk.dump"

"${compose[@]}" exec -T postgres pg_dump \
  --username "$POSTGRES_USER" --dbname "$N8N_DB_NAME" \
  --format=custom --compress=6 --no-password >"$stage_dir/n8n.dump"

"${compose[@]}" exec -T n8n tar -C /home/node/.n8n -czf - . >"$stage_dir/n8n-data.tar.gz"

capture_counts() {
  local database="$1"
  local output="$2"
  local tables table count
  tables="$("${compose[@]}" exec -T postgres psql \
    --username "$POSTGRES_USER" --dbname "$database" \
    --tuples-only --no-align --set=ON_ERROR_STOP=1 \
    --command "SELECT schemaname || '.' || tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema') ORDER BY 1;")"
  : >"$output"
  while IFS= read -r table; do
    [[ -z "$table" ]] && continue
    if [[ ! "$table" =~ ^[a-zA-Z_][a-zA-Z0-9_]*\.[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
      echo "backup_counts=FAIL reason=unsafe_identifier" >&2
      return 1
    fi
    count="$("${compose[@]}" exec -T postgres psql \
      --username "$POSTGRES_USER" --dbname "$database" \
      --tuples-only --no-align --set=ON_ERROR_STOP=1 \
      --command "SELECT count(*) FROM $table;")"
    printf '%s\t%s\n' "$table" "$count" >>"$output"
  done <<<"$tables"
}

capture_counts "$SMARTDESK_DB_NAME" "$stage_dir/smartdesk-counts.tsv"
capture_counts "$N8N_DB_NAME" "$stage_dir/n8n-counts.tsv"

"${compose[@]}" exec -T postgres pg_restore --list <"$stage_dir/smartdesk.dump" >/dev/null
"${compose[@]}" exec -T postgres pg_restore --list <"$stage_dir/n8n.dump" >/dev/null
tar -tzf "$stage_dir/n8n-data.tar.gz" >/dev/null

deployed_commit="unknown"
if [[ -f "$project_dir/DEPLOYED_COMMIT" ]]; then
  candidate="$(tr -cd '0-9a-fA-F' <"$project_dir/DEPLOYED_COMMIT")"
  [[ "$candidate" =~ ^[0-9a-fA-F]{40}$ ]] && deployed_commit="$candidate"
fi
cat >"$stage_dir/metadata.txt" <<EOF
format_version=1
created_utc=$timestamp
deployed_commit=$deployed_commit
postgres_image=postgres:17.11-bookworm
contents=smartdesk_db,n8n_db,n8n_data
EOF

(
  cd "$stage_dir"
  sha256sum smartdesk.dump n8n.dump n8n-data.tar.gz smartdesk-counts.tsv n8n-counts.tsv metadata.txt >SHA256SUMS
)

tar -C "$stage_dir" -czf "$plain_archive" .
chmod 600 "$plain_archive"
tar -tzf "$plain_archive" >/dev/null

if [[ "$run_restore_drill" == "1" ]]; then
  "$root_dir/scripts/ops/restore-drill.sh" "$plain_archive"
fi

final_archive="$plain_archive"
if [[ -n "$recipient_cert" ]]; then
  if [[ ! -r "$recipient_cert" ]]; then
    echo "backup_encryption=FAIL reason=recipient_certificate_unreadable" >&2
    exit 1
  fi
  final_archive="$plain_archive.cms"
  openssl cms -encrypt -binary -aes-256-cbc -outform DER \
    -in "$plain_archive" -out "$final_archive" "$recipient_cert"
  chmod 600 "$final_archive"
  openssl cms -cmsout -inform DER -in "$final_archive" -noout >/dev/null
  rm -f -- "$plain_archive"
  echo "backup_encryption=PASS"
else
  echo "backup_encryption=SKIP reason=recipient_certificate_not_configured"
fi

sha256sum "$final_archive" >"$final_archive.sha256"
chmod 600 "$final_archive.sha256"

find "$backup_dir" -maxdepth 1 -type f \
  \( -name 'smartdesk-*.tar.gz' -o -name 'smartdesk-*.tar.gz.cms' -o -name 'smartdesk-*.tar.gz.cms.sha256' \) \
  -mtime "+$retention_days" -delete

echo "backup_validation=PASS"
echo "backup_file=$(basename "$final_archive")"
