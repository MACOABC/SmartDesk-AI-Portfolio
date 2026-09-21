#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: restore-drill.sh <smartdesk-backup.tar.gz>" >&2
  exit 2
fi

archive="$(realpath "$1")"
if [[ ! -r "$archive" || "$archive" != *.tar.gz ]]; then
  echo "restore_drill=FAIL reason=plaintext_archive_required" >&2
  exit 2
fi

work_dir="$(mktemp -d)"
token="$(date +%s)-$$"
container="smartdesk-restore-$token"
volume="smartdesk-restore-$token"
cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
  docker volume rm "$volume" >/dev/null 2>&1 || true
  rm -rf -- "$work_dir"
}
trap cleanup EXIT
umask 077

tar -xzf "$archive" -C "$work_dir"
(cd "$work_dir" && sha256sum --check SHA256SUMS >/dev/null)

docker volume create "$volume" >/dev/null
docker run --detach --name "$container" --network none \
  --security-opt no-new-privileges:true \
  --env POSTGRES_PASSWORD=restore_drill_local_only \
  --volume "$volume:/var/lib/postgresql/data" \
  --volume "$work_dir:/backup:ro" \
  postgres:17.11-bookworm >/dev/null

ready=0
for _ in $(seq 1 60); do
  if docker exec "$container" pg_isready --username postgres --dbname postgres >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [[ "$ready" != "1" ]]; then
  echo "restore_drill=FAIL reason=isolated_postgres_not_ready" >&2
  exit 1
fi

docker exec "$container" createdb --username postgres smartdesk_restore
docker exec "$container" createdb --username postgres n8n_restore
docker exec "$container" pg_restore --username postgres --dbname smartdesk_restore \
  --no-owner --no-privileges --exit-on-error /backup/smartdesk.dump
docker exec "$container" pg_restore --username postgres --dbname n8n_restore \
  --no-owner --no-privileges --exit-on-error /backup/n8n.dump

compare_counts() {
  local database="$1"
  local expected_file="$2"
  local table expected actual
  while IFS=$'\t' read -r table expected; do
    [[ -z "$table" ]] && continue
    if [[ ! "$table" =~ ^[a-zA-Z_][a-zA-Z0-9_]*\.[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
      echo "restore_drill=FAIL reason=unsafe_count_identifier" >&2
      return 1
    fi
    actual="$(docker exec "$container" psql --username postgres --dbname "$database" \
      --tuples-only --no-align --set=ON_ERROR_STOP=1 --command "SELECT count(*) FROM $table;")"
    if [[ "$actual" != "$expected" ]]; then
      echo "restore_drill=FAIL reason=row_count_mismatch table=$table" >&2
      return 1
    fi
  done <"$expected_file"
}

compare_counts smartdesk_restore "$work_dir/smartdesk-counts.tsv"
compare_counts n8n_restore "$work_dir/n8n-counts.tsv"

analytics_views="$(docker exec "$container" psql --username postgres --dbname smartdesk_restore \
  --tuples-only --no-align --set=ON_ERROR_STOP=1 \
  --command "SELECT count(*) FROM information_schema.views WHERE table_schema='analytics';")"
invalid_constraints="$(docker exec "$container" psql --username postgres --dbname smartdesk_restore \
  --tuples-only --no-align --set=ON_ERROR_STOP=1 \
  --command "SELECT count(*) FROM pg_constraint WHERE contype IN ('f','c') AND NOT convalidated;")"
if [[ "$analytics_views" != "4" || "$invalid_constraints" != "0" ]]; then
  echo "restore_drill=FAIL reason=schema_or_constraint_validation" >&2
  exit 1
fi

echo "restore_environment=isolated_no_published_ports"
echo "restore_row_counts=PASS"
echo "restore_constraints=PASS"
echo "restore_drill=PASS"
