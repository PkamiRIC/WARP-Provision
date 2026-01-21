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

for var in APP_REPO_URL APP_DIR APP_REF; do
  if [[ -z "${!var:-}" ]]; then
    echo "${var} is not set in ${ENV_FILE}" >&2
    exit 1
  fi
done

if ! command -v git >/dev/null 2>&1; then
  echo "git is required but not installed." >&2
  exit 1
fi

if [[ ! -d "$APP_DIR" ]]; then
  mkdir -p "$APP_DIR"
  git clone "$APP_REPO_URL" "$APP_DIR"
fi

if [[ ! -d "${APP_DIR}/.git" ]]; then
  echo "${APP_DIR} exists but is not a git repo" >&2
  exit 1
fi

git -C "$APP_DIR" fetch --all --tags

resolve_ref() {
  local ref="$1"
  if git -C "$APP_DIR" rev-parse --verify "${ref}^{commit}" >/dev/null 2>&1; then
    echo "$ref"
    return 0
  fi
  if git -C "$APP_DIR" rev-parse --verify "origin/${ref}^{commit}" >/dev/null 2>&1; then
    echo "origin/${ref}"
    return 0
  fi
  return 1
}

target_ref="$(resolve_ref "$APP_REF")" || {
  echo "Unable to resolve ref: $APP_REF" >&2
  exit 1
}

git -C "$APP_DIR" checkout --force "$target_ref"
git -C "$APP_DIR" reset --hard "$target_ref"
