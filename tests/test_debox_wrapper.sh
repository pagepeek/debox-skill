#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRAPPER="$ROOT_DIR/debox/scripts/debox.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    fail "expected output to contain '$needle', got: $haystack"
  fi
}

assert_file_exists() {
  local path="$1"
  [[ -f "$path" ]] || fail "expected file to exist: $path"
}

sha256_file() {
  local path="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
  else
    sha256sum "$path" | awk '{print $1}'
  fi
}

make_fake_release() {
  local release_root="$1"
  local version="$2"
  local platform="$3"
  local release_dir="$release_root/v$version"
  mkdir -p "$release_dir"

  local binary_name="debox-$version-$platform"
  local binary_path="$release_dir/$binary_name"
  cat > "$binary_path" <<'BIN'
#!/usr/bin/env bash
echo "{\"ok\":true,\"action\":\"fake.cli\",\"args\":[$(printf '%s\n' "$@" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk 'BEGIN{first=1}{if(!first)printf ","; printf "\"%s\"", $0; first=0}')],\"env_api_key_present\":$(if [[ -n "${DEBOX_API_KEY:-}" ]]; then echo true; else echo false; fi)}"
BIN
  chmod +x "$binary_path"

  local digest
  digest="$(sha256_file "$binary_path")"
  printf '%s  %s\n' "$digest" "$binary_name" > "$release_dir/checksums.txt"
}

run_with_fake_release() {
  local tmp="$1"
  shift
  local release_root="$tmp/releases"
  local cache_dir="$tmp/cache"
  local version="0.1.0"
  local platform="${DEBOX_TEST_PLATFORM:-darwin-arm64}"

  make_fake_release "$release_root" "$version" "$platform"

  DEBOX_SKILL_CLI_VERSION="$version" \
  DEBOX_SKILL_CLI_BASE_URL="file://$release_root" \
  DEBOX_SKILL_CACHE_DIR="$cache_dir" \
  DEBOX_SKILL_TEST_PLATFORM="$platform" \
  "$WRAPPER" "$@"
}

test_downloads_and_execs_cli() {
  local tmp
  tmp="$(mktemp -d)"
  local output
  output="$(run_with_fake_release "$tmp" env check --json)"
  assert_contains "$output" '"ok":true'
  assert_contains "$output" '"action":"fake.cli"'
  assert_contains "$output" '"env"'
  assert_file_exists "$tmp/cache/bin/debox-0.1.0-darwin-arm64"
}

test_cache_hit_execs_without_second_download() {
  local tmp
  tmp="$(mktemp -d)"
  run_with_fake_release "$tmp" message send-group --json >/dev/null

  rm -rf "$tmp/releases"

  local output
  output="$(
    DEBOX_SKILL_CLI_VERSION="0.1.0" \
    DEBOX_SKILL_CLI_BASE_URL="file://$tmp/releases" \
    DEBOX_SKILL_CACHE_DIR="$tmp/cache" \
    DEBOX_SKILL_TEST_PLATFORM="darwin-arm64" \
    "$WRAPPER" message send-group --json
  )"
  assert_contains "$output" '"ok":true'
  assert_contains "$output" '"send-group"'
}

test_checksum_mismatch_fails_closed() {
  local tmp
  tmp="$(mktemp -d)"
  local release_root="$tmp/releases"
  local release_dir="$release_root/v0.1.0"
  mkdir -p "$release_dir"
  cat > "$release_dir/debox-0.1.0-darwin-arm64" <<'BIN'
#!/usr/bin/env bash
echo should-not-run
BIN
  chmod +x "$release_dir/debox-0.1.0-darwin-arm64"
  printf '%s  %s\n' "0000000000000000000000000000000000000000000000000000000000000000" "debox-0.1.0-darwin-arm64" > "$release_dir/checksums.txt"

  set +e
  local output
  output="$(
    DEBOX_SKILL_CLI_VERSION="0.1.0" \
    DEBOX_SKILL_CLI_BASE_URL="file://$release_root" \
    DEBOX_SKILL_CACHE_DIR="$tmp/cache" \
    DEBOX_SKILL_TEST_PLATFORM="darwin-arm64" \
    "$WRAPPER" env check --json 2>&1
  )"
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "expected checksum mismatch to fail"
  assert_contains "$output" '"ok":false'
  assert_contains "$output" 'CHECKSUM_MISMATCH'
}

test_unsupported_platform_json_error() {
  local tmp
  tmp="$(mktemp -d)"
  set +e
  local output
  output="$(
    DEBOX_SKILL_CLI_VERSION="0.1.0" \
    DEBOX_SKILL_CLI_BASE_URL="file://$tmp/releases" \
    DEBOX_SKILL_CACHE_DIR="$tmp/cache" \
    DEBOX_SKILL_TEST_PLATFORM="plan9-mips" \
    "$WRAPPER" env check --json 2>&1
  )"
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "expected unsupported platform to fail"
  assert_contains "$output" '"ok":false'
  assert_contains "$output" 'UNSUPPORTED_PLATFORM'
}

test_skip_checksum_allows_dev_binary() {
  local tmp
  tmp="$(mktemp -d)"
  local release_root="$tmp/releases"
  local release_dir="$release_root/v0.1.0"
  mkdir -p "$release_dir"
  cat > "$release_dir/debox-0.1.0-darwin-arm64" <<'BIN'
#!/usr/bin/env bash
echo "{\"ok\":true,\"action\":\"dev.binary\"}"
BIN
  chmod +x "$release_dir/debox-0.1.0-darwin-arm64"

  local output
  output="$(
    DEBOX_SKILL_CLI_VERSION="0.1.0" \
    DEBOX_SKILL_CLI_BASE_URL="file://$release_root" \
    DEBOX_SKILL_CACHE_DIR="$tmp/cache" \
    DEBOX_SKILL_TEST_PLATFORM="darwin-arm64" \
    DEBOX_SKILL_SKIP_CHECKSUM="1" \
    "$WRAPPER" env check --json
  )"

  assert_contains "$output" '"ok":true'
  assert_contains "$output" 'dev.binary'
}

main() {
  test_downloads_and_execs_cli
  test_cache_hit_execs_without_second_download
  test_checksum_mismatch_fails_closed
  test_unsupported_platform_json_error
  test_skip_checksum_allows_dev_binary
  echo "PASS: debox wrapper tests"
}

main "$@"
