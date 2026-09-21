#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: package-release.sh <40-character-sha> <output.tar.gz>" >&2
  exit 2
fi

sha="$1"
output="$(realpath -m "$2")"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo "release_package=FAIL reason=invalid_sha" >&2; exit 2; }
resolved="$(git -C "$root_dir" rev-parse "$sha^{commit}")"
[[ "$resolved" == "$sha" ]] || { echo "release_package=FAIL reason=sha_mismatch" >&2; exit 1; }

work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT
git -C "$root_dir" archive --format=tar "$sha" | tar -xf - -C "$work_dir"
printf '%s\n' "$sha" >"$work_dir/DEPLOYED_COMMIT"
tar -C "$work_dir" -czf "$output" .
tar -tzf "$output" >/dev/null
echo "release_package=PASS sha=$sha file=$(basename "$output")"
