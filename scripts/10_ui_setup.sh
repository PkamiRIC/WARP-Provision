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
UI_ENABLE_DEVICE1="${UI_ENABLE_DEVICE1:-true}"
UI_ENABLE_DEVICE2="${UI_ENABLE_DEVICE2:-true}"
UI_ENABLE_DEVICE3="${UI_ENABLE_DEVICE3:-true}"

if [[ "$UI_ENABLE_DEVICE1" != "true" && "$UI_ENABLE_DEVICE2" != "true" && "$UI_ENABLE_DEVICE3" != "true" ]]; then
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

build_console() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    echo "[ui] Missing ${dir}, skipping"
    return
  fi
  echo "[ui] Building ${dir}"
  install_node_deps "$dir"
  npm --prefix "$dir" run build
}

build_dashboard() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    echo "[ui] Missing ${dir}, skipping"
    return
  fi
  echo "[ui] Building ${dir}"
  install_node_deps "$dir"
  npm --prefix "$dir" run build
}

if [[ "$UI_ENABLE_DEVICE1" == "true" ]]; then
  build_console "${APP_DIR}/ui/device1-console"
  build_dashboard "${APP_DIR}/dashboard-device1"
fi

if [[ "$UI_ENABLE_DEVICE2" == "true" ]]; then
  build_console "${APP_DIR}/ui/device2-console"
  build_dashboard "${APP_DIR}/dashboard-device2"
fi

if [[ "$UI_ENABLE_DEVICE3" == "true" ]]; then
  build_console "${APP_DIR}/ui/warp-console"
  build_dashboard "${APP_DIR}/dashboard"
fi
