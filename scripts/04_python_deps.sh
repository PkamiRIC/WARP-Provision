#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---prod}"
ENV_FILE="/etc/warp/env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing ${ENV_FILE}. Run bootstrap.sh first." >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

if [[ -z "${VIRTUAL_ENV:-}" ]]; then
  echo "Virtualenv is not active. Run bootstrap.sh or source the venv first." >&2
  exit 1
fi

if [[ -z "${APP_DIR:-}" || -z "${APP_REQ_PATH:-}" ]]; then
  echo "APP_DIR or APP_REQ_PATH is not set in ${ENV_FILE}" >&2
  exit 1
fi

REQ_FILE="${APP_DIR}/${APP_REQ_PATH}"
if [[ ! -f "$REQ_FILE" ]]; then
  echo "Missing requirements file: $REQ_FILE" >&2
  exit 1
fi

requirement_is_pinned() {
  local line="$1"
  if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
    return 0
  fi
  if [[ "$line" =~ ^[[:space:]]*- ]]; then
    return 0
  fi
  if [[ "$line" =~ ^[[:space:]]*git\+ ]]; then
    return 0
  fi
  if [[ "$line" =~ (==|~=|>=|<=|!=|<|>) ]]; then
    return 0
  fi
  return 1
}

validate_requirements() {
  local file="$1"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if ! requirement_is_pinned "$line"; then
      echo "Unpinned requirement in $file: $line" >&2
      exit 1
    fi
  done < "$file"
}

validate_requirements "$REQ_FILE"
req_hash_file="${VIRTUAL_ENV}/.requirements.sha256"
req_hash="$(sha256sum "$REQ_FILE" | awk '{print $1}')"
if [[ ! -f "$req_hash_file" ]] || [[ "$(cat "$req_hash_file")" != "$req_hash" ]]; then
  python -m pip install -r "$REQ_FILE"
  echo "$req_hash" > "$req_hash_file"
fi

if [[ "$MODE" == "--dev" && -n "${APP_DEV_REQ_PATH:-}" ]]; then
  DEV_REQ_FILE="${APP_DIR}/${APP_DEV_REQ_PATH}"
  if [[ -f "$DEV_REQ_FILE" ]]; then
    validate_requirements "$DEV_REQ_FILE"
    dev_hash_file="${VIRTUAL_ENV}/.requirements-dev.sha256"
    dev_hash="$(sha256sum "$DEV_REQ_FILE" | awk '{print $1}')"
    if [[ ! -f "$dev_hash_file" ]] || [[ "$(cat "$dev_hash_file")" != "$dev_hash" ]]; then
      python -m pip install -r "$DEV_REQ_FILE"
      echo "$dev_hash" > "$dev_hash_file"
    fi
  fi
fi
