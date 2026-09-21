#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: rollback-remote.sh <rollback-id> [target-directory]" >&2
  exit 2
fi

rollback_id="$1"
target_dir="$(realpath -m "${2:-$HOME/smartdesk-ai}")"
rollback_dir="$HOME/.smartdesk-deploy/rollbacks/$rollback_id"

[[ "$rollback_id" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{12}$ ]] || { echo "rollback=FAIL reason=invalid_id" >&2; exit 2; }
[[ "$target_dir" == "$HOME/"* && "$target_dir" != "$HOME" ]] || { echo "rollback=FAIL reason=unsafe_target" >&2; exit 2; }
[[ -d "$rollback_dir/files" ]] || { echo "rollback=FAIL reason=snapshot_missing" >&2; exit 1; }
[[ -f "$target_dir/.env" ]] || { echo "rollback=FAIL reason=production_env_missing" >&2; exit 1; }

migration_count="$(sed -n 's/^migration_count=//p' "$rollback_dir/metadata")"
[[ "$migration_count" == "0" ]] || { echo "rollback=FAIL reason=database_restore_required" >&2; exit 1; }

rsync -a --delete --exclude='.env' --exclude='backups/' "$rollback_dir/files/" "$target_dir/"
find "$target_dir/db" -type f -name '*.sh' -exec chmod 755 {} +
find "$target_dir/scripts" -type f -name '*.sh' -exec chmod 750 {} +
docker compose --project-directory "$target_dir" --file "$target_dir/compose.yaml" up --detach --remove-orphans --wait
SMARTDESK_PROJECT_DIR="$target_dir" "$target_dir/scripts/ops/check-health.sh"
previous_sha="$(tr -cd '0-9a-f' <"$target_dir/DEPLOYED_COMMIT" 2>/dev/null || true)"
echo "rollback=PASS sha=${previous_sha:-unknown}"
