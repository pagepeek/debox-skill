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
  "debox-http/references/channel-integration.md"
  "debox-http/references/message-http.md"
  "debox-http/references/setup-for-developers.md"
  "debox-http/references/webhook-http.md"
)

for path in "${required_files[@]}"; do
  [[ -f "$ROOT_DIR/$path" ]] || fail "missing required file: $path"
done

grep -Fqx -- "name: debox-http" "$ROOT_DIR/debox-http/SKILL.md" || fail "wrong skill name"
grep -Fq "DeBox developer" "$ROOT_DIR/debox-http/SKILL.md" || fail "missing developer-oriented positioning"
grep -Fq "not an executable tool skill" "$ROOT_DIR/debox-http/SKILL.md" || fail "missing non-executable skill positioning"
grep -Fq "developer integration guide" "$ROOT_DIR/debox-http/SKILL.md" || fail "missing integration guide positioning"
grep -Fq "## Required Setup Gate" "$ROOT_DIR/debox-http/SKILL.md" || fail "missing required setup gate"
grep -Fq "Do not proceed to channel architecture or code" "$ROOT_DIR/debox-http/SKILL.md" || fail "missing setup-before-development rule"
grep -Fq "copy-paste setup flow" "$ROOT_DIR/debox-http/SKILL.md" || fail "missing copy-paste setup gate"
grep -Fq "## Setup Gate" "$ROOT_DIR/debox-http/references/channel-integration.md" || fail "missing channel integration setup gate"
grep -Fq "If any item is not ready, do not design code yet" "$ROOT_DIR/debox-http/references/channel-integration.md" || fail "missing channel setup gating rule"
grep -Fq "## Install This Skill" "$ROOT_DIR/debox-http/SKILL.md" || fail "missing install section"
grep -Fq "~/.claude/skills/debox-http/SKILL.md" "$ROOT_DIR/debox-http/SKILL.md" || fail "missing Claude Code install path"
grep -Fq "https://raw.githubusercontent.com/pagepeek/debox-skill/main/debox-http/SKILL.md" "$ROOT_DIR/debox-http/SKILL.md" || fail "missing skill entry URL"
grep -Fq "https://raw.githubusercontent.com/pagepeek/debox-skill/main/debox-http/references/channel-integration.md" "$ROOT_DIR/debox-http/SKILL.md" || fail "missing channel integration URL"
grep -Fq "https://raw.githubusercontent.com/pagepeek/debox-skill/main/debox-http/references/setup-for-developers.md" "$ROOT_DIR/debox-http/SKILL.md" || fail "missing developer setup URL"
grep -Fq "Assume the user may know nothing except how to paste DeBox values into chat" "$ROOT_DIR/debox-http/SKILL.md" || fail "missing non-technical user setup rule"
grep -Fq "## Copy-Paste Prompt" "$ROOT_DIR/debox-http/references/setup-for-developers.md" || fail "missing copy-paste prompt"
grep -Fq "Ask the user to paste the DeBox values they can see" "$ROOT_DIR/debox-http/references/setup-for-developers.md" || fail "missing paste-values rule"
grep -Fq "Accept messy pasted text" "$ROOT_DIR/debox-http/references/setup-for-developers.md" || fail "missing messy paste handling"
grep -Fq "Minimum local env content" "$ROOT_DIR/debox-http/references/setup-for-developers.md" || fail "missing local env guidance"
grep -Fq "API Key obtained from UI or user and stored by agent" "$ROOT_DIR/debox-http/references/setup-for-developers.md" || fail "missing API key setup checklist"
grep -Fq "Webhook Key obtained from UI or user and stored by agent" "$ROOT_DIR/debox-http/references/setup-for-developers.md" || fail "missing webhook key setup checklist"
grep -Fq "Do not hard-code real DeBox keys into source code or commit them to git" "$ROOT_DIR/debox-http/references/setup-for-developers.md" || fail "missing no hard-coded real secrets rule"
grep -Fq "https://developer.debox.pro" "$ROOT_DIR/debox-http/references/setup-for-developers.md" || fail "missing developer platform setup"
grep -Fq "The developer platform page alone may not provide enough context" "$ROOT_DIR/debox-http/references/setup-for-developers.md" || fail "missing platform insufficiency warning"
grep -Fq "Do not invent API keys" "$ROOT_DIR/debox-http/references/setup-for-developers.md" || fail "missing no-invented-credentials rule"

if grep -RInE -- 'debox/scripts/debox\.sh|curl|bash|```bash|download|binary|executable|SDKs|local scripts|shell commands' "$ROOT_DIR/debox-http" | grep -Ev "Do not use|without|Do not show|Do not generate"; then
  fail "debox-http should not depend on CLI, binaries, or SDK execution"
fi

grep -Fq "bot/getUpdates" "$ROOT_DIR/debox-http/references/message-http.md" || fail "missing receive messages endpoint"
grep -Fq "bot/sendMessage" "$ROOT_DIR/debox-http/references/message-http.md" || fail "missing bot send endpoint"
grep -Fq "ingest_webhook(http_request)" "$ROOT_DIR/debox-http/references/channel-integration.md" || fail "missing channel webhook contract"
grep -Fq "send(channel_message)" "$ROOT_DIR/debox-http/references/channel-integration.md" || fail "missing channel send contract"
grep -Fq "provider_update_id" "$ROOT_DIR/debox-http/references/channel-integration.md" || fail "missing channel update mapping"
grep -Fq "Webhook URL" "$ROOT_DIR/debox-http/references/channel-integration.md" || fail "missing webhook channel setup"
grep -Fq "messages/group/send" "$ROOT_DIR/debox-http/references/message-http.md" || fail "missing OpenPlatform group send endpoint"
grep -Fq "signature = lowercase_hex_sha1" "$ROOT_DIR/debox-http/references/auth-http.md" || fail "missing signature rule"
grep -Fq "X-API-KEY" "$ROOT_DIR/debox-http/references/webhook-http.md" || fail "missing webhook header verification"

echo "PASS: debox-http skill content checks"
