#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: remote-deploy.sh <release.tar.gz> <expected-sha> [target-directory]" >&2
  exit 2
fi

archive="$(realpath "$1")"
expected_sha="$2"
target_dir="${3:-$HOME/smartdesk-ai}"
target_dir="$(realpath -m "$target_dir")"
deploy_root="$HOME/.smartdesk-deploy"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
rollback_id="$timestamp-${expected_sha:0:12}"
rollback_dir="$deploy_root/rollbacks/$rollback_id"
install -d -m 700 "$deploy_root" "$deploy_root/rollbacks"
stage_dir="$(mktemp -d "$deploy_root/stage.XXXXXX")"

cleanup() { rm -rf -- "$stage_dir"; }
trap cleanup EXIT
umask 077

verify_health() {
  if [[ -x "$target_dir/scripts/ops/check-health.sh" ]]; then
    SMARTDESK_PROJECT_DIR="$target_dir" "$target_dir/scripts/ops/check-health.sh"
    return
  fi
  local service container_id state health
  for service in postgres n8n caddy; do
    container_id="$(docker compose --project-directory "$target_dir" --file "$target_dir/compose.yaml" ps --quiet "$service")"
    [[ -n "$container_id" ]] || return 1
    state="$(docker inspect --format '{{.State.Status}}' "$container_id")"
    health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_id")"
    [[ "$state" == "running" && "$health" == "healthy" ]] || return 1
  done
  [[ "$(curl --silent --max-time 8 --output /dev/null --write-out '%{http_code}' http://127.0.0.1:5678/healthz/readiness)" == "200" ]]
}

[[ "$expected_sha" =~ ^[0-9a-f]{40}$ ]] || { echo "deploy=FAIL reason=invalid_sha" >&2; exit 2; }
[[ "$target_dir" == "$HOME/"* && "$target_dir" != "$HOME" ]] || { echo "deploy=FAIL reason=unsafe_target" >&2; exit 2; }
[[ -f "$target_dir/.env" ]] || { echo "deploy=FAIL reason=production_env_missing" >&2; exit 1; }

if tar -tzf "$archive" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
  echo "deploy=FAIL reason=unsafe_archive" >&2
  exit 1
fi
tar -xzf "$archive" -C "$stage_dir"

# The deployment workspace is intentionally created under umask 077. Restore
# explicit artifact permissions before rsync so read-only container mounts stay
# traversable by their non-root runtime users.
find "$stage_dir" -type d -exec chmod 755 {} +
find "$stage_dir" -type f -exec chmod 644 {} +
find "$stage_dir/db" -type f -name '*.sh' -exec chmod 755 {} +
find "$stage_dir/scripts" -type f -name '*.sh' -exec chmod 750 {} +

actual_sha="$(tr -cd '0-9a-f' <"$stage_dir/DEPLOYED_COMMIT")"
[[ "$actual_sha" == "$expected_sha" ]] || { echo "deploy=FAIL reason=archive_sha_mismatch" >&2; exit 1; }
[[ ! -e "$stage_dir/.env" ]] || { echo "deploy=FAIL reason=release_contains_env" >&2; exit 1; }

docker compose --project-directory "$stage_dir" --file "$stage_dir/compose.yaml" \
  --env-file "$target_dir/.env" config --quiet

new_migrations=()
if [[ -d "$target_dir/db/migrations" ]]; then
  while IFS= read -r new_file; do
    base="$(basename "$new_file")"
    old_file="$target_dir/db/migrations/$base"
    if [[ -f "$old_file" ]]; then
      cmp --silent <(tr -d '\r' <"$old_file") <(tr -d '\r' <"$new_file") \
        || { echo "deploy=FAIL reason=immutable_migration_changed file=$base" >&2; exit 1; }
    else
      new_migrations+=("$base")
    fi
  done < <(find "$stage_dir/db/migrations" -maxdepth 1 -type f -name '*.sql' | sort)
fi

if (( ${#new_migrations[@]} > 0 )) && [[ "${ALLOW_MIGRATIONS:-0}" != "1" ]]; then
  echo "deploy=FAIL reason=new_migrations_require_explicit_approval count=${#new_migrations[@]}" >&2
  exit 1
fi

install -d -m 700 "$rollback_dir/files"
rsync -a --exclude='.env' --exclude='backups/' --exclude='.git/' "$target_dir/" "$rollback_dir/files/"
if [[ -f "$target_dir/DEPLOYED_COMMIT" ]]; then
  cp "$target_dir/DEPLOYED_COMMIT" "$rollback_dir/PREVIOUS_COMMIT"
else
  printf '%s\n' unknown >"$rollback_dir/PREVIOUS_COMMIT"
fi
printf 'migration_count=%s\n' "${#new_migrations[@]}" >"$rollback_dir/metadata"

if (( ${#new_migrations[@]} > 0 )); then
  SMARTDESK_RESTORE_DRILL=0 "$target_dir/scripts/ops/backup-smartdesk.sh"
fi

deploy_failed=0
rsync -a --delete --exclude='.env' --exclude='backups/' --exclude='.git/' "$stage_dir/" "$target_dir/" || deploy_failed=1
find "$target_dir/db" -type f -name '*.sh' -exec chmod 755 {} +
find "$target_dir/scripts" -type f -name '*.sh' -exec chmod 750 {} +

if (( deploy_failed == 0 && ${#new_migrations[@]} > 0 )); then
  set -a
  # shellcheck disable=SC1091
  source "$target_dir/.env"
  set +a
  for migration in "${new_migrations[@]}"; do
    docker compose --project-directory "$target_dir" --file "$target_dir/compose.yaml" exec -T postgres \
      psql --username "$SMARTDESK_DB_USER" --dbname "$SMARTDESK_DB_NAME" \
      --set=ON_ERROR_STOP=1 --file "/opt/smartdesk/migrations/$migration" || deploy_failed=1
    (( deploy_failed == 0 )) || break
  done
fi

if (( deploy_failed == 0 )); then
  docker compose --project-directory "$target_dir" --file "$target_dir/compose.yaml" up --detach --remove-orphans --wait || deploy_failed=1
fi
if (( deploy_failed == 0 )); then
  verify_health || deploy_failed=1
fi

if (( deploy_failed != 0 )); then
  echo "deploy=FAIL reason=deployment_or_healthcheck rollback_id=$rollback_id" >&2
  if (( ${#new_migrations[@]} == 0 )); then
    rsync -a --delete --exclude='.env' --exclude='backups/' "$rollback_dir/files/" "$target_dir/"
    [[ ! -d "$target_dir/db" ]] || find "$target_dir/db" -type f -name '*.sh' -exec chmod 755 {} +
    [[ ! -d "$target_dir/scripts" ]] || find "$target_dir/scripts" -type f -name '*.sh' -exec chmod 750 {} +
    docker compose --project-directory "$target_dir" --file "$target_dir/compose.yaml" up --detach --remove-orphans --wait
    verify_health
    echo "automatic_rollback=PASS" >&2
  else
    echo "automatic_rollback=SKIP reason=migration_restore_requires_operator" >&2
  fi
  exit 1
fi

echo "deploy=PASS sha=$expected_sha"
echo "rollback_id=$rollback_id"
echo "migration_count=${#new_migrations[@]}"
