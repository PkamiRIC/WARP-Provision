#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILES=("/boot/config.txt" "/boot/firmware/config.txt")
SPI_OVERLAY_LINE="dtoverlay=spi0-2cs,cs0_pin=7,cs1_pin=8"
SC16_OVERLAY_LINE="dtoverlay=sc16is752-spi1-rpiplc-v4,xtal=14745600"

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

ensure_overlay_line() {
  local file="$1"
  local line="$2"
  if [[ ! -f "$file" ]]; then
    return
  fi
  if ! grep -qF "$line" "$file"; then
    echo "$line" >> "$file"
  fi
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
    ensure_overlay_line "$cfg" "$SPI_OVERLAY_LINE"
    ensure_overlay_line "$cfg" "$SC16_OVERLAY_LINE"
  done
fi

enable_kernel_module "i2c-dev"
enable_kernel_module "spi-bcm2835"

if systemctl list-unit-files | grep -qE '^pigpiod\.service'; then
  systemctl enable pigpiod
  systemctl start pigpiod
fi

log "Hardware enablement complete. Reboot required for changes to take full effect."
