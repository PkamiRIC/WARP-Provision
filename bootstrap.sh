#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="warp"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/${PROJECT_NAME}"
LOG_FILE="${LOG_DIR}/bootstrap.log"
ENV_DIR="/etc/${PROJECT_NAME}"
ENV_FILE="${ENV_DIR}/env"
DEPLOY_DIR="${ROOT_DIR}/deploy"
DEVICE_CONFIGS=(
  "device1.yaml"
  "device2.yaml"
  "device3.yaml"
)

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [--prod|--dev] [--no-hw] [--vnc] [--no-ui] --app-ref <ref>

  --prod     Run in production mode (default)
  --dev      Run in development mode
  --no-hw    Skip hardware enablement step
  --vnc      Install VNC server
  --no-ui    Skip UI setup (Next.js + Vite)
  --app-ref  App git tag/commit/branch to checkout
EOF
}

MODE="--prod"
NO_HW="false"
APP_REF=""
VNC="false"
NO_UI="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prod)
      MODE="--prod"
      shift
      ;;
    --dev)
      MODE="--dev"
      shift
      ;;
    --no-hw)
      NO_HW="true"
      shift
      ;;
    --vnc)
      VNC="true"
      shift
      ;;
    --no-ui)
      NO_UI="true"
      shift
      ;;
    --app-ref)
      APP_REF="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$APP_REF" ]]; then
  echo "Missing required --app-ref <ref>" >&2
  usage
  exit 1
fi

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
  fi
}

print_header() {
  local title="$1"
  echo
  echo "===== ${title} ====="
}

print_ok() {
  echo "[OK] $*"
}

print_fail() {
  echo "[FAIL] $*" >&2
}

require_root

mkdir -p "$LOG_DIR" "$ENV_DIR"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

print_header "Bootstrap Start"

if [[ -d "${ROOT_DIR}/scripts" ]]; then
  chmod +x "${ROOT_DIR}/scripts/"*.sh
fi

if [[ ! -f "$ENV_FILE" ]]; then
  if [[ ! -f "${DEPLOY_DIR}/env.example" ]]; then
    print_fail "Missing deploy/env.example"
    exit 1
  fi
  install -m 0640 "${DEPLOY_DIR}/env.example" "$ENV_FILE"
  print_ok "Wrote ${ENV_FILE} from env.example"
fi

if grep -q '^APP_REF=' "$ENV_FILE"; then
  sed -i -E "s|^APP_REF=.*|APP_REF=${APP_REF}|" "$ENV_FILE"
else
  echo "APP_REF=${APP_REF}" >> "$ENV_FILE"
fi

if grep -q '^APP_ENV=' "$ENV_FILE"; then
  sed -i -E "s|^APP_ENV=.*|APP_ENV=${MODE#--}|" "$ENV_FILE"
else
  echo "APP_ENV=${MODE#--}" >> "$ENV_FILE"
fi

set -a
source "$ENV_FILE"
set +a

missing_vars=()
for var in APP_REPO_URL APP_DIR VENV_DIR; do
  if [[ -z "${!var:-}" ]]; then
    missing_vars+=("$var")
  fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
  print_fail "Missing required values in ${ENV_FILE}:"
  for var in "${missing_vars[@]}"; do
    echo "  - ${var}" >&2
  done
  if printf '%s\n' "${missing_vars[@]}" | grep -q '^APP_REPO_URL$'; then
    echo "Set APP_REPO_URL in ${ENV_FILE} if you need to override." >&2
  fi
  exit 1
fi

created_configs=()
for cfg in "${DEVICE_CONFIGS[@]}"; do
  target="${ENV_DIR}/${cfg}"
  example="${ROOT_DIR}/config/${cfg}.example"
  if [[ ! -f "$target" ]]; then
    if [[ -f "$example" ]]; then
      install -m 0640 "$example" "$target"
      created_configs+=("$target")
    else
      print_fail "Missing device config: ${target}"
      echo "  Example not found at ${example}" >&2
      exit 1
    fi
  fi
done

if [[ ${#created_configs[@]} -gt 0 ]]; then
  print_fail "Device config(s) created from example:"
  for cfg in "${created_configs[@]}"; do
    echo "  - ${cfg}" >&2
  done
  echo "Edit them and re-run bootstrap." >&2
  exit 1
fi

print_ok "Config files present"

SCRIPTS=(
  "scripts/01_os_deps.sh"
  "scripts/02_python_env.sh"
  "scripts/03_app_repo.sh"
  "scripts/04_python_deps.sh"
  "scripts/05_vendor_deps.sh"
  "scripts/06_hw_enablement.sh"
  "scripts/10_ui_setup.sh"
  "scripts/07_services.sh"
  "scripts/08_security_hardening.sh"
  "scripts/09_smoke_test.sh"
)

SCRIPT_RESULTS=()

for script in "${SCRIPTS[@]}"; do
  if [[ "$script" == "scripts/06_hw_enablement.sh" && "$NO_HW" == "true" ]]; then
    echo "Skipping hardware enablement: $script"
    continue
  fi
  if [[ "$script" == "scripts/10_ui_setup.sh" && "$NO_UI" == "true" ]]; then
    echo "Skipping UI setup: $script"
    continue
  fi
  if [[ ! -e "$script" ]]; then
    print_fail "Missing required script: $script"
    exit 1
  fi
  if [[ ! -x "$script" ]]; then
    print_fail "Script is not executable: $script"
    exit 1
  fi
  print_header "Running ${script}"
  script_args=("$MODE")
  if [[ "$NO_HW" == "true" ]]; then
    script_args+=("--no-hw")
  fi
  if [[ "$VNC" == "true" ]]; then
    script_args+=("--vnc")
  fi
  if [[ "$NO_UI" == "true" ]]; then
    script_args+=("--no-ui")
  fi
  "$script" "${script_args[@]}"
  print_ok "${script} completed"
  SCRIPT_RESULTS+=("OK:${script}")
  if [[ "$script" == "scripts/02_python_env.sh" ]]; then
    # shellcheck disable=SC1091
    source "${VENV_DIR}/bin/activate"
  fi
  if [[ "$script" == "scripts/03_app_repo.sh" ]]; then
    # Reload env in case APP_REF or paths were updated.
    set -a
    source "$ENV_FILE"
    set +a
  fi
done

print_header "Bootstrap Summary"
for result in "${SCRIPT_RESULTS[@]}"; do
  status="${result%%:*}"
  name="${result#*:}"
  if [[ "$status" == "OK" ]]; then
    print_ok "$name"
  else
    print_fail "$name"
  fi
done
print_ok "Bootstrap completed successfully"
