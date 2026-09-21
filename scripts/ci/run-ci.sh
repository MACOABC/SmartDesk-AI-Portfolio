#!/usr/bin/env bash
set -Eeuo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root_dir"

python3 scripts/ci/validate_repo.py
python3 -m unittest discover -s eval/tests -v

while IFS= read -r script; do
  bash -n "$script"
done < <(find db scripts -type f -name '*.sh' -print | sort)

docker compose --file compose.yaml --env-file .env.example config --quiet
docker compose --file ops/ci/compose.ci.yaml config --quiet

scripts/ci/test-database.sh
echo "ci_pipeline=PASS"
