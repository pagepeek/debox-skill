---
name: debox-http
description: Use when a DeBox developer is designing or implementing HTTP-based DeBox messaging, webhook, bot, or agent channel integrations.
---

# debox-http

Use this skill as a developer integration guide for DeBox HTTP messaging, webhook callbacks, bot send/receive flows, and agent channel adapters.

This is not an executable tool skill and it does not provide a runtime. Do not use shell commands, curl, local scripts, downloaded binaries, SDK execution, or long-running local processes as part of this skill. Express integrations as HTTP contracts, channel contracts, credential requirements, and implementation acceptance criteria.

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
~/.claude/skills/debox-http/references/setup-for-developers.md
~/.claude/skills/debox-http/references/webhook-http.md
```

Canonical source URLs:

```text
https://raw.githubusercontent.com/pagepeek/debox-skill/main/debox-http/SKILL.md
https://raw.githubusercontent.com/pagepeek/debox-skill/main/debox-http/references/auth-http.md
https://raw.githubusercontent.com/pagepeek/debox-skill/main/debox-http/references/channel-integration.md
https://raw.githubusercontent.com/pagepeek/debox-skill/main/debox-http/references/message-http.md
https://raw.githubusercontent.com/pagepeek/debox-skill/main/debox-http/references/setup-for-developers.md
https://raw.githubusercontent.com/pagepeek/debox-skill/main/debox-http/references/webhook-http.md
```

After installation, ask the agent to use `debox-http` as a DeBox developer integration guide. For a human who is new to DeBox, read `references/setup-for-developers.md` first. For webhook channel development, read `references/channel-integration.md`.

## First Action

Classify the developer request:

- **New DeBox developer setup / API Key / Webhook Key / Webhook URL**: read `references/setup-for-developers.md`.
- **Receive messages / poll bot updates**: read `references/message-http.md` section `Receive Messages`.
- **Send a bot reply to a chat/user/group**: read `references/message-http.md` section `Bot Send Message`.
- **Integrate DeBox as an agent channel**: read `references/channel-integration.md`.
- **Send OpenPlatform group push message**: read `references/message-http.md` section `OpenPlatform Group Send`.
- **Webhook callback handling**: read `references/webhook-http.md`.
- **Credentials or signing**: read `references/auth-http.md`.

## Required Setup Gate

Before designing or implementing any DeBox webhook channel, first guide the human developer through `references/setup-for-developers.md` and collect a yes/no readiness checklist. Do not only send the developer to `https://developer.debox.pro`; use the setup reference and official Bot Guide links to explain what fields must exist and what to do if the page is incomplete. Do not proceed to channel architecture or code until the developer confirms:

```text
DeBox account registered: yes
Developer platform accessible: yes
API Key obtained and stored server-side: yes
App Domain configured: yes
Webhook URL configured or planned for a public HTTPS endpoint: yes
Webhook Key obtained and stored server-side, or waiting for Webhook URL activation: yes
Monitor group message setting chosen intentionally: yes
```

If any item is not ready, keep the work in setup mode. Explain the missing step and avoid implementation details beyond what is needed to complete setup.

## Required Credentials

Use the host application's secret store or user-provided secret references. Never ask for private keys, mnemonics, or seed phrases.

- `DEBOX_API_KEY`: required for all HTTP requests.
- `DEBOX_API_SECRET`: required for bot polling and bot send endpoints that need `nonce`, `timestamp`, and `signature` headers.
- `DEBOX_APP_ID`: used by some OpenPlatform endpoints.
- `DEBOX_WEBHOOK_KEY`: only for validating webhook callbacks.
- `DEBOX_OPENAPI_BASE_URL`: default `https://open.debox.pro`.

## HTTP Rules

- Keep secrets in headers or the host secret store, not in URLs, logs, command text, frontend code, or committed files.
- Describe requests as structured HTTP objects or host integration contracts. Do not generate curl, bash, Python, Go, SDK, or local executable snippets.
- Use `POST` for message sending and SDK-derived bot update polling.
- For signed bot endpoints, if the HTTP-only environment cannot compute `sha1(secret + nonce + timestamp)`, ask the user or a trusted backend to provide `nonce`, `timestamp`, and `signature`; do not invent signatures.
- For bot polling, remember DeBox retains unread polling messages only briefly, about 1 minute; poll frequently or use webhook callbacks.
- If a webhook URL is configured in the DeBox bot panel, SDK-style polling may not receive messages because callbacks go to the webhook first.
- To receive group messages, the bot must be in the group; enable group message monitoring only when needed. Without it, the bot may only receive mentions.

## Developer Guidance

When helping a developer implement DeBox integration, report:

- endpoint and operation, without secret values
- required request method, headers, body type, and body fields
- expected DeBox response `ok`, `code`, `message`, `result`, or `data`
- parsed fields such as `update.id`, `message.chat.id`, `message.chat.type`, `message.text`, or returned `message_id`
- host-side responsibilities such as webhook validation, deduplication, secret storage, retry policy, and tests

For implementation failures, do not suggest blind retries. Check credentials, Bot webhook-vs-polling configuration, target IDs, DeBox API error messages, and the host's channel routing state.
