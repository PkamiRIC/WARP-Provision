#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---prod}"
NO_UI="false"

if [[ "${2:-}" == "--no-ui" ]] || [[ "${3:-}" == "--no-ui" ]] || [[ "${4:-}" == "--no-ui" ]]; then
  NO_UI="true"
fi

ENV_FILE="/etc/warp/env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing ${ENV_FILE}. Run bootstrap.sh first." >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

if [[ "$NO_UI" == "true" ]]; then
  echo "[ui] Skipping UI setup"
  exit 0
fi

APP_DIR="${APP_DIR:-/opt/warp/app}"
UI_API_BASE="${UI_API_BASE:-http://localhost:8003}"
UI_ENABLE_WARP_CONSOLE="${UI_ENABLE_WARP_CONSOLE:-true}"
UI_ENABLE_DASHBOARD="${UI_ENABLE_DASHBOARD:-true}"

if [[ "$UI_ENABLE_WARP_CONSOLE" != "true" && "$UI_ENABLE_DASHBOARD" != "true" ]]; then
  echo "[ui] UI disabled via env"
  exit 0
fi

ensure_node() {
  if command -v node >/dev/null 2>&1; then
    local major
    major="$(node -v | sed -E 's/^v([0-9]+).*/\1/')"
    if [[ "$major" -ge 20 ]]; then
      return
    fi
  fi
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required to install Node.js" >&2
    exit 1
  fi
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
}

ensure_node

install_node_deps() {
  local dir="$1"
  if [[ -f "${dir}/package-lock.json" ]]; then
    npm --prefix "$dir" ci
  else
    npm --prefix "$dir" install
  fi
}

build_warp_console() {
  local dir="${APP_DIR}/ui/warp-console"
  if [[ ! -d "$dir" ]]; then
    echo "[ui] Missing ${dir}, skipping warp-console"
    return
  fi
  echo "[ui] Building warp-console"
  install_node_deps "$dir"
  NEXT_PUBLIC_API_BASE="$UI_API_BASE" npm --prefix "$dir" run build
}

build_dashboard() {
  local dir="${APP_DIR}/dashboard"
  if [[ ! -d "$dir" ]]; then
    echo "[ui] Missing ${dir}, skipping dashboard"
    return
  fi
  echo "[ui] Building dashboard"
  install_node_deps "$dir"
  VITE_DEVICE3_URL="$UI_API_BASE" npm --prefix "$dir" run build
}

if [[ "$UI_ENABLE_WARP_CONSOLE" == "true" ]]; then
  build_warp_console
fi

if [[ "$UI_ENABLE_DASHBOARD" == "true" ]]; then
  build_dashboard
fi
