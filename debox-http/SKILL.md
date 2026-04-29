---
name: debox-http
description: Use when an agent only has an HTTP request tool and needs DeBox message receive/send workflows without shell, CLI binaries, SDK execution, or local scripts.
---

# debox-http

Use this skill for DeBox message workflows implemented with an HTTP request tool only. Do not use shell commands, curl, local scripts, downloaded binaries, SDK execution, or long-running local processes.

## Install This Skill

Install the whole `debox-http` skill directory, not only this entry file, because the detailed HTTP contracts live in `references/`.

For Claude Code, place files under:

```text
~/.claude/skills/debox-http/
```

Required files:

```text
~/.claude/skills/debox-http/SKILL.md
~/.claude/skills/debox-http/references/auth-http.md
~/.claude/skills/debox-http/references/channel-integration.md
~/.claude/skills/debox-http/references/message-http.md
~/.claude/skills/debox-http/references/webhook-http.md
```

Canonical source URLs:

```text
https://raw.githubusercontent.com/pagepeek/debox-skill/main/debox-http/SKILL.md
https://raw.githubusercontent.com/pagepeek/debox-skill/main/debox-http/references/auth-http.md
https://raw.githubusercontent.com/pagepeek/debox-skill/main/debox-http/references/channel-integration.md
https://raw.githubusercontent.com/pagepeek/debox-skill/main/debox-http/references/message-http.md
https://raw.githubusercontent.com/pagepeek/debox-skill/main/debox-http/references/webhook-http.md
```

After installation, ask the agent to use `debox-http` and read `references/channel-integration.md` when implementing a DeBox webhook channel.

## First Action

Classify the request:

- **Receive messages / poll bot updates**: read `references/message-http.md` section `Receive Messages`.
- **Send a bot reply to a chat/user/group**: read `references/message-http.md` section `Bot Send Message`.
- **Integrate DeBox as an agent channel**: read `references/channel-integration.md`.
- **Send OpenPlatform group push message**: read `references/message-http.md` section `OpenPlatform Group Send`.
- **Webhook callback handling**: read `references/webhook-http.md`.
- **Credentials or signing**: read `references/auth-http.md`.

## Required Credentials

Use the HTTP tool's secret store or user-provided secret references. Never ask for private keys, mnemonics, or seed phrases.

- `DEBOX_API_KEY`: required for all HTTP requests.
- `DEBOX_API_SECRET`: required for bot polling and bot send endpoints that need `nonce`, `timestamp`, and `signature` headers.
- `DEBOX_APP_ID`: used by some OpenPlatform endpoints.
- `DEBOX_WEBHOOK_KEY`: only for validating webhook callbacks.
- `DEBOX_OPENAPI_BASE_URL`: default `https://open.debox.pro`.

## HTTP Rules

- Keep secrets in headers or the HTTP tool's secret store, not in URLs, logs, command text, frontend code, or committed files.
- Use the HTTP tool's structured request object. Do not generate curl, bash, Python, Go, SDK, or local executable snippets.
- Use `POST` for message sending and SDK-derived bot update polling.
- For signed bot endpoints, if the HTTP-only environment cannot compute `sha1(secret + nonce + timestamp)`, ask the user or a trusted backend to provide `nonce`, `timestamp`, and `signature`; do not invent signatures.
- For bot polling, remember DeBox retains unread polling messages only briefly, about 1 minute; poll frequently or use webhook callbacks.
- If a webhook URL is configured in the DeBox bot panel, SDK-style polling may not receive messages because callbacks go to the webhook first.
- To receive group messages, the bot must be in the group; enable group message monitoring only when needed. Without it, the bot may only receive mentions.

## Output Handling

When making HTTP calls for a user, report:

- endpoint and operation, without secret values
- HTTP status
- DeBox response `ok`, `code`, `message`, `result`, or `data`
- parsed `update.id`, `message.chat.id`, `message.chat.type`, `message.text`, or returned `message_id` when present

If a request fails, do not retry blindly. Check credentials, Bot webhook-vs-polling configuration, target IDs, and DeBox API error message.
