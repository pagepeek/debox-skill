#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file_exists() {
  local path="$1"
  [[ -f "$ROOT_DIR/$path" ]] || fail "expected file to exist: $path"
}

assert_executable() {
  local path="$1"
  [[ -x "$ROOT_DIR/$path" ]] || fail "expected file to be executable: $path"
}

assert_contains_literal() {
  local path="$1"
  local expected="$2"
  grep -Fqx -- "$expected" "$ROOT_DIR/$path" || fail "expected $path to contain line: $expected"
}

assert_not_contains_regex() {
  local description="$1"
  local pattern="$2"
  shift 2

  local output
  set +e
  output="$(grep -RInE -- "$pattern" "$@" 2>/dev/null)"
  local status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    fail "$description found forbidden content:
$output"
  fi
  [[ "$status" -eq 1 ]] || fail "$description scan failed"
}

required_files=(
  "debox/SKILL.md"
  "debox/scripts/debox.sh"
  "debox/references/credentials.md"
  "debox/references/messaging.md"
  "debox/references/bot-registration.md"
  "debox/references/miniapp.md"
  "debox/references/chatwidget.md"
  "debox/references/shares-safety.md"
  "debox/references/troubleshooting.md"
)

for required_file in "${required_files[@]}"; do
  assert_file_exists "$required_file"
done

assert_contains_literal "debox/SKILL.md" "name: debox"
if grep -Fqx -- "name: debox-skill" "$ROOT_DIR/debox/SKILL.md" || grep -Fqx -- "name: debox skill" "$ROOT_DIR/debox/SKILL.md"; then
  fail "debox/SKILL.md uses stale frontmatter name"
fi

assert_executable "debox/scripts/debox.sh"

skill_facing_paths=(
  "$ROOT_DIR/debox/SKILL.md"
  "$ROOT_DIR/debox/scripts/debox.sh"
  "$ROOT_DIR/debox/references"
  "$ROOT_DIR/docs/superpowers/specs/2026-04-29-debox-skill-design.md"
  "$ROOT_DIR/docs/superpowers/plans/2026-04-29-debox-skill.md"
)

assert_not_contains_regex "placeholder TBD" "[Tt][Bb][Dd]" "${skill_facing_paths[@]}"
assert_not_contains_regex "placeholder TODO" "[Tt][Oo][Dd][Oo]" "${skill_facing_paths[@]}"
assert_not_contains_regex "stale debox-agent name" "debox[-]agent" "${skill_facing_paths[@]}"
assert_not_contains_regex "stale DEBOX_AGENT variable" "DEBOX[_]AGENT" "${skill_facing_paths[@]}"
assert_not_contains_regex "stale curl error code" "CURL[_]NOT[_]FOUND" "${skill_facing_paths[@]}"
assert_not_contains_regex "stale sha256 error code" "SHA256[_]TOOL[_]NOT[_]FOUND" "${skill_facing_paths[@]}"
assert_not_contains_regex "unsafe transaction-executing phrasing" "transaction[-]executing" "${skill_facing_paths[@]}"
assert_not_contains_regex "unsafe signatures and transactions phrasing" "signatures, and transactions" "${skill_facing_paths[@]}"
assert_not_contains_regex "unsafe confirmation exception phrasing" "unless explicitly requested" "${skill_facing_paths[@]}"

asset_scope_paths=(
  "$ROOT_DIR/debox/SKILL.md"
  "$ROOT_DIR/debox/references"
  "$ROOT_DIR/docs/superpowers/specs/2026-04-29-debox-skill-design.md"
  "$ROOT_DIR/docs/superpowers/plans/2026-04-29-debox-skill.md"
)

asset_scope_files=()
while IFS= read -r -d '' asset_scope_file; do
  asset_scope_files+=("$asset_scope_file")
done < <(find "${asset_scope_paths[@]}" -type f -print0 | sort -z)

asset_moving_claims="$(
  awk '
    BEGIN { bad = 0 }
    {
      line = tolower($0)
      has_confirmation = line ~ /(after|with|upon|once)[^[:cntrl:]]*(explicit )?(user )?confirm/
      has_action = line ~ /(broadcast|sign|send|execute|call swap|enable real allowance|asset-moving|transaction)/
      is_safe_boundary = line ~ /(does not|do not|no |outside|only|placeholder|dry-run|review|explain|conceptual)/
      if (has_confirmation && has_action && !is_safe_boundary) {
        printf "%s:%d:%s\n", FILENAME, FNR, $0
        bad = 1
      }
    }
    END { exit bad }
  ' "${asset_scope_files[@]}"
)" || fail "docs claim real asset-moving/signing actions can execute after confirmation:
$asset_moving_claims"

wrapper="$ROOT_DIR/debox/scripts/debox.sh"
troubleshooting="$ROOT_DIR/debox/references/troubleshooting.md"

wrapper_error_codes=()
while IFS= read -r code; do
  wrapper_error_codes+=("$code")
done < <(grep -oE '"[A-Z0-9_]+(_FAILED|_NOT_FOUND|_MISMATCH|_INVALID|_SET|_PLATFORM)|"MISSING_[A-Z0-9_]+"' "$wrapper" | tr -d '"' | grep -v '^DEBOX_' | sort -u)

for code in "${wrapper_error_codes[@]}"; do
  grep -Fq -- "$code" "$troubleshooting" || fail "troubleshooting is missing error code: $code"
done

echo "PASS: debox skill content checks"
