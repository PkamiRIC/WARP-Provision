#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="warp"
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/deploy"
SYSTEMD_DIR="/etc/systemd/system"
ENV_FILE="/etc/${PROJECT_NAME}/env"

log() {
  echo "[services] $*"
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
  fi
}

require_root

if [[ ! -d "$DEPLOY_DIR" ]]; then
  echo "Missing deploy directory: $DEPLOY_DIR" >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing ${ENV_FILE}. Run bootstrap.sh first." >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

UI_ENABLE_DEVICE1="${UI_ENABLE_DEVICE1:-true}"
UI_ENABLE_DEVICE2="${UI_ENABLE_DEVICE2:-true}"
UI_ENABLE_DEVICE3="${UI_ENABLE_DEVICE3:-true}"

shopt -s nullglob
service_files=("${DEPLOY_DIR}"/*.service)
if [[ ${#service_files[@]} -eq 0 ]]; then
  echo "No .service files found in ${DEPLOY_DIR}" >&2
  exit 1
fi

for svc_src in "${service_files[@]}"; do
  svc_name="$(basename "$svc_src")"
  if [[ "$svc_name" == "warp-ui-device1.service" || "$svc_name" == "warp-dashboard-device1.service" ]]; then
    if [[ "$UI_ENABLE_DEVICE1" != "true" ]]; then
      log "Skipping ${svc_name} (UI_ENABLE_DEVICE1=false)"
      continue
    fi
  fi
  if [[ "$svc_name" == "warp-ui-device2.service" || "$svc_name" == "warp-dashboard-device2.service" ]]; then
    if [[ "$UI_ENABLE_DEVICE2" != "true" ]]; then
      log "Skipping ${svc_name} (UI_ENABLE_DEVICE2=false)"
      continue
    fi
  fi
  if [[ "$svc_name" == "warp-ui-device3.service" || "$svc_name" == "warp-dashboard-device3.service" ]]; then
    if [[ "$UI_ENABLE_DEVICE3" != "true" ]]; then
      log "Skipping ${svc_name} (UI_ENABLE_DEVICE3=false)"
      continue
    fi
  fi
  if [[ "$svc_name" == "warp-ui.service" || "$svc_name" == "warp-dashboard.service" ]]; then
    log "Skipping legacy UI service ${svc_name}"
    continue
  fi
  svc_dest="${SYSTEMD_DIR}/${svc_name}"
  service_changed="false"

  if [[ ! -f "$svc_dest" ]] || ! cmp -s "$svc_src" "$svc_dest"; then
    install -m 0644 "$svc_src" "$svc_dest"
    service_changed="true"
  fi

  if [[ "$service_changed" == "true" ]]; then
    systemctl daemon-reload
  fi
  if ! systemctl is-enabled --quiet "$svc_name"; then
    systemctl enable "$svc_name"
  fi
  if ! systemctl is-active --quiet "$svc_name"; then
    systemctl start "$svc_name"
  fi
  log "Installed and started ${svc_name}"
done
