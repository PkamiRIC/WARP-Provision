#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="/etc/warp/env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing ${ENV_FILE}. Run bootstrap.sh first." >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

SERVICE_NAME="${SERVICE_NAME:-warp-device3.service}"
PING_HOST="${PING_HOST:-8.8.8.8}"
PLC_SO_NAME="${PLC_SO_NAME:-librpiplc.so}"
PLC_PY_MODULE="${PLC_PY_MODULE:-}"
GPIO_TEST_CMD="${GPIO_TEST_CMD:-}"
PY_IMPORT_MODULE="${PY_IMPORT_MODULE:-src.main}"

fail() {
  echo "[smoke] FAIL: $*" >&2
  exit 1
}

log() {
  echo "[smoke] $*"
}

check_python_imports() {
  log "Checking Python imports"
  python - <<PY || exit 1
import importlib
importlib.import_module("${PY_IMPORT_MODULE}")
PY
}

check_plc_library() {
  log "Checking PLC library"
  if [[ -n "$PLC_PY_MODULE" ]]; then
    python - <<PY || exit 1
import importlib
importlib.import_module("${PLC_PY_MODULE}")
PY
    return
  fi
  if ! ldconfig -p | grep -q "$PLC_SO_NAME"; then
    fail "PLC library not found in ldconfig: ${PLC_SO_NAME}"
  fi
}

check_hardware() {
  if [[ -e /dev/i2c-1 || -e /dev/spidev0.0 ]]; then
    log "Hardware detected"
  else
    log "No I2C/SPI device nodes detected; skipping hardware ping"
    return
  fi

  if [[ -n "$GPIO_TEST_CMD" ]]; then
    log "Running GPIO/PLC test command"
    bash -c "$GPIO_TEST_CMD"
  else
    log "No GPIO_TEST_CMD provided; skipping active hardware test"
  fi
}

check_network() {
  log "Checking network reachability"
  ping -c 1 -W 2 "$PING_HOST" >/dev/null 2>&1 || fail "Network unreachable: $PING_HOST"
}

check_service() {
  log "Checking systemd service: $SERVICE_NAME"
  systemctl is-active --quiet "$SERVICE_NAME" || fail "Service not active: $SERVICE_NAME"
}

check_python_imports
check_plc_library
check_hardware
check_network
check_service

log "Smoke test passed"
