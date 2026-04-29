#!/usr/bin/env bash
set -euo pipefail

ORIGINAL_ARGS=("$@")

DEFAULT_VERSION="0.1.0"
DEFAULT_BASE_URL="https://github.com/debox-pro/debox-cli/releases/download"
DEFAULT_CACHE_DIR="$HOME/.cache/debox-skill"

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

args_include_json() {
  local arg
  for arg in "${ORIGINAL_ARGS[@]}"; do
    if [[ "$arg" == "--json" ]]; then
      return 0
    fi
  done
  return 1
}

fail_bootstrap() {
  local code="$1"
  local message="$2"
  local hint="$3"

  if args_include_json; then
    printf '{"ok":false,"action":"bootstrap","error":{"code":"%s","message":"%s","hint":"%s"}}\n' \
      "$(json_escape "$code")" \
      "$(json_escape "$message")" \
      "$(json_escape "$hint")" >&2
  else
    printf 'debox bootstrap failed [%s]: %s\nHint: %s\n' "$code" "$message" "$hint" >&2
  fi
  exit 1
}

resolve_platform() {
  if [[ -n "${DEBOX_SKILL_TEST_PLATFORM:-}" ]]; then
    printf '%s' "$DEBOX_SKILL_TEST_PLATFORM"
    return 0
  fi

  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Darwin) os="darwin" ;;
    Linux) os="linux" ;;
    *) fail_bootstrap "UNSUPPORTED_PLATFORM" "Unsupported operating system: $os" "Supported platforms are darwin-arm64, darwin-amd64, linux-arm64, and linux-amd64." ;;
  esac

  case "$arch" in
    arm64|aarch64) arch="arm64" ;;
    x86_64|amd64) arch="amd64" ;;
    *) fail_bootstrap "UNSUPPORTED_PLATFORM" "Unsupported CPU architecture: $arch" "Supported platforms are darwin-arm64, darwin-amd64, linux-arm64, and linux-amd64." ;;
  esac

  printf '%s-%s' "$os" "$arch"
}

ensure_supported_platform() {
  local platform="$1"
  case "$platform" in
    darwin-arm64|darwin-amd64|linux-arm64|linux-amd64) ;;
    *) fail_bootstrap "UNSUPPORTED_PLATFORM" "Unsupported platform: $platform" "Set DEBOX_SKILL_TEST_PLATFORM only to a supported platform, or run on macOS/Linux arm64/amd64." ;;
  esac
}

download_file() {
  local url="$1"
  local destination="$2"

  if ! command -v curl >/dev/null 2>&1; then
    fail_bootstrap "MISSING_CURL" "curl is required to download the debox CLI." "Install curl or pre-populate the cache with the matching binary."
  fi

  if ! curl -fsSL "$url" -o "$destination"; then
    fail_bootstrap "DOWNLOAD_FAILED" "Failed to download $url" "Check DEBOX_SKILL_CLI_BASE_URL, DEBOX_SKILL_CLI_VERSION, and network access."
  fi
}

sha256_file() {
  local path="$1"

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
  else
    fail_bootstrap "MISSING_SHA256" "No SHA-256 checksum tool is available." "Install shasum or sha256sum, or set DEBOX_SKILL_SKIP_CHECKSUM=1 for local development only."
  fi
}

expected_checksum_for() {
  local checksums_path="$1"
  local binary_name="$2"
  local checksum

  checksum="$(awk -v name="$binary_name" '$2 == name { print $1; found = 1; exit } END { if (!found) exit 1 }' "$checksums_path" || true)"
  if [[ -z "$checksum" ]]; then
    fail_bootstrap "CHECKSUM_NOT_FOUND" "No checksum entry found for $binary_name." "Verify the release checksums.txt includes the requested platform binary."
  fi

  printf '%s' "$checksum"
}

verify_checksum() {
  local binary_path="$1"
  local checksums_path="$2"
  local binary_name="$3"
  local expected actual

  expected="$(expected_checksum_for "$checksums_path" "$binary_name")"
  actual="$(sha256_file "$binary_path")"

  if [[ "$actual" != "$expected" ]]; then
    fail_bootstrap "CHECKSUM_MISMATCH" "Checksum mismatch for $binary_name." "Do not run this binary; verify the release source and checksums."
  fi
}

version="${DEBOX_SKILL_CLI_VERSION:-$DEFAULT_VERSION}"
base_url="${DEBOX_SKILL_CLI_BASE_URL:-$DEFAULT_BASE_URL}"
cache_dir="${DEBOX_SKILL_CACHE_DIR:-$DEFAULT_CACHE_DIR}"
skip_checksum="${DEBOX_SKILL_SKIP_CHECKSUM:-0}"

platform="$(resolve_platform)"
ensure_supported_platform "$platform"

binary_name="debox-$version-$platform"
binary_path="$cache_dir/bin/$binary_name"
checksums_path="$cache_dir/checksums/checksums-$version.txt"
release_base_url="${base_url%/}/v$version"
binary_url="$release_base_url/$binary_name"
checksums_url="$release_base_url/checksums.txt"

if [[ ! -f "$binary_path" ]]; then
  mkdir -p "$cache_dir/bin" "$cache_dir/checksums"

  tmp_binary="$(mktemp "${TMPDIR:-/tmp}/debox-bootstrap.XXXXXX")"
  cleanup_tmp() {
    rm -f "$tmp_binary"
  }
  trap cleanup_tmp EXIT

  download_file "$binary_url" "$tmp_binary"

  if [[ "$skip_checksum" == "1" ]]; then
    printf 'Warning: DEBOX_SKILL_SKIP_CHECKSUM=1; executing unverified debox CLI binary.\n' >&2
  else
    download_file "$checksums_url" "$checksums_path"
    verify_checksum "$tmp_binary" "$checksums_path" "$binary_name"
  fi

  mv "$tmp_binary" "$binary_path"
  trap - EXIT
fi

chmod +x "$binary_path"
exec "$binary_path" "$@"
