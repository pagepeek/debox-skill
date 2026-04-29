# debox skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first version of `debox skill`, centered on a stable `debox/scripts/debox.sh` wrapper that bootstraps a compiled DeBox CLI and concise references that guide agents through safe DeBox one-shot operations.

**Architecture:** The skill is a small routing layer in `debox/SKILL.md`, with detailed context split into reference files loaded only when needed. Executable operations go through `debox/scripts/debox.sh`, which detects platform, downloads and verifies a cached CLI binary, then `exec`s it with the original arguments. Tests exercise the shell wrapper using local fake release assets so no real DeBox API or external release is required.

**Tech Stack:** Markdown skill files, POSIX-compatible shell with Bash test harness, `curl`, `shasum` or `sha256sum`, git.

---

## File Structure

Create these files:

- `debox/SKILL.md`: skill metadata and routing workflow for agents.
- `debox/scripts/debox.sh`: stable wrapper that downloads, verifies, caches, and invokes the compiled DeBox CLI.
- `debox/references/credentials.md`: credential sources, environment variables, and redaction rules.
- `debox/references/messaging.md`: group/private message workflows and examples that call `debox.sh`.
- `debox/references/bot-registration.md`: user-owned Bot registration and Open Platform checklist.
- `debox/references/miniapp.md`: MiniApp/browser/wallet integration guidance.
- `debox/references/chatwidget.md`: ChatWidget integration guidance.
- `debox/references/shares-safety.md`: safety policy for Shares, signing, transfers, Swap, and chain buttons.
- `debox/references/troubleshooting.md`: common failures and CLI/API error handling.
- `tests/test_debox_wrapper.sh`: shell tests for `debox/scripts/debox.sh`.

Modify these files:

- `docs/superpowers/plans/2026-04-29-debox-skill.md`: track this implementation plan only while executing.

No compiled DeBox CLI source is implemented in this plan. The CLI is an external release artifact invoked through `debox/scripts/debox.sh`.

---

### Task 1: Create Skill Skeleton

**Files:**
- Create: `debox/SKILL.md`
- Create: `debox/scripts/.gitkeep`
- Create: `debox/references/.gitkeep`

- [ ] **Step 1: Create the skill directories**

Run:

```bash
mkdir -p debox/scripts debox/references
touch debox/scripts/.gitkeep debox/references/.gitkeep
```

Expected: command exits `0`.

- [ ] **Step 2: Write the initial `SKILL.md`**

Create `debox/SKILL.md` with:

```markdown
---
name: debox skill
description: Use when an agent needs to use DeBox OpenPlatform for safe one-shot community operations such as sending group/private messages, checking DeBox credentials, parsing group IDs, or guiding DeBox Bot registration, MiniApp, ChatWidget, or Shares integration. Prefer the bundled debox/scripts/debox.sh wrapper for executable operations and do not use for long-running Bot runtime management.
---

# debox skill

Use this skill to help an agent use DeBox as a community action surface without hand-writing DeBox API requests.

## Scope

This skill supports:

- Sending DeBox group and private messages through `scripts/debox.sh`.
- Checking local DeBox credential readiness.
- Parsing and validating DeBox group IDs.
- Guiding user-owned Bot registration.
- Routing MiniApp, ChatWidget, and Shares questions to focused references.

This skill does not support:

- Long-running Bot runtime processes.
- Polling loops or webhook server deployment.
- Scheduling or background task queues.
- Automatic token transfers, Swap, signing, or Shares execution.
- Asking for wallet private keys, mnemonics, or seed phrases.

## First Action

Classify the user's request:

- **One-shot message or lookup**: use `scripts/debox.sh` and include `--json`.
- **Credentials or setup**: read `references/credentials.md`.
- **Group/private messaging**: read `references/messaging.md`.
- **Bot registration**: read `references/bot-registration.md`.
- **MiniApp or wallet-in-browser integration**: read `references/miniapp.md`.
- **ChatWidget embedding**: read `references/chatwidget.md`.
- **Shares, signing, transfer, Swap, or chain buttons**: read `references/shares-safety.md`.
- **Failures or unclear CLI/API output**: read `references/troubleshooting.md`.

## Executable Operations

Always prefer the wrapper:

```bash
debox/scripts/debox.sh <command> --json
```

Before sending messages, run:

```bash
debox/scripts/debox.sh env check --json
```

Do not call DeBox OpenPlatform with raw `curl` unless `debox/scripts/debox.sh` is unavailable and the user explicitly accepts the fallback.

## Credential Rules

Read credentials from environment variables:

```bash
DEBOX_API_KEY=
DEBOX_APP_ID=
DEBOX_APP_SECRET=
DEBOX_WEBHOOK_KEY=
```

Never ask for wallet private keys, mnemonics, or seed phrases. Never place DeBox secrets in command-line arguments, code snippets, logs, or frontend code. Webhook verification should use the CLI's safe input mode once available; avoid placing header values in shell history or logs.

## Required Output Handling

For agent-initiated commands, include `--json` and trust the exit code:

- Exit code `0` means the JSON should contain `"ok": true`.
- Non-zero exit means the JSON should contain `"ok": false` and an `error.hint`.

Report success with the DeBox target and returned identifier. Report failure with the CLI's structured hint.
```

- [ ] **Step 3: Verify the skeleton files exist**

Run:

```bash
find debox -maxdepth 3 -type f | sort
```

Expected output contains:

```text
debox/SKILL.md
debox/references/.gitkeep
debox/scripts/.gitkeep
```

- [ ] **Step 4: Commit the skeleton**

Run:

```bash
git add debox/SKILL.md debox/scripts/.gitkeep debox/references/.gitkeep
git commit -m "Add debox skill skeleton"
```

Expected: commit succeeds.

---

### Task 2: Add Wrapper Tests First

**Files:**
- Create: `tests/test_debox_wrapper.sh`
- Test: `tests/test_debox_wrapper.sh`

- [ ] **Step 1: Write failing wrapper tests**

Create `tests/test_debox_wrapper.sh` with:

```bash
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
```

- [ ] **Step 2: Make the tests executable**

Run:

```bash
chmod +x tests/test_debox_wrapper.sh
```

Expected: command exits `0`.

- [ ] **Step 3: Run tests and verify they fail because the wrapper is not implemented**

Run:

```bash
tests/test_debox_wrapper.sh
```

Expected: FAIL with a message indicating `debox/scripts/debox.sh` does not exist or is not executable.

- [ ] **Step 4: Commit the failing tests**

Run:

```bash
git add tests/test_debox_wrapper.sh
git commit -m "test: add debox wrapper bootstrap tests"
```

Expected: commit succeeds.

---

### Task 3: Implement `scripts/debox.sh`

**Files:**
- Create: `debox/scripts/debox.sh`
- Delete: `debox/scripts/.gitkeep`
- Test: `tests/test_debox_wrapper.sh`

- [ ] **Step 1: Write the wrapper implementation**

Create `debox/scripts/debox.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VERSION="0.1.0"
DEFAULT_BASE_URL="https://github.com/debox-pro/debox-cli/releases/download"

json_requested() {
  for arg in "$@"; do
    if [[ "$arg" == "--json" ]]; then
      return 0
    fi
  done
  return 1
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

fail_bootstrap() {
  local code="$1"
  local message="$2"
  local hint="$3"
  local status="${4:-1}"

  if json_requested "$@"; then
    :
  fi

  if json_requested "${ORIGINAL_ARGS[@]}"; then
    printf '{"ok":false,"action":"bootstrap","error":{"code":"%s","message":"%s","hint":"%s"}}\n' \
      "$(json_escape "$code")" \
      "$(json_escape "$message")" \
      "$(json_escape "$hint")" >&2
  else
    printf 'debox skill bootstrap failed: %s\nHint: %s\n' "$message" "$hint" >&2
  fi
  exit "$status"
}

detect_platform() {
  if [[ -n "${DEBOX_SKILL_TEST_PLATFORM:-}" ]]; then
    printf '%s' "$DEBOX_SKILL_TEST_PLATFORM"
    return 0
  fi

  local os
  local arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "$os" in
    darwin) os="darwin" ;;
    linux) os="linux" ;;
    *) fail_bootstrap "UNSUPPORTED_PLATFORM" "Unsupported operating system: $os" "Use darwin or linux, or provide a supported DeBox CLI binary manually." ;;
  esac

  case "$arch" in
    arm64|aarch64) arch="arm64" ;;
    x86_64|amd64) arch="amd64" ;;
    *) fail_bootstrap "UNSUPPORTED_PLATFORM" "Unsupported CPU architecture: $arch" "Use amd64 or arm64, or provide a supported DeBox CLI binary manually." ;;
  esac

  printf '%s-%s' "$os" "$arch"
}

validate_platform() {
  local platform="$1"
  case "$platform" in
    darwin-arm64|darwin-amd64|linux-arm64|linux-amd64) return 0 ;;
    *) fail_bootstrap "UNSUPPORTED_PLATFORM" "Unsupported platform: $platform" "Supported platforms are darwin-arm64, darwin-amd64, linux-arm64, and linux-amd64." ;;
  esac
}

download_file() {
  local url="$1"
  local dest="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest" || return 1
    return 0
  fi

  fail_bootstrap "MISSING_CURL" "curl is required to download the DeBox CLI." "Install curl or pre-populate DEBOX_SKILL_CACHE_DIR with the DeBox CLI binary."
}

sha256_file() {
  local path="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
    return 0
  fi
  fail_bootstrap "MISSING_SHA256" "No SHA-256 tool found." "Install shasum or sha256sum, or set DEBOX_SKILL_SKIP_CHECKSUM=1 for local development only."
}

verify_checksum() {
  local binary_path="$1"
  local binary_name="$2"
  local checksums_path="$3"

  local expected
  expected="$(awk -v name="$binary_name" '$2 == name {print $1}' "$checksums_path" | head -n 1)"
  if [[ -z "$expected" ]]; then
    fail_bootstrap "CHECKSUM_NOT_FOUND" "No checksum entry found for $binary_name." "Ensure the release checksums.txt contains an entry for this platform."
  fi

  local actual
  actual="$(sha256_file "$binary_path")"
  if [[ "$actual" != "$expected" ]]; then
    rm -f "$binary_path"
    fail_bootstrap "CHECKSUM_MISMATCH" "Checksum mismatch for $binary_name." "Do not run this binary. Check the release source or update the checksum file."
  fi
}

main() {
  ORIGINAL_ARGS=("$@")

  local version="${DEBOX_SKILL_CLI_VERSION:-$DEFAULT_VERSION}"
  local base_url="${DEBOX_SKILL_CLI_BASE_URL:-$DEFAULT_BASE_URL}"
  local cache_dir="${DEBOX_SKILL_CACHE_DIR:-$HOME/.cache/debox-skill}"
  local skip_checksum="${DEBOX_SKILL_SKIP_CHECKSUM:-0}"

  local platform
  platform="$(detect_platform)"
  validate_platform "$platform"

  local binary_name="debox-$version-$platform"
  local bin_dir="$cache_dir/bin"
  local checksums_dir="$cache_dir/checksums"
  local binary_path="$bin_dir/$binary_name"
  local checksums_path="$checksums_dir/checksums-$version.txt"
  local release_url="$base_url/v$version"

  mkdir -p "$bin_dir" "$checksums_dir"

  if [[ ! -x "$binary_path" ]]; then
    local tmp_binary="$binary_path.tmp.$$"
    if ! download_file "$release_url/$binary_name" "$tmp_binary"; then
      rm -f "$tmp_binary"
      fail_bootstrap "CLI_DOWNLOAD_FAILED" "Failed to download the DeBox CLI binary." "Check network access or set DEBOX_SKILL_CLI_BASE_URL."
    fi

    if [[ "$skip_checksum" != "1" ]]; then
      if [[ ! -f "$checksums_path" ]]; then
        if ! download_file "$release_url/checksums.txt" "$checksums_path.tmp.$$"; then
          rm -f "$tmp_binary" "$checksums_path.tmp.$$"
          fail_bootstrap "CHECKSUM_DOWNLOAD_FAILED" "Failed to download checksums.txt." "Check release assets or set DEBOX_SKILL_CLI_BASE_URL to a valid release root."
        fi
        mv "$checksums_path.tmp.$$" "$checksums_path"
      fi
      verify_checksum "$tmp_binary" "$binary_name" "$checksums_path"
    else
      printf 'Warning: DEBOX_SKILL_SKIP_CHECKSUM=1; running an unverified DeBox CLI binary.\n' >&2
    fi

    chmod +x "$tmp_binary"
    mv "$tmp_binary" "$binary_path"
  fi

  exec "$binary_path" "$@"
}

ORIGINAL_ARGS=("$@")
main "$@"
```

- [ ] **Step 2: Remove the placeholder and make the wrapper executable**

Run:

```bash
rm -f debox/scripts/.gitkeep
chmod +x debox/scripts/debox.sh
```

Expected: command exits `0`.

- [ ] **Step 3: Run wrapper tests**

Run:

```bash
tests/test_debox_wrapper.sh
```

Expected output:

```text
PASS: debox wrapper tests
```

- [ ] **Step 4: If `fail_bootstrap` errors because `ORIGINAL_ARGS` is unbound, patch the wrapper**

Replace the top of `fail_bootstrap` in `debox/scripts/debox.sh` with this implementation:

```bash
fail_bootstrap() {
  local code="$1"
  local message="$2"
  local hint="$3"
  local status="${4:-1}"

  local args=()
  if declare -p ORIGINAL_ARGS >/dev/null 2>&1; then
    args=("${ORIGINAL_ARGS[@]}")
  else
    args=()
  fi

  if json_requested "${args[@]}"; then
    printf '{"ok":false,"action":"bootstrap","error":{"code":"%s","message":"%s","hint":"%s"}}\n' \
      "$(json_escape "$code")" \
      "$(json_escape "$message")" \
      "$(json_escape "$hint")" >&2
  else
    printf 'debox skill bootstrap failed: %s\nHint: %s\n' "$message" "$hint" >&2
  fi
  exit "$status"
}
```

Then run:

```bash
tests/test_debox_wrapper.sh
```

Expected output:

```text
PASS: debox wrapper tests
```

- [ ] **Step 5: Commit the wrapper**

Run:

```bash
git add debox/scripts/debox.sh tests/test_debox_wrapper.sh
git rm --cached -q debox/scripts/.gitkeep 2>/dev/null || true
git add -u debox/scripts
git commit -m "Add debox CLI bootstrap wrapper"
```

Expected: commit succeeds.

---

### Task 4: Add Credential and Messaging References

**Files:**
- Create: `debox/references/credentials.md`
- Create: `debox/references/messaging.md`
- Delete: `debox/references/.gitkeep`

- [ ] **Step 1: Write credential reference**

Create `debox/references/credentials.md` with:

```markdown
# DeBox Credentials

Use this reference when the user needs to configure DeBox OpenPlatform access or when `debox/scripts/debox.sh env check --json` reports missing credentials.

## Environment Variables

The skill and CLI read credentials from environment variables:

```bash
export DEBOX_API_KEY="..."
export DEBOX_APP_ID="..."
export DEBOX_APP_SECRET="..."
export DEBOX_WEBHOOK_KEY="..."
```

`DEBOX_API_KEY` is required for one-shot message sending and most OpenPlatform calls. `DEBOX_APP_ID` identifies the developer app or Bot. `DEBOX_APP_SECRET` is only for sensitive APIs such as payment, transfer, or point-related calls, which are outside this skill's v1 executable scope. `DEBOX_WEBHOOK_KEY` is used to verify DeBox webhook callbacks.

## Agent Rules

- Do not ask for wallet private keys, mnemonics, or seed phrases.
- Do not pass API keys or app secrets as command-line arguments.
- Do not put secrets in frontend code, examples, logs, commits, or screenshots.
- Do not echo full secrets back to the user.
- If a secret must be discussed, refer to it by variable name.

## Readiness Check

Run:

```bash
debox/scripts/debox.sh env check --json
```

If this fails, report the CLI's `error.hint` and ask the user to set the missing environment variable locally.

## Where Values Come From

The user obtains DeBox OpenPlatform values from the DeBox developer portal after connecting the wallet that owns the DeBox account:

- App ID: application or Bot identifier.
- API Key: primary API credential for OpenPlatform calls.
- App Secret: sensitive credential, usually available after advanced developer verification.
- Webhook Key: generated after webhook configuration and sent by DeBox in the `X-API-KEY` callback header.
```

- [ ] **Step 2: Write messaging reference**

Create `debox/references/messaging.md` with:

```markdown
# DeBox Messaging

Use this reference when the user asks to send a DeBox group message, send a DeBox private message, parse a group ID, or understand message-related CLI output.

## Always Use the Wrapper

For executable operations, use:

```bash
debox/scripts/debox.sh <command> --json
```

Do not hand-write raw DeBox API `curl` calls unless the wrapper is unavailable and the user explicitly accepts the fallback.

## Group ID Extraction

If the user gives a DeBox invite URL such as:

```text
https://m.debox.pro/group?id=fxi3hqo5
```

Run:

```bash
debox/scripts/debox.sh group parse-id \
  --url "https://m.debox.pro/group?id=fxi3hqo5" \
  --json
```

Use the returned `group_id` in message commands.

## Send Group Message

First check credentials:

```bash
debox/scripts/debox.sh env check --json
```

Then send:

```bash
debox/scripts/debox.sh message send-group \
  --group-id "fxi3hqo5" \
  --type text \
  --content "hello" \
  --json
```

Report the returned `message_id` if present. If the command fails, report `error.hint`.

## Send Private Message

First check credentials:

```bash
debox/scripts/debox.sh env check --json
```

Then send:

```bash
debox/scripts/debox.sh message send-private \
  --user-id "uvg2p6ho" \
  --type text \
  --content "hello" \
  --json
```

## Query Group or User Information

When the CLI supports these commands:

```bash
debox/scripts/debox.sh group info --group-id "fxi3hqo5" --json
debox/scripts/debox.sh user info --user-id "uvg2p6ho" --json
```

Use the output to confirm targets before sending messages.

## Message Type Rules

Use `--type text` for plain notifications. Use richer message types only when the user asks for links, images, or structured content and the CLI supports the requested format.

Do not include DeBox credentials in message content.
```

- [ ] **Step 3: Remove reference placeholder**

Run:

```bash
rm -f debox/references/.gitkeep
```

Expected: command exits `0`.

- [ ] **Step 4: Verify references contain no placeholders**

Run:

```bash
rg -n "T[B]D|T[O]DO|debox[-]agent|DEBOX[_]AGENT" debox/references/credentials.md debox/references/messaging.md
```

Expected: no output and exit code `1`.

- [ ] **Step 5: Commit credential and messaging references**

Run:

```bash
git add debox/references/credentials.md debox/references/messaging.md
git add -u debox/references
git commit -m "Add debox credential and messaging references"
```

Expected: commit succeeds.

---

### Task 5: Add Integration and Safety References

**Files:**
- Create: `debox/references/bot-registration.md`
- Create: `debox/references/miniapp.md`
- Create: `debox/references/chatwidget.md`
- Create: `debox/references/shares-safety.md`
- Create: `debox/references/troubleshooting.md`

- [ ] **Step 1: Write Bot registration reference**

Create `debox/references/bot-registration.md` with:

```markdown
# DeBox Bot Registration

Use this reference when the user asks how to create or configure a DeBox Bot. This skill does not run a Bot runtime.

## Ownership Boundary

The user must register and authorize the Bot with their own DeBox wallet account. Do not ask for private keys, mnemonics, or seed phrases. Do not attempt to operate the user's wallet.

## Registration Flow

1. The user creates or selects a DeBox account in the DeBox app or web app.
2. The user opens the DeBox developer portal.
3. The user connects the wallet that owns the DeBox account and signs in.
4. The user creates or enables the Bot.
5. The user configures nickname, avatar, profile, App Domain, and optional Webhook URL.
6. The user copies the required non-wallet credentials into local environment variables.

## Fields

- App ID: unique application or Bot identifier.
- API Key: required for most OpenPlatform and Bot API calls.
- App Secret: required only for sensitive APIs, outside this skill's v1 executable scope.
- App Domain: trusted domain for webhook callbacks.
- Webhook URL: HTTPS endpoint that receives DeBox message callbacks.
- Webhook Key: sent by DeBox in the callback `X-API-KEY` header.

## When to Use CLI Instead

If the user only needs to send a group notification or private message, prefer `debox/scripts/debox.sh` one-shot commands. Do not introduce runtime, polling, or webhook server design for simple sending tasks.
```

- [ ] **Step 2: Write MiniApp reference**

Create `debox/references/miniapp.md` with:

```markdown
# DeBox MiniApp

Use this reference when the user wants to adapt a web product to run inside DeBox.

## Core Model

A DeBox MiniApp is an H5/web application opened inside DeBox's built-in browser. Existing HTML/CSS/JavaScript applications can often run with minimal changes, but must be mobile-friendly and served over HTTPS.

## Detect DeBox Browser

Use user agent detection:

```javascript
const isDeBox = !!window?.navigator?.userAgent?.includes("DeBox");
```

Use this only as an environment check. Keep a normal browser fallback.

## Wallet Environment

Inside DeBox, the app may have injected wallet objects such as `window.ethereum` or `window.solana`. Use them for wallet authorization and address access only after explicit user action. Route signing, transfer, and transaction requests to `shares-safety.md`.

## Secret Handling

Do not put `DEBOX_API_KEY`, `DEBOX_APP_SECRET`, or equivalent OpenPlatform credentials in frontend code. If a DeBox OpenPlatform call needs secrets, place it behind a private backend endpoint.

## Agent Guidance

For MiniApp requests, provide an integration checklist and minimal examples. For transaction-related requests, provide only placeholder, review, or dry-run examples with no signing or submission calls.
```

- [ ] **Step 3: Write ChatWidget reference**

Create `debox/references/chatwidget.md` with:

```markdown
# DeBox ChatWidget

Use this reference when the user wants to embed DeBox chat into an external web page.

## Integration Options

Use the official packages when available:

```bash
npm install @debox-pro/chat-widget-html
npm install @debox-pro/chat-widget-react
```

Native HTML initialization:

```javascript
import { DeBoxChatWidget } from "@debox-pro/chat-widget-html";

DeBoxChatWidget.init({
  projectId: "your-project-id",
  zIndex: "999",
  containerDomId: "chat-container",
  defaultOpen: false,
  destroyOnClose: false
});

DeBoxChatWidget.setConversation("conversation-id");
```

React usage:

```jsx
import { DeBoxChatWidget } from "@debox-pro/chat-widget-react";

export function ChatPanel() {
  return (
    <DeBoxChatWidget
      projectId="your-project-id"
      conversationId="conversation-id"
      onEvent={(event) => console.log(event.detail)}
    />
  );
}
```

## Conversation ID

The widget needs a DeBox conversation ID, which refers to the chat group ID used by ChatWidget. Current ChatWidget support is scoped to on-chain token-holding group chats. If obtaining the conversation ID requires OpenPlatform credentials, put that lookup on a private backend and keep credentials out of frontend code.

## Agent Guidance

For ChatWidget requests, help the user choose HTML or React integration and explain where `projectId` and `conversationId` come from. Avoid runtime/Bot design; for Bot runtime requests, explain that it is outside this skill's executable scope and provide only high-level pointers.
```

- [ ] **Step 4: Write Shares safety reference**

Create `debox/references/shares-safety.md` with:

```markdown
# DeBox Shares and Chain Safety

Use this reference for Shares, signing, transfers, Swap, chain buttons, or any request that could move assets or authorize wallet actions.

## Default Stance

Treat these tasks as high risk. By default, generate templates, explain parameters, or review user-provided code. Do not auto-execute real asset-moving actions.

## Hard Rules

- Never ask for private keys, mnemonics, or seed phrases.
- Never hide recipient, token, chain ID, amount, allowance, calldata, or contract address from the user.
- Even with explicit confirmation, this v1 skill does not broadcast, sign, or send real transactions, call Swap, enable real allowances, or integrate production Shares contract addresses into deployable code.
- Do not place App Secret or API keys in frontend code.
- Prefer testnet or dry-run examples when possible.

## Allowed Without Extra Confirmation

- Explain DeBox Shares concepts.
- Generate placeholder-only contract or frontend templates with no production addresses, no real amounts, and no transaction submission or signing calls.
- Decode or summarize user-provided transaction parameters.
- Identify which fields need user review.

## Explicit Confirmation Can Allow

- Review of user-provided code, calldata, or transaction parameters.
- Placeholder templates that still avoid production addresses, real amounts, and execution calls.
- Parameter explanation for a user-provided chain, token, amount, recipient, allowance, calldata, or contract.
- High-level conceptual next steps or official-doc pointers only, with no real recipient, amount, calldata, allowance, signing, or broadcast steps.

## Outside V1 Executable Scope

- Broadcasting, signing, or sending a real transaction.
- Creating calldata for a specific real recipient and amount.
- Enabling a real ERC20 allowance.
- Calling Swap.
- Integrating production Shares contract addresses into deployable code.

When explicit confirmation is needed for review, explanation, placeholder templates, or outside-the-skill conceptual pointers, summarize the exact chain, token, amount, recipient, contract, and risk before proceeding.
```

- [ ] **Step 5: Write troubleshooting reference**

Create `debox/references/troubleshooting.md` with:

```markdown
# DeBox Troubleshooting

Use this reference when `debox/scripts/debox.sh` fails, DeBox OpenPlatform returns an error, or the user reports missing messages or setup issues.

## Common Wrapper Bootstrap Errors

This list is not exhaustive; for unlisted bootstrap failures, inspect the JSON `error.code` and follow `error.hint`.

- `BINARY_CACHE_PATH_INVALID`: cached CLI path is not a regular file. Remove the path or use another cache directory.
- `BINARY_CHMOD_FAILED`: the wrapper could not mark the cached CLI executable. Check cache permissions.
- `BINARY_CACHE_WRITE_FAILED`: the wrapper could not write the downloaded CLI into cache. Check cache permissions and disk space.
- `CACHE_DIR_CREATE_FAILED`: the wrapper could not create cache directories. Check `DEBOX_SKILL_CACHE_DIR`.
- `CHECKSUM_CACHE_PATH_INVALID`: cached checksum path is not a regular file. Remove the path or use another cache directory.
- `CHECKSUM_CACHE_WRITE_FAILED`: the wrapper could not write checksum metadata into cache. Check cache permissions and disk space.
- `CHECKSUM_DOWNLOAD_FAILED`: release is missing `checksums.txt` or the base URL is wrong.
- `CHECKSUM_MISMATCH`: do not run the binary; verify the release source.
- `CHECKSUM_NOT_FOUND`: `checksums.txt` lacks the platform binary entry.
- `CHECKSUM_READ_FAILED`: the wrapper could not read cached checksum metadata. Remove the cached checksum file.
- `CLI_DOWNLOAD_FAILED`: check network access or set `DEBOX_SKILL_CLI_BASE_URL`.
- `CLI_EXEC_FAILED`: cached CLI could not start cleanly. Remove the cached binary and retry.
- `HOME_NOT_SET`: set `DEBOX_SKILL_CACHE_DIR` or run with `HOME` set.
- `MISSING_CURL`: install `curl` or pre-populate the cache.
- `MISSING_SHA256`: install `shasum` or `sha256sum`, or use `DEBOX_SKILL_SKIP_CHECKSUM=1` for local development only.
- `SHA256_FAILED`: checksum calculation failed. Check cache readability or remove the cached binary.
- `TEMP_FILE_FAILED`: temporary file creation failed. Check `TMPDIR`.
- `UNSUPPORTED_PLATFORM`: supported platforms are `darwin-arm64`, `darwin-amd64`, `linux-arm64`, and `linux-amd64`.

## Common DeBox API Errors

- `-2004`: invalid parameter. Check group ID, user ID, message type, and required content.
- `-2013`: access token expired. Re-authorize the relevant user flow.
- `-2015`: access token check failure. Verify token source and headers.
- `-7048`: insufficient balance. Do not retry blindly.

## Group ID Issues

A DeBox group invite URL can contain `id=<group_id>`. Use:

```bash
debox/scripts/debox.sh group parse-id --url "https://m.debox.pro/group?id=fxi3hqo5" --json
```

## Bot Message Receiving Issues

This skill does not manage Bot runtime. If the user is using a Bot outside this skill:

- If Webhook URL is configured, SDK polling may not receive messages.
- If group full-message monitoring is off, the Bot may only receive messages that mention it.
- Webhook callbacks should verify the `X-API-KEY` header against `DEBOX_WEBHOOK_KEY`.

## Redirect URI Issues

For DeBox authorization flows, use HTTPS redirect URIs and encode special characters with `encodeURIComponent` when building URLs.
```

- [ ] **Step 6: Scan all references**

Run:

```bash
rg -n "T[B]D|T[O]DO|debox[-]agent|DEBOX[_]AGENT|private key.*provide|mnemonic.*provide" debox
```

Expected: no output and exit code `1`.

- [ ] **Step 7: Commit integration and safety references**

Run:

```bash
git add debox/references/bot-registration.md debox/references/miniapp.md debox/references/chatwidget.md debox/references/shares-safety.md debox/references/troubleshooting.md
git commit -m "Add debox integration and safety references"
```

Expected: commit succeeds.

---

### Task 6: Add Skill Consistency Checks

**Files:**
- Create: `tests/test_skill_content.sh`
- Test: `tests/test_skill_content.sh`

- [ ] **Step 1: Write content consistency tests**

Create `tests/test_skill_content.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file: $path"
}

assert_contains() {
  local path="$1"
  local text="$2"
  grep -Fq "$text" "$path" || fail "expected $path to contain: $text"
}

assert_not_contains_repo() {
  local pattern="$1"
  if rg -n "$pattern" debox docs/superpowers/plans/2026-04-29-debox-skill.md; then
    fail "unexpected pattern found: $pattern"
  fi
}

assert_file "debox/SKILL.md"
assert_file "debox/scripts/debox.sh"
assert_file "debox/references/credentials.md"
assert_file "debox/references/messaging.md"
assert_file "debox/references/bot-registration.md"
assert_file "debox/references/miniapp.md"
assert_file "debox/references/chatwidget.md"
assert_file "debox/references/shares-safety.md"
assert_file "debox/references/troubleshooting.md"

assert_contains "debox/SKILL.md" "name: debox skill"
assert_contains "debox/SKILL.md" "debox/scripts/debox.sh <command> --json"
assert_contains "debox/references/credentials.md" "DEBOX_API_KEY"
assert_contains "debox/references/messaging.md" "message send-group"
assert_contains "debox/references/shares-safety.md" "Treat these tasks as high risk"

assert_not_contains_repo "T[B]D|T[O]DO|debox[-]agent|DEBOX[_]AGENT"

echo "PASS: debox skill content checks"
```

- [ ] **Step 2: Make content tests executable**

Run:

```bash
chmod +x tests/test_skill_content.sh
```

Expected: command exits `0`.

- [ ] **Step 3: Run content tests**

Run:

```bash
tests/test_skill_content.sh
```

Expected output:

```text
PASS: debox skill content checks
```

- [ ] **Step 4: Run wrapper tests again**

Run:

```bash
tests/test_debox_wrapper.sh
```

Expected output:

```text
PASS: debox wrapper tests
```

- [ ] **Step 5: Commit content checks**

Run:

```bash
git add tests/test_skill_content.sh
git commit -m "test: add debox skill content checks"
```

Expected: commit succeeds.

---

### Task 7: Final Verification and Documentation Review

**Files:**
- Modify: `docs/superpowers/plans/2026-04-29-debox-skill.md`

- [ ] **Step 1: Run full verification**

Run:

```bash
tests/test_debox_wrapper.sh
tests/test_skill_content.sh
git status --short
```

Expected output includes:

```text
PASS: debox wrapper tests
PASS: debox skill content checks
```

Expected `git status --short`: only this plan file may be modified if task checkboxes were updated.

- [ ] **Step 2: Review skill routing for scope drift**

Run:

```bash
rg -n "runtime|polling|webhook server|transfer|Swap|signing|Shares" debox/SKILL.md debox/references
```

Expected: matches are only in scope boundaries, safety rules, or troubleshooting notes. There should be no instruction to implement Bot runtime or execute asset-moving actions.

- [ ] **Step 3: Review wrapper for secret leakage**

Run:

```bash
rg -n "DEBOX_API_KEY|DEBOX_APP_SECRET|DEBOX_WEBHOOK_KEY|echo|printf" debox/scripts/debox.sh debox/references
```

Expected: references explain environment variables, and wrapper output does not print credential values.

- [ ] **Step 4: Commit final plan checkbox updates if any**

If this plan file was updated during execution, run:

```bash
git add docs/superpowers/plans/2026-04-29-debox-skill.md
git commit -m "docs: update debox skill implementation plan progress"
```

Expected: commit succeeds if there are plan changes. If there are no plan changes, skip this step.

---

## Self-Review

Spec coverage:

- Skill directory and `SKILL.md`: Task 1.
- `scripts/debox.sh` wrapper: Tasks 2 and 3.
- Concise reference files: Tasks 4 and 5.
- Wrapper tests for OS/arch, cache, checksum, unsupported platforms, and argument preservation: Tasks 2 and 3.
- CLI contract is represented by wrapper invocation and documented command surface in `SKILL.md` and references.
- Credentials and safety boundaries: Tasks 1, 4, 5, and 6.
- Non-goals around Bot runtime and asset execution: Tasks 1, 5, and 7.

Placeholder scan:

- The plan contains no unresolved placeholders and no forbidden legacy command names.
- The only external release URL chosen is a concrete default: `https://github.com/debox-pro/debox-cli/releases/download`.

Type and name consistency:

- Skill-facing wrapper path is consistently `debox/scripts/debox.sh`.
- Environment variables are consistently `DEBOX_SKILL_*` for wrapper bootstrap and `DEBOX_*` for DeBox credentials.
- JSON error shape uses `ok`, `action`, and `error.code/message/hint`.
