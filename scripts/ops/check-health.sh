#!/usr/bin/env bash
set -Eeuo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
project_dir="${SMARTDESK_PROJECT_DIR:-$root_dir}"
disk_limit="${SMARTDESK_DISK_LIMIT_PERCENT:-85}"
memory_limit="${SMARTDESK_MEMORY_LIMIT_PERCENT:-90}"

fail() {
  echo "health_check=FAIL reason=$1" >&2
  exit 1
}

[[ "${SMARTDESK_MONITOR_FORCE_FAIL:-0}" != "1" ]] || fail "forced_test_failure"
[[ "$disk_limit" =~ ^[0-9]+$ && "$memory_limit" =~ ^[0-9]+$ ]] || fail "invalid_threshold"

cd "$project_dir"
compose=(docker compose --project-directory "$project_dir" --file "$project_dir/compose.yaml")

for service in postgres n8n caddy; do
  container_id="$("${compose[@]}" ps --quiet "$service")"
  [[ -n "$container_id" ]] || fail "${service}_container_missing"
  state="$(docker inspect --format '{{.State.Status}}' "$container_id")"
  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_id")"
  [[ "$state" == "running" ]] || fail "${service}_not_running"
  [[ "$health" == "healthy" ]] || fail "${service}_not_healthy"
done

"${compose[@]}" exec -T postgres sh -lc \
  'pg_isready -q --username="$POSTGRES_USER" --dbname="$POSTGRES_DB"' \
  || fail "postgres_readiness"

n8n_code="$(curl --silent --show-error --max-time 8 --output /dev/null \
  --write-out '%{http_code}' http://127.0.0.1:5678/healthz/readiness)"
[[ "$n8n_code" == "200" ]] || fail "n8n_readiness"

host_value="$(sed -n 's/^SMARTDESK_HOST=//p' "$project_dir/.env" | tail -n1 | tr -d '\r' | sed 's/^"//;s/"$//')"
[[ -n "$host_value" ]] || fail "public_host_missing"
https_code="$(curl --silent --show-error --max-time 12 --output /dev/null \
  --write-out '%{http_code}' "https://$host_value/")"
[[ "$https_code" == "404" ]] || fail "https_boundary_unexpected"

disk_used="$(df -P "$project_dir" | awk 'NR==2 {gsub(/%/,"",$5); print $5}')"
(( disk_used < disk_limit )) || fail "disk_threshold"

memory_used="$(awk '/MemTotal:/ {total=$2} /MemAvailable:/ {available=$2} END {printf "%d", ((total-available)*100)/total}' /proc/meminfo)"
(( memory_used < memory_limit )) || fail "memory_threshold"

echo "containers=healthy"
echo "postgres_readiness=PASS"
echo "n8n_readiness=PASS"
echo "https_boundary=PASS"
echo "resource_thresholds=PASS"
echo "health_check=PASS"
