#!/usr/bin/env bash
set -Eeuo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
compose_file="$root_dir/ops/ci/compose.ci.yaml"
project_name="smartdesk-ci-${GITHUB_RUN_ID:-local}-$$"
project_name="${project_name//[^a-zA-Z0-9_-]/-}"

cleanup() {
  docker compose --project-name "$project_name" --file "$compose_file" down --volumes --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker compose --project-name "$project_name" --file "$compose_file" up --detach --wait postgres

compose=(docker compose --project-name "$project_name" --file "$compose_file")

"${compose[@]}" exec -T postgres psql \
  --username smartdesk_ci_user \
  --dbname smartdesk_ci \
  --set=ON_ERROR_STOP=1 \
  --file /opt/smartdesk/tests/phase6_contract_tests.sql

"${compose[@]}" exec -T postgres psql \
  --username smartdesk_ci_user \
  --dbname smartdesk_ci \
  --set=ON_ERROR_STOP=1 \
  --file /opt/smartdesk/analytics/gate8_checks.sql

schema_result="$("${compose[@]}" exec -T postgres psql \
  --username smartdesk_ci_user \
  --dbname smartdesk_ci \
  --tuples-only --no-align --set=ON_ERROR_STOP=1 \
  --command "SELECT (SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE') >= 4 AND (SELECT count(*) FROM information_schema.views WHERE table_schema='analytics') = 4;")"

if [[ "$schema_result" != "t" ]]; then
  echo "database_schema_validation=FAIL" >&2
  exit 1
fi

# Migration 005 is intentionally CREATE OR REPLACE and must be safe to reapply.
"${compose[@]}" exec -T postgres psql \
  --username smartdesk_ci_user \
  --dbname smartdesk_ci \
  --set=ON_ERROR_STOP=1 \
  --file /opt/smartdesk/migrations/005_phase8_analytics_views.sql >/dev/null

echo "database_schema_validation=PASS"
echo "database_integration=PASS"
