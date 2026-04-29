#!/usr/bin/env bash
set -euo pipefail

ORIGINAL_ARGS=("$@")

DEFAULT_VERSION="0.1.0"
DEFAULT_BASE_URL="https://github.com/debox-pro/debox-cli/releases/download"
DEFAULT_CACHE_SUBDIR=".cache/debox-skill"

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  value="${value//$'\b'/\\b}"
  value="${value//$'\f'/\\f}"
  value="${value//$'\001'/\\u0001}"
  value="${value//$'\002'/\\u0002}"
  value="${value//$'\003'/\\u0003}"
  value="${value//$'\004'/\\u0004}"
  value="${value//$'\005'/\\u0005}"
  value="${value//$'\006'/\\u0006}"
  value="${value//$'\007'/\\u0007}"
  value="${value//$'\013'/\\u000b}"
  value="${value//$'\016'/\\u000e}"
  value="${value//$'\017'/\\u000f}"
  value="${value//$'\020'/\\u0010}"
  value="${value//$'\021'/\\u0011}"
  value="${value//$'\022'/\\u0012}"
  value="${value//$'\023'/\\u0013}"
  value="${value//$'\024'/\\u0014}"
  value="${value//$'\025'/\\u0015}"
  value="${value//$'\026'/\\u0016}"
  value="${value//$'\027'/\\u0017}"
  value="${value//$'\030'/\\u0018}"
  value="${value//$'\031'/\\u0019}"
  value="${value//$'\032'/\\u001a}"
  value="${value//$'\033'/\\u001b}"
  value="${value//$'\034'/\\u001c}"
  value="${value//$'\035'/\\u001d}"
  value="${value//$'\036'/\\u001e}"
  value="${value//$'\037'/\\u001f}"
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

resolve_cache_dir() {
  if [[ -n "${DEBOX_SKILL_CACHE_DIR:-}" ]]; then
    printf '%s' "$DEBOX_SKILL_CACHE_DIR"
    return 0
  fi

  if [[ -n "${HOME:-}" ]]; then
    printf '%s/%s' "$HOME" "$DEFAULT_CACHE_SUBDIR"
    return 0
  fi

  fail_bootstrap "HOME_NOT_SET" "HOME is not set and DEBOX_SKILL_CACHE_DIR was not provided." "Set DEBOX_SKILL_CACHE_DIR or run with HOME set so the debox CLI cache can be located."
}

resolve_platform() {
  if [[ -n "${DEBOX_SKILL_TEST_PLATFORM:-}" ]]; then
    case "$DEBOX_SKILL_TEST_PLATFORM" in
      *[!abcdefghijklmnopqrstuvwxyz0123456789-]*)
        fail_bootstrap "UNSUPPORTED_PLATFORM" "Unsupported platform override." "DEBOX_SKILL_TEST_PLATFORM must be one of darwin-arm64, darwin-amd64, linux-arm64, or linux-amd64."
        ;;
    esac
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
  local code="$3"
  local message="$4"
  local hint="$5"
  local curl_error

  if ! command -v curl >/dev/null 2>&1; then
    fail_bootstrap "MISSING_CURL" "curl is required to download the debox CLI." "Install curl or pre-populate the cache with the matching binary."
  fi

  if ! curl_error="$(curl -fsSL "$url" -o "$destination" 2>&1)"; then
    rm -f "$destination" 2>/dev/null || true
    fail_bootstrap "$code" "$message: $url" "$hint"
  fi
}

make_temp_file() {
  local var_name="$1"
  local temp_path

  if ! temp_path="$(mktemp "${TMPDIR:-/tmp}/debox-bootstrap.XXXXXX" 2>/dev/null)"; then
    fail_bootstrap "TEMP_FILE_FAILED" "Failed to create a temporary bootstrap file." "Check that TMPDIR is writable and has available space."
  fi

  printf -v "$var_name" '%s' "$temp_path"
}

move_into_cache() {
  local source="$1"
  local destination="$2"
  local code="$3"
  local message="$4"

  if ! mv "$source" "$destination" 2>/dev/null; then
    fail_bootstrap "$code" "$message" "Check that DEBOX_SKILL_CACHE_DIR is writable and has available space."
  fi
}

sha256_file() {
  local path="$1"
  local output
  local digest

  if command -v shasum >/dev/null 2>&1; then
    if ! output="$(shasum -a 256 "$path" 2>/dev/null)"; then
      fail_bootstrap "SHA256_FAILED" "Failed to calculate SHA-256 for $path." "Check that the cached debox CLI binary is readable, or remove it so it can be downloaded again."
    fi
  elif command -v sha256sum >/dev/null 2>&1; then
    if ! output="$(sha256sum "$path" 2>/dev/null)"; then
      fail_bootstrap "SHA256_FAILED" "Failed to calculate SHA-256 for $path." "Check that the cached debox CLI binary is readable, or remove it so it can be downloaded again."
    fi
  else
    fail_bootstrap "MISSING_SHA256" "No SHA-256 checksum tool is available." "Install shasum or sha256sum, or set DEBOX_SKILL_SKIP_CHECKSUM=1 for local development only."
  fi

  read -r digest _ <<<"$output"
  if [[ -z "$digest" ]]; then
    fail_bootstrap "SHA256_FAILED" "Failed to parse SHA-256 output for $path." "Check that the cached debox CLI binary is readable, or remove it so it can be downloaded again."
  fi
  printf '%s' "$digest"
}

expected_checksum_for() {
  local checksums_path="$1"
  local binary_name="$2"
  local checksum

  if [[ ! -r "$checksums_path" ]]; then
    fail_bootstrap "CHECKSUM_READ_FAILED" "Failed to read checksums file $checksums_path." "Check that the cached checksums file is readable, or remove it so it can be downloaded again."
  fi

  if ! checksum="$(awk -v name="$binary_name" '$2 == name { print $1; exit }' "$checksums_path" 2>/dev/null)"; then
    fail_bootstrap "CHECKSUM_READ_FAILED" "Failed to read checksums file $checksums_path." "Check that the cached checksums file is readable, or remove it so it can be downloaded again."
  fi
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
    rm -f "$binary_path" 2>/dev/null || true
    fail_bootstrap "CHECKSUM_MISMATCH" "Checksum mismatch for $binary_name." "Do not run this binary; verify the release source and checksums."
  fi
}

ensure_checksums() {
  if [[ -f "$checksums_path" ]]; then
    return 0
  fi

  if [[ -e "$checksums_path" ]]; then
    fail_bootstrap "CHECKSUM_CACHE_PATH_INVALID" "Cached debox CLI checksums path is not a regular file: $checksums_path." "Remove this path or set DEBOX_SKILL_CACHE_DIR to a valid cache directory."
  fi

  make_temp_file tmp_checksums
  download_file \
    "$checksums_url" \
    "$tmp_checksums" \
    "CHECKSUM_DOWNLOAD_FAILED" \
    "Failed to download debox CLI checksums" \
    "Check DEBOX_SKILL_CLI_BASE_URL, DEBOX_SKILL_CLI_VERSION, and release checksums.txt availability."
  move_into_cache "$tmp_checksums" "$checksums_path" "CHECKSUM_CACHE_WRITE_FAILED" "Failed to cache debox CLI checksums."
  tmp_checksums=""
}

version="${DEBOX_SKILL_CLI_VERSION:-$DEFAULT_VERSION}"
base_url="${DEBOX_SKILL_CLI_BASE_URL:-$DEFAULT_BASE_URL}"
skip_checksum="${DEBOX_SKILL_SKIP_CHECKSUM:-0}"
cache_dir="$(resolve_cache_dir)"

platform="$(resolve_platform)"
ensure_supported_platform "$platform"

binary_name="debox-$version-$platform"
binary_path="$cache_dir/bin/$binary_name"
checksums_path="$cache_dir/checksums/checksums-$version.txt"
release_base_url="${base_url%/}/v$version"
binary_url="$release_base_url/$binary_name"
checksums_url="$release_base_url/checksums.txt"

if ! mkdir -p "$cache_dir/bin" "$cache_dir/checksums" 2>/dev/null; then
  fail_bootstrap "CACHE_DIR_CREATE_FAILED" "Failed to create debox CLI cache directories." "Check that DEBOX_SKILL_CACHE_DIR is writable."
fi

if [[ -e "$binary_path" && ! -f "$binary_path" ]]; then
  fail_bootstrap "BINARY_CACHE_PATH_INVALID" "Cached debox CLI path is not a regular file: $binary_path." "Remove this path or set DEBOX_SKILL_CACHE_DIR to a valid cache directory."
fi

tmp_binary=""
tmp_checksums=""
cleanup_tmp() {
  if [[ -n "$tmp_binary" ]]; then
    rm -f "$tmp_binary" 2>/dev/null || true
  fi
  if [[ -n "$tmp_checksums" ]]; then
    rm -f "$tmp_checksums" 2>/dev/null || true
  fi
}
trap cleanup_tmp EXIT

if [[ ! -f "$binary_path" ]]; then
  make_temp_file tmp_binary
  download_file \
    "$binary_url" \
    "$tmp_binary" \
    "CLI_DOWNLOAD_FAILED" \
    "Failed to download debox CLI binary" \
    "Check DEBOX_SKILL_CLI_BASE_URL, DEBOX_SKILL_CLI_VERSION, platform support, and network access."

  if [[ "$skip_checksum" == "1" ]]; then
    printf 'Warning: DEBOX_SKILL_SKIP_CHECKSUM=1; executing unverified debox CLI binary.\n' >&2
  else
    ensure_checksums
    verify_checksum "$tmp_binary" "$checksums_path" "$binary_name"
  fi

  move_into_cache "$tmp_binary" "$binary_path" "BINARY_CACHE_WRITE_FAILED" "Failed to cache debox CLI binary."
  tmp_binary=""
  if [[ ! -f "$binary_path" ]]; then
    fail_bootstrap "BINARY_CACHE_PATH_INVALID" "Cached debox CLI path is not a regular file: $binary_path." "Remove this path or set DEBOX_SKILL_CACHE_DIR to a valid cache directory."
  fi
else
  if [[ "$skip_checksum" == "1" ]]; then
    printf 'Warning: DEBOX_SKILL_SKIP_CHECKSUM=1; executing unverified debox CLI binary.\n' >&2
  else
    ensure_checksums
    verify_checksum "$binary_path" "$checksums_path" "$binary_name"
  fi
fi

if ! chmod +x "$binary_path" 2>/dev/null; then
  fail_bootstrap "BINARY_CHMOD_FAILED" "Failed to mark cached debox CLI binary executable." "Check permissions for DEBOX_SKILL_CACHE_DIR."
fi

trap - EXIT
exec "$binary_path" "$@"
