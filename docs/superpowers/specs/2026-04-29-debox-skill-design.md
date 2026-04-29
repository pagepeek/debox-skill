# debox skill Design

## Purpose

`debox skill` helps an agent use DeBox as a reliable community action surface without making the agent hand-write DeBox API requests. The first version focuses on one-shot OpenPlatform operations and integration guidance. It deliberately excludes Bot runtime, long polling, webhook servers, session state, scheduled jobs, and chain transaction execution.

The skill should let an agent safely perform or guide these tasks:

- Send a DeBox group message.
- Send a DeBox private message.
- Parse and validate a DeBox group ID from an invite URL.
- Query group and user information when the CLI supports it.
- Check local credential and CLI readiness.
- Route MiniApp, ChatWidget, Shares, and Bot registration questions to concise references.
- Refuse or require explicit confirmation for asset-moving or signing-related flows.

## Repository Shape

The repository is a standalone git repository for the skill source.

```text
debox-skill/
├── debox/
│   ├── SKILL.md
│   ├── scripts/
│   │   └── debox.sh
│   └── references/
│       ├── credentials.md
│       ├── messaging.md
│       ├── bot-registration.md
│       ├── miniapp.md
│       ├── chatwidget.md
│       ├── shares-safety.md
│       └── troubleshooting.md
└── docs/
    └── superpowers/
        └── specs/
            └── 2026-04-29-debox-skill-design.md
```

The skill directory is named `debox`. The human-facing skill name is `debox skill`. No command, directory, or binary is named `debox-agent`.

## Core Design

`SKILL.md` is a small routing layer. It tells the agent to classify the user's request and choose the correct reference or executable path. It should not embed the full DeBox documentation.

For executable actions, the agent uses:

```bash
debox/scripts/debox.sh <command> --json
```

`debox.sh` is the only stable execution entrypoint exposed by the skill. It bootstraps and invokes a compiled DeBox CLI. The underlying binary name can be `debox`, `debox-cli`, or another release artifact, but the skill-facing command remains `debox/scripts/debox.sh`.

## Wrapper Behavior

`debox/scripts/debox.sh` must:

1. Detect operating system and CPU architecture.
2. Resolve the requested CLI version.
3. Check a local cache for the matching binary.
4. Download the binary if missing.
5. Download and verify checksums.
6. Mark the binary executable.
7. `exec` the binary with the original arguments.

Supported platforms for v1:

- `darwin-arm64`
- `darwin-amd64`
- `linux-arm64`
- `linux-amd64`

Default cache layout:

```text
~/.cache/debox-skill/
├── bin/
│   └── debox-<version>-<os>-<arch>
└── checksums/
    └── checksums-<version>.txt
```

Configuration environment variables:

```bash
DEBOX_SKILL_CLI_VERSION=0.1.0
DEBOX_SKILL_CLI_BASE_URL=https://github.com/<org>/<repo>/releases/download
DEBOX_SKILL_CACHE_DIR=~/.cache/debox-skill
DEBOX_SKILL_SKIP_CHECKSUM=0
```

Checksum verification is required by default. `DEBOX_SKILL_SKIP_CHECKSUM=1` is allowed only for local development or private test releases, and the skill must warn that this weakens supply-chain safety.

If the user passes `--json`, wrapper bootstrap failures should also emit JSON:

```json
{
  "ok": false,
  "action": "bootstrap",
  "error": {
    "code": "CLI_DOWNLOAD_FAILED",
    "message": "Failed to download the DeBox CLI binary.",
    "hint": "Check network access or set DEBOX_SKILL_CLI_BASE_URL."
  }
}
```

## CLI Contract

The compiled CLI is responsible for API calls, validation, JSON formatting, error mapping, and credential loading.

Minimum v1 command surface:

```bash
debox.sh env check --json

debox.sh group parse-id \
  --url "https://m.debox.pro/group?id=fxi3hqo5" \
  --json

debox.sh message send-group \
  --group-id fxi3hqo5 \
  --type text \
  --content "hello" \
  --json

debox.sh message send-private \
  --user-id uvg2p6ho \
  --type text \
  --content "hello" \
  --json

debox.sh group info \
  --group-id fxi3hqo5 \
  --json

debox.sh user info \
  --user-id uvg2p6ho \
  --json

debox.sh webhook verify \
  --header-api-key "<value-from-request-header>" \
  --json
```

All agent-initiated calls should include `--json`. The CLI should return exit code `0` only when `ok: true`.

Successful output shape:

```json
{
  "ok": true,
  "action": "message.send_group",
  "data": {
    "group_id": "fxi3hqo5",
    "message_id": "..."
  }
}
```

Failure output shape:

```json
{
  "ok": false,
  "action": "message.send_group",
  "error": {
    "code": "-2004",
    "message": "Parameter invalid",
    "hint": "Check group_id, message type, and required content fields."
  }
}
```

## Credentials

The skill and CLI must use environment variables for credentials. The agent must not pass DeBox secrets as CLI arguments unless the command is specifically designed for verifying a received webhook header value.

Credential variables:

```bash
DEBOX_API_KEY=
DEBOX_APP_ID=
DEBOX_APP_SECRET=
DEBOX_WEBHOOK_KEY=
```

Rules:

- Message send commands require `DEBOX_API_KEY`.
- Sensitive payment, transfer, and point-related APIs require `DEBOX_APP_SECRET`, but those actions are outside v1 executable scope.
- Webhook verification compares the received request header against `DEBOX_WEBHOOK_KEY`.
- No flow should ask for wallet private keys or mnemonics.
- CLI JSON output must never echo full credential values.

## Agent Workflow

For a group message request:

1. Run `debox/scripts/debox.sh env check --json`.
2. Ensure a `group_id` exists. If the user provides an invite URL, run `group parse-id`.
3. Run `message send-group --json`.
4. Report the resulting message ID or the structured error hint.

For a private message request:

1. Run `env check --json`.
2. Ensure `user_id` exists.
3. Run `message send-private --json`.
4. Report success or the structured error hint.

For Bot registration:

1. Do not attempt to register or control the user's wallet.
2. Guide the user through DeBox app registration and developer portal setup.
3. Explain which fields are needed: App ID, API Key, App Secret when relevant, App Domain, Webhook URL, and Webhook Key.
4. If the task only needs one-shot message sending, prefer CLI commands over runtime design.

For MiniApp or ChatWidget requests:

1. Load the matching reference file.
2. Provide integration steps and minimal examples.
3. Avoid exposing API keys or app secrets in frontend code.

For Shares, signing, transfer, Swap, or chain buttons:

1. Load `references/shares-safety.md`.
2. Treat the task as high risk.
3. Generate templates or explain parameters only by default.
4. Require explicit user confirmation before any real asset-moving action.

## References

The references keep `SKILL.md` small:

- `credentials.md`: where credentials come from, environment setup, redaction rules.
- `messaging.md`: group/private message operations, text/rich text types, group ID extraction.
- `bot-registration.md`: user-owned DeBox account setup, Open Platform Bot setup, webhook fields.
- `miniapp.md`: DeBox built-in browser detection, wallet injection, HTTPS/mobile requirements.
- `chatwidget.md`: HTML/React widget integration and conversation ID flow.
- `shares-safety.md`: safety policy for Shares, signing, transfer, Swap, and chain buttons.
- `troubleshooting.md`: common DeBox API errors, redirect URI issues, missing group/user IDs, CLI bootstrap failures.

## Explicit Non-Goals

V1 does not include:

- Long-running Bot runtime.
- `bot run`, polling loops, or webhook server processes.
- Local runtime event storage.
- Scheduling or background task queues.
- Automatic Shares integration.
- Real token transfer, Swap, signing, or asset movement.
- Grant application automation.
- Full MiniApp or ChatWidget project generation.

These can be added later without changing the first version's stable entrypoint.

## Testing Strategy

Wrapper tests:

- OS/arch mapping works for supported platforms.
- Unsupported platforms fail with a clear JSON error when `--json` is present.
- Cache hit avoids download.
- Missing binary triggers download.
- Checksum mismatch fails closed.
- Original CLI arguments are preserved.

CLI contract tests:

- `env check` reports missing credentials without leaking secrets.
- `group parse-id` extracts IDs from supported DeBox invite URLs.
- Message commands build the expected API payloads.
- Non-2xx and DeBox error codes map to structured JSON errors.

Skill behavior tests:

- For a send-message prompt, the agent chooses `debox/scripts/debox.sh`, not raw curl.
- For Bot registration, the agent asks the user to complete wallet-owned setup instead of requesting private keys.
- For chain/payment prompts, the agent treats the action as high risk and does not auto-execute.

## Approval Gate

After this spec is approved, the next step is to write an implementation plan for:

1. Creating the `debox/` skill directory.
2. Writing `SKILL.md`.
3. Writing `scripts/debox.sh`.
4. Writing concise reference files.
5. Defining or stubbing the external compiled CLI release contract.

