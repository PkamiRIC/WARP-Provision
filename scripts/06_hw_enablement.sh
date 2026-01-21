#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILES=("/boot/config.txt" "/boot/firmware/config.txt")

log() {
  echo "[hw] $*"
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
  fi
}

set_config_kv() {
  local file="$1"
  local key="$2"
  local value="$3"
  local line="${key}=${value}"

  if [[ ! -f "$file" ]]; then
    return
  fi
  if grep -qE "^[#]*\s*${key}=" "$file"; then
    sed -i -E "s|^[#]*\s*${key}=.*|${line}|g" "$file"
  else
    echo "$line" >> "$file"
  fi
}

enable_kernel_module() {
  local module="$1"
  if ! grep -qE "^[#]*\s*${module}\b" /etc/modules; then
    echo "$module" >> /etc/modules
  fi
  modprobe "$module" || true
}

require_root

if command -v raspi-config >/dev/null 2>&1; then
  raspi-config nonint do_i2c 0
  raspi-config nonint do_spi 0
  raspi-config nonint do_serial 2 || true
  raspi-config nonint do_serial_hw 0 || true
else
  for cfg in "${CONFIG_FILES[@]}"; do
    set_config_kv "$cfg" "dtparam=i2c_arm" "on"
    set_config_kv "$cfg" "dtparam=spi" "on"
    set_config_kv "$cfg" "enable_uart" "1"
  done
fi

enable_kernel_module "i2c-dev"
enable_kernel_module "spi-bcm2835"

if systemctl list-unit-files | grep -qE '^pigpiod\.service'; then
  systemctl enable pigpiod
  systemctl start pigpiod
fi

log "Hardware enablement complete. Reboot required for changes to take full effect."
