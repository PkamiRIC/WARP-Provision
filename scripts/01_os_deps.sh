#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---prod}"
NO_HW="false"
VNC="false"

if [[ "${2:-}" == "--no-hw" ]]; then
  NO_HW="true"
fi
if [[ "${2:-}" == "--vnc" ]] || [[ "${3:-}" == "--vnc" ]]; then
  VNC="true"
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get upgrade -y

core_packages=(
  git
  curl
  wget
  ca-certificates
  build-essential
  pkg-config
)

python_packages=(
  python3
  python3-venv
  python3-pip
)

network_packages=(
  avahi-daemon
  net-tools
)

ui_packages=(
)

hw_packages=(
  pigpio
  i2c-tools
  spi-tools
)

missing_packages=()
for pkg in "${core_packages[@]}" "${python_packages[@]}" "${network_packages[@]}"; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    missing_packages+=("$pkg")
  fi
done

if [[ ${#missing_packages[@]} -gt 0 ]]; then
  apt-get install -y "${missing_packages[@]}"
fi

if [[ "$VNC" == "true" ]]; then
  missing_ui=()
  for pkg in "${ui_packages[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      missing_ui+=("$pkg")
    fi
  done
  if [[ ${#missing_ui[@]} -gt 0 ]]; then
    apt-get install -y "${missing_ui[@]}"
  fi
fi

if [[ "$NO_HW" != "true" ]]; then
  missing_hw=()
  for pkg in "${hw_packages[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      missing_hw+=("$pkg")
    fi
  done
  if [[ ${#missing_hw[@]} -gt 0 ]]; then
    apt-get install -y "${missing_hw[@]}"
  fi
fi
