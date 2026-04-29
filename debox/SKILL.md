---
name: debox-skill
description: Use when an agent needs DeBox OpenPlatform help for safe one-shot community operations such as group/private messages, credential checks, group ID parsing, Bot registration guidance, MiniApp guidance, ChatWidget embedding, or Shares safety review.
---

# debox skill

Use this skill to help an agent use DeBox as a community action surface without hand-writing DeBox API requests.

## Scope

This skill supports:

- Sending DeBox group and private messages through `debox/scripts/debox.sh`.
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

- **One-shot message or lookup**: use `debox/scripts/debox.sh` and include `--json`.
- **Credentials or setup**: read `references/credentials.md`.
- **Group/private messaging**: read `references/messaging.md`.
- **Bot registration**: read `references/bot-registration.md`.
- **Webhook verification**: pipe the received header value to `debox/scripts/debox.sh webhook verify --header-api-key-stdin --json`; never pass header values as CLI arguments.
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

Never ask for wallet private keys, mnemonics, or seed phrases. Never place DeBox secrets in command-line arguments, code snippets, logs, or frontend code. Webhook verification must use `webhook verify --header-api-key-stdin --json`; avoid placing header values in shell history or logs.

## Required Output Handling

For agent-initiated commands, include `--json` and trust the exit code:

- Exit code `0` means the JSON must contain `"ok": true`.
- Non-zero exit means the JSON must contain `"ok": false` and an `error.hint`.

Report success with the DeBox target and returned identifier. Report failure with the CLI's structured hint.
