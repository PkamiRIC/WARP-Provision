#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="warp"
INSTALL_ROOT="/usr/local"
BUILD_ROOT="/tmp/${PROJECT_NAME}-vendor"
ENV_FILE="/etc/warp/env"

mkdir -p "$BUILD_ROOT"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

log() {
  echo "[vendor] $*"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

verify_sha256() {
  local file="$1"
  local expected="$2"
  echo "${expected}  ${file}" | sha256sum -c -
}

install_librpiplc_from_git() {
  local repo_url="$1"
  local tag="$2"
  local marker="${INSTALL_ROOT}/lib/librpiplc.so"

  if [[ -f "$marker" ]]; then
    log "librpiplc already present: $marker"
    return
  fi

  require_cmd git
  require_cmd make
  require_cmd gcc

  local workdir="${BUILD_ROOT}/librpiplc"
  rm -rf "$workdir"
  git clone --depth 1 --branch "$tag" "$repo_url" "$workdir"
  make -C "$workdir"
  make -C "$workdir" install PREFIX="$INSTALL_ROOT"
}

install_industrialshields_repo() {
  local repo_url="${INDUSTRIALSHIELDS_REPO_URL:-}"
  local list_file="/etc/apt/sources.list.d/industrialshields.list"

  if [[ -z "$repo_url" ]]; then
    repo_url="https://apps.industrialshields.com/main/DebRepo/"
  fi

  if [[ -f "$list_file" ]] && grep -q "$repo_url" "$list_file"; then
    return
  fi

  echo "deb ${repo_url} ./" > "$list_file"
  apt-get update
}

install_industrialshields_packages() {
  install_industrialshields_repo

  local librpiplc_version="${LIBRPIPLC_VERSION:-}"
  local py_librpiplc_version="${PYTHON3_LIBRPIPLC_VERSION:-}"

  if [[ -n "$librpiplc_version" ]]; then
    if ! dpkg -s librpiplc >/dev/null 2>&1 || \
      ! dpkg -s librpiplc | grep -q "Version: ${librpiplc_version}"; then
      apt-get install -y "librpiplc=${librpiplc_version}"
    fi
  else
    if ! dpkg -s librpiplc >/dev/null 2>&1; then
      apt-get install -y librpiplc
    fi
  fi

  if [[ -n "$py_librpiplc_version" ]]; then
    if ! dpkg -s python3-librpiplc >/dev/null 2>&1 || \
      ! dpkg -s python3-librpiplc | grep -q "Version: ${py_librpiplc_version}"; then
      apt-get install -y "python3-librpiplc=${py_librpiplc_version}"
    fi
  else
    if ! dpkg -s python3-librpiplc >/dev/null 2>&1; then
      apt-get install -y python3-librpiplc
    fi
  fi
}

install_deb_with_checksum() {
  local url="$1"
  local sha256="$2"
  local name="$3"
  local marker="/var/lib/${PROJECT_NAME}/vendor/${name}.installed"

  if [[ -f "$marker" ]]; then
    log "${name} already installed"
    return
  fi

  require_cmd curl
  require_cmd sha256sum
  require_cmd dpkg

  mkdir -p "$(dirname "$marker")"
  local deb="${BUILD_ROOT}/${name}.deb"
  curl -fsSL "$url" -o "$deb"
  verify_sha256 "$deb" "$sha256"
  dpkg -i "$deb"
  touch "$marker"
}

install_shared_object() {
  local url="$1"
  local sha256="$2"
  local name="$3"
  local dest="${INSTALL_ROOT}/lib/${name}"

  if [[ -f "$dest" ]]; then
    log "${name} already present: $dest"
    return
  fi

  require_cmd curl
  require_cmd sha256sum

  local so="${BUILD_ROOT}/${name}"
  curl -fsSL "$url" -o "$so"
  verify_sha256 "$so" "$sha256"
  install -m 0644 "$so" "$dest"
  ldconfig
}

# --- Industrial Shields / PLC libraries ---
# Set explicit tags/versions and checksums below.

LIBRPIPLC_REPO="https://example.com/industrial-shields/librpiplc.git"
LIBRPIPLC_TAG="v0.0.0"

# install_librpiplc_from_git "$LIBRPIPLC_REPO" "$LIBRPIPLC_TAG"

# Install Industrial Shields apt repo + packages.
install_industrialshields_packages

# --- Custom .deb / .so / binary installs (examples) ---
# install_deb_with_checksum "https://example.com/vendor/foo_1.2.3_arm64.deb" \
#   "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" "foo"
#
# install_shared_object "https://example.com/vendor/libbar.so.1.2.3" \
#   "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789" "libbar.so.1.2.3"
