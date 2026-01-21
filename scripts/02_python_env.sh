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

if [[ -z "${VENV_DIR:-}" ]]; then
  echo "VENV_DIR is not set in ${ENV_FILE}" >&2
  exit 1
fi

MARKER_FILE="${VENV_DIR}/.bootstrap_env_ready"

if [[ ! -d "$VENV_DIR" ]]; then
  python3 -m venv "$VENV_DIR"
fi

source "${VENV_DIR}/bin/activate"
if [[ ! -f "$MARKER_FILE" ]]; then
  python -m pip install --upgrade pip setuptools wheel
  touch "$MARKER_FILE"
fi
