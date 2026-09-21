#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$EUID" -ne 0 ]]; then
  echo "install_systemd=FAIL reason=root_required" >&2
  exit 1
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
unit_dir="$root_dir/ops/systemd"

for unit in smartdesk-health.service smartdesk-health.timer smartdesk-health-alert@.service smartdesk-backup.service smartdesk-backup.timer; do
  install -m 0644 "$unit_dir/$unit" "/etc/systemd/system/$unit"
done

systemctl daemon-reload
systemctl enable --now smartdesk-health.timer smartdesk-backup.timer
echo "install_systemd=PASS"
