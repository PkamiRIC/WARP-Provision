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
    exit 2
  fi
done

if ! command -v git >/dev/null 2>&1; then
  echo "git is required but not installed." >&2
  exit 1
fi

if [[ ! -d "$APP_DIR" ]]; then
  mkdir -p "$APP_DIR"
  git clone "$APP_REPO_URL" "$APP_DIR"
else
  git -C "$APP_DIR" remote set-url origin "$APP_REPO_URL"
fi

if [[ ! -d "${APP_DIR}/.git" ]]; then
  echo "${APP_DIR} exists but is not a git repo" >&2
  exit 1
fi

git -C "$APP_DIR" fetch --all --tags --prune

# Reset any local changes to keep provisioning deterministic.
git -C "$APP_DIR" reset --hard

if git -C "$APP_DIR" show-ref --verify --quiet "refs/remotes/origin/${APP_REF}"; then
  git -C "$APP_DIR" checkout --force -B "$APP_REF" "origin/${APP_REF}"
  git -C "$APP_DIR" reset --hard "origin/${APP_REF}"
else
  git -C "$APP_DIR" checkout --force "$APP_REF"
  git -C "$APP_DIR" reset --hard "$APP_REF"
fi

echo "Checked out $(git -C "$APP_DIR" rev-parse --short HEAD)"
