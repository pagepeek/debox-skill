#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

required_files=(
  "debox-http/SKILL.md"
  "debox-http/references/auth-http.md"
  "debox-http/references/message-http.md"
  "debox-http/references/webhook-http.md"
)

for path in "${required_files[@]}"; do
  [[ -f "$ROOT_DIR/$path" ]] || fail "missing required file: $path"
done

grep -Fqx -- "name: debox-http" "$ROOT_DIR/debox-http/SKILL.md" || fail "wrong skill name"

if grep -RInE -- 'debox/scripts/debox\.sh|curl|bash|```bash|download|binary|executable|SDKs|local scripts|shell commands' "$ROOT_DIR/debox-http" | grep -Ev "Do not use|without|Do not show|Do not generate"; then
  fail "debox-http should not depend on CLI, binaries, or SDK execution"
fi

grep -Fq "bot/getUpdates" "$ROOT_DIR/debox-http/references/message-http.md" || fail "missing receive messages endpoint"
grep -Fq "bot/sendMessage" "$ROOT_DIR/debox-http/references/message-http.md" || fail "missing bot send endpoint"
grep -Fq "messages/group/send" "$ROOT_DIR/debox-http/references/message-http.md" || fail "missing OpenPlatform group send endpoint"
grep -Fq "signature = lowercase_hex_sha1" "$ROOT_DIR/debox-http/references/auth-http.md" || fail "missing signature rule"
grep -Fq "X-API-KEY" "$ROOT_DIR/debox-http/references/webhook-http.md" || fail "missing webhook header verification"

echo "PASS: debox-http skill content checks"
