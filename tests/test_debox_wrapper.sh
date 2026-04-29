#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRAPPER="$ROOT_DIR/debox/scripts/debox.sh"
TMP_DIRS=()

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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    fail "expected output not to contain '$needle', got: $haystack"
  fi
}

assert_file_exists() {
  local path="$1"
  [[ -f "$path" ]] || fail "expected file to exist: $path"
}

assert_file_not_exists() {
  local path="$1"
  [[ ! -f "$path" ]] || fail "expected file not to exist: $path"
}

assert_starts_with() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != "$needle"* ]]; then
    fail "expected output to start with '$needle', got: $haystack"
  fi
}

make_tmp_dir() {
  local var_name="$1"
  local created
  created="$(mktemp -d)"
  TMP_DIRS+=("$created")
  printf -v "$var_name" '%s' "$created"
}

cleanup_all() {
  local path
  for path in "${TMP_DIRS[@]}"; do
    rm -rf "$path"
  done
}

trap cleanup_all EXIT

sha256_file() {
  local path="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
  else
    fail "missing SHA-256 tool"
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
  local platform="darwin-arm64"

  make_fake_release "$release_root" "$version" "$platform"

  DEBOX_SKILL_CLI_VERSION="$version" \
  DEBOX_SKILL_CLI_BASE_URL="file://$release_root" \
  DEBOX_SKILL_CACHE_DIR="$cache_dir" \
  DEBOX_SKILL_TEST_PLATFORM="$platform" \
  DEBOX_SKILL_SKIP_CHECKSUM="0" \
  "$WRAPPER" "$@"
}

test_downloads_and_execs_cli() {
  local tmp
  make_tmp_dir tmp

  local output
  output="$(run_with_fake_release "$tmp" env check --json)"
  assert_contains "$output" '"ok":true'
  assert_contains "$output" '"action":"fake.cli"'
  assert_contains "$output" '"args":["env","check","--json"]'
  assert_file_exists "$tmp/cache/bin/debox-0.1.0-darwin-arm64"
}

test_cache_hit_execs_without_second_download() {
  local tmp
  make_tmp_dir tmp

  run_with_fake_release "$tmp" message send-group --json >/dev/null

  rm -rf "$tmp/releases"

  local output
  output="$(
    DEBOX_SKILL_CLI_VERSION="0.1.0" \
    DEBOX_SKILL_CLI_BASE_URL="file://$tmp/releases" \
    DEBOX_SKILL_CACHE_DIR="$tmp/cache" \
    DEBOX_SKILL_TEST_PLATFORM="darwin-arm64" \
    DEBOX_SKILL_SKIP_CHECKSUM="0" \
    "$WRAPPER" message send-group --json
  )"
  assert_contains "$output" '"ok":true'
  assert_contains "$output" '"send-group"'
  assert_contains "$output" '"args":["message","send-group","--json"]'
}

test_checksum_mismatch_fails_closed() {
  local tmp
  make_tmp_dir tmp

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
    DEBOX_SKILL_SKIP_CHECKSUM="0" \
    "$WRAPPER" env check --json 2>&1
  )"
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "expected checksum mismatch to fail"
  assert_contains "$output" '"ok":false'
  assert_contains "$output" 'CHECKSUM_MISMATCH'
  assert_contains "$output" '"hint"'
  assert_not_contains "$output" 'should-not-run'
}

test_checksum_download_failure_does_not_cache_binary() {
  local tmp
  make_tmp_dir tmp

  local release_root="$tmp/releases"
  local release_dir="$release_root/v0.1.0"
  mkdir -p "$release_dir"
  cat > "$release_dir/debox-0.1.0-darwin-arm64" <<'BIN'
#!/usr/bin/env bash
echo should-not-cache
BIN
  chmod +x "$release_dir/debox-0.1.0-darwin-arm64"

  set +e
  local output
  output="$(
    DEBOX_SKILL_CLI_VERSION="0.1.0" \
    DEBOX_SKILL_CLI_BASE_URL="file://$release_root" \
    DEBOX_SKILL_CACHE_DIR="$tmp/cache" \
    DEBOX_SKILL_TEST_PLATFORM="darwin-arm64" \
    DEBOX_SKILL_SKIP_CHECKSUM="0" \
    "$WRAPPER" env check --json 2>&1
  )"
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "expected checksum download failure to fail"
  assert_starts_with "$output" '{'
  assert_contains "$output" 'CHECKSUM_DOWNLOAD_FAILED'
  assert_contains "$output" '"hint"'
  assert_not_contains "$output" 'curl:'
  assert_not_contains "$output" 'should-not-cache'
  assert_file_not_exists "$tmp/cache/bin/debox-0.1.0-darwin-arm64"
}

test_checksum_entry_missing_does_not_cache_binary() {
  local tmp
  make_tmp_dir tmp

  local release_root="$tmp/releases"
  local release_dir="$release_root/v0.1.0"
  mkdir -p "$release_dir"
  cat > "$release_dir/debox-0.1.0-darwin-arm64" <<'BIN'
#!/usr/bin/env bash
echo should-not-cache-missing-entry
BIN
  chmod +x "$release_dir/debox-0.1.0-darwin-arm64"
  printf '%s  %s\n' "0000000000000000000000000000000000000000000000000000000000000000" "debox-0.1.0-linux-amd64" > "$release_dir/checksums.txt"

  set +e
  local output
  output="$(
    DEBOX_SKILL_CLI_VERSION="0.1.0" \
    DEBOX_SKILL_CLI_BASE_URL="file://$release_root" \
    DEBOX_SKILL_CACHE_DIR="$tmp/cache" \
    DEBOX_SKILL_TEST_PLATFORM="darwin-arm64" \
    DEBOX_SKILL_SKIP_CHECKSUM="0" \
    "$WRAPPER" env check --json 2>&1
  )"
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "expected missing checksum entry to fail"
  assert_starts_with "$output" '{'
  assert_contains "$output" 'CHECKSUM_NOT_FOUND'
  assert_contains "$output" '"hint"'
  assert_not_contains "$output" 'should-not-cache-missing-entry'
  assert_file_not_exists "$tmp/cache/bin/debox-0.1.0-darwin-arm64"
}

test_binary_download_failure_json_is_clean() {
  local tmp
  make_tmp_dir tmp

  local release_root="$tmp/releases"
  mkdir -p "$release_root/v0.1.0"

  set +e
  local output
  output="$(
    DEBOX_SKILL_CLI_VERSION="0.1.0" \
    DEBOX_SKILL_CLI_BASE_URL="file://$release_root" \
    DEBOX_SKILL_CACHE_DIR="$tmp/cache" \
    DEBOX_SKILL_TEST_PLATFORM="darwin-arm64" \
    DEBOX_SKILL_SKIP_CHECKSUM="0" \
    "$WRAPPER" env check --json 2>&1
  )"
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "expected binary download failure to fail"
  assert_starts_with "$output" '{'
  assert_contains "$output" 'CLI_DOWNLOAD_FAILED'
  assert_contains "$output" '"hint"'
  assert_not_contains "$output" 'curl:'
  assert_file_not_exists "$tmp/cache/bin/debox-0.1.0-darwin-arm64"
}

test_cached_binary_checksum_mismatch_fails_closed() {
  local tmp
  make_tmp_dir tmp

  run_with_fake_release "$tmp" env check --json >/dev/null

  cat > "$tmp/cache/bin/debox-0.1.0-darwin-arm64" <<'BIN'
#!/usr/bin/env bash
echo should-not-run-cached
BIN
  chmod +x "$tmp/cache/bin/debox-0.1.0-darwin-arm64"

  set +e
  local output
  output="$(
    DEBOX_SKILL_CLI_VERSION="0.1.0" \
    DEBOX_SKILL_CLI_BASE_URL="file://$tmp/releases" \
    DEBOX_SKILL_CACHE_DIR="$tmp/cache" \
    DEBOX_SKILL_TEST_PLATFORM="darwin-arm64" \
    DEBOX_SKILL_SKIP_CHECKSUM="0" \
    "$WRAPPER" env check --json 2>&1
  )"
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "expected cached checksum mismatch to fail"
  assert_contains "$output" 'CHECKSUM_MISMATCH'
  assert_contains "$output" '"hint"'
  assert_not_contains "$output" 'should-not-run-cached'
}

test_unsupported_platform_json_error() {
  local tmp
  make_tmp_dir tmp

  set +e
  local output
  output="$(
    DEBOX_SKILL_CLI_VERSION="0.1.0" \
    DEBOX_SKILL_CLI_BASE_URL="file://$tmp/releases" \
    DEBOX_SKILL_CACHE_DIR="$tmp/cache" \
    DEBOX_SKILL_TEST_PLATFORM="plan9-mips" \
    DEBOX_SKILL_SKIP_CHECKSUM="0" \
    "$WRAPPER" env check --json 2>&1
  )"
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "expected unsupported platform to fail"
  assert_contains "$output" '"ok":false'
  assert_contains "$output" 'UNSUPPORTED_PLATFORM'
  assert_contains "$output" '"hint"'
}

test_preserves_complex_arguments() {
  local tmp
  make_tmp_dir tmp

  local output
  output="$(run_with_fake_release "$tmp" message send-group --content 'hello world "quoted" *' '' --json)"
  assert_contains "$output" '"ok":true'
  assert_contains "$output" '"args":["message","send-group","--content","hello world \"quoted\" *","","--json"]'
}

test_skip_checksum_allows_dev_binary() {
  local tmp
  make_tmp_dir tmp

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
    "$WRAPPER" env check --json 2>&1
  )"

  assert_contains "$output" '"ok":true'
  assert_contains "$output" 'dev.binary'
  if [[ "$output" != *'DEBOX_SKILL_SKIP_CHECKSUM=1'* && "$output" != *'unverified'* ]]; then
    fail "expected skip-checksum warning, got: $output"
  fi
}

main() {
  test_downloads_and_execs_cli
  test_cache_hit_execs_without_second_download
  test_checksum_mismatch_fails_closed
  test_checksum_download_failure_does_not_cache_binary
  test_checksum_entry_missing_does_not_cache_binary
  test_binary_download_failure_json_is_clean
  test_cached_binary_checksum_mismatch_fails_closed
  test_unsupported_platform_json_error
  test_preserves_complex_arguments
  test_skip_checksum_allows_dev_binary
  echo "PASS: debox wrapper tests"
}

main "$@"
