#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="warp"
SSHD_DIR="/etc/ssh/sshd_config.d"
SSHD_DROPIN="${SSHD_DIR}/99-${PROJECT_NAME}.conf"
CONFIG_DIR="/etc/${PROJECT_NAME}"

log() {
  echo "[security] $*"
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
  fi
}

require_root

mkdir -p "$SSHD_DIR"

desired_content=$(
  cat <<'EOF'
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
EOF
)

sshd_changed="false"
if [[ ! -f "$SSHD_DROPIN" ]] || [[ "$(cat "$SSHD_DROPIN")" != "$desired_content" ]]; then
  printf '%s\n' "$desired_content" > "$SSHD_DROPIN"
  sshd_changed="true"
fi

if [[ "$sshd_changed" == "true" ]]; then
  if systemctl list-unit-files | grep -qE '^sshd\.service'; then
    systemctl reload sshd || systemctl restart sshd
  else
    systemctl reload ssh || systemctl restart ssh
  fi
fi

if [[ -d "$CONFIG_DIR" ]]; then
  find "$CONFIG_DIR" -type f -name "*.conf" -exec chmod 0640 {} +
  find "$CONFIG_DIR" -type f -name "*.env" -exec chmod 0640 {} +
  find "$CONFIG_DIR" -type f -name "*.secret" -exec chmod 0600 {} +
fi

if [[ -n "${TAILSCALE_AUTHKEY:-}" ]]; then
  if ! command -v tailscale >/dev/null 2>&1; then
    log "Installing Tailscale"
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
  if ! tailscale status >/dev/null 2>&1; then
    tailscale up --authkey="${TAILSCALE_AUTHKEY}"
  fi
fi
