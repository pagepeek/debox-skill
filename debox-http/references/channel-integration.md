# DeBox Channel Integration

Use this reference when any agent host needs to treat DeBox as a messaging channel. This document is platform-neutral: map the contracts below onto the host's own channel, webhook, queue, or tool interfaces.

Do not assume a specific agent runtime, framework, repository layout, or programming language.

## Setup Gate

Before channel design or implementation, complete the human setup flow in `setup-for-developers.md`.

Required readiness confirmation:

```text
DeBox account registered: yes
Developer platform accessible: yes
API Key obtained and stored server-side: yes
App Domain configured: yes
Webhook URL configured or planned for a public HTTPS endpoint: yes
Webhook Key obtained and stored server-side, or waiting for Webhook URL activation: yes
Monitor group message setting chosen intentionally: yes
```

If any item is not ready, do not design code yet. Stay in setup mode and help the human developer finish DeBox platform configuration first.

## Channel Model

Represent DeBox as one channel adapter with two host-facing operations:

```text
ingest_webhook(http_request) -> inbound_message
send(channel_message) -> provider_result
```

Webhook is the preferred channel mode. DeBox pushes updates to the host runtime; the host validates and normalizes them; the agent receives normalized channel messages. The model process should not expose a public webhook server by itself.

## Adapter Boundary

Keep DeBox-specific logic in the channel adapter, not in the model prompt:

- credential lookup
- webhook header validation
- DeBox update parsing
- deduplication
- DeBox request signing
- outbound `bot/sendMessage` HTTP calls
- provider-specific error mapping

The agent should see a stable, provider-neutral inbound message and should send a stable, provider-neutral outbound reply.

## Channel State

Persist this state outside the model context when possible:

```json
{
  "provider": "debox",
  "mode": "webhook",
  "base_url": "https://open.debox.pro",
  "bot_identity": "<bot-or-account-id>",
  "seen_update_ids": [],
  "seen_message_ids": [],
  "last_received_at": null,
  "last_sent_at": null
}
```

State rules:

- Store state per bot identity, not globally across all DeBox bots.
- Deduplicate by `update.id`; use `message.message_id` as a secondary key when available.
- Use a bounded durable store or TTL cache for dedupe keys. Do not rely on model memory.
- Persist enough routing state to reply to the same DeBox conversation.

## Channel Message Shape

Use this provider-neutral inbound shape internally. Rename fields only if the host already has a channel schema.

```json
{
  "provider": "debox",
  "provider_message_id": "msg-id",
  "provider_update_id": "123",
  "conversation_id": "chat-id",
  "conversation_type": "group",
  "reply_target": "group:chat-id",
  "sender_id": "user-id",
  "sender_name": "name",
  "text": "hello",
  "raw": {}
}
```

Target rules:

- `reply_target` should include both DeBox chat type and chat id because outbound sending needs both values.
- Recommended format: `<chat_type>:<chat_id>`, for example `group:fxi3hqo5` or `private:uvg2p6ho`.
- If the host has structured targets, store `{ "chat_type": "...", "chat_id": "..." }` instead of a string.
- Validate outbound targets before sending; reject targets without both chat type and chat id.

## Ingest Webhook Operation

Configure the DeBox Bot Webhook URL to point at the host runtime's DeBox channel endpoint. The endpoint receives DeBox callbacks and validates the `X-API-KEY` request header against `DEBOX_WEBHOOK_KEY`.

Host webhook endpoint shape, expressed generically:

```yaml
method: POST
url: https://<host-runtime>/<debox-webhook-path>
headers:
  X-API-KEY: <webhook header from DeBox>
body_type: json
```

Validation rules:

- Reject missing or mismatched `X-API-KEY`.
- Do not log the received header or `DEBOX_WEBHOOK_KEY`.
- Parse the JSON body only after header validation.
- Deduplicate before invoking the agent.
- Return a successful HTTP status after accepting or ignoring a duplicate update.

Expected DeBox Chat Bot webhook body shape:

```json
{
  "from_user_id": "sender-debox-id",
  "to_user_id": "bot-debox-id",
  "language": "en",
  "group_id": "group-id-or-empty",
  "message": "message without bot mention",
  "mention_users": "mentioned-users",
  "message_raw": "complete raw message"
}
```

Compatibility rules:

- DeBox Chat Bot webhook callbacks may not include a provider message id. Generate an internal provider message id from a host event id or a stable hash of the callback body.
- When `group_id` is non-empty, set `conversation_type` to `group` and `conversation_id` to `group_id`.
- When `group_id` is empty, set `conversation_type` to `private` and choose the reply conversation id from the host's DeBox private-chat send contract.
- Accept only text messages for the first implementation unless the host explicitly supports media or callbacks.
- Preserve the raw DeBox update in a debug-safe field or state record, but never include secrets.

Map the webhook body into the channel message shape:

```json
{
  "provider": "debox",
  "provider_message_id": "host-generated-id",
  "provider_update_id": "host-generated-id",
  "conversation_id": "group-id",
  "conversation_type": "group",
  "reply_target": "group:group-id",
  "sender_id": "sender-debox-id",
  "sender_name": null,
  "text": "message without bot mention",
  "raw": {}
}
```

Filtering rules:

- Ignore webhook updates without `message` unless the agent explicitly handles callbacks or media.
- Deduplicate by `provider_update_id`; use `provider_message_id` as a secondary key.
- If the bot should only respond to mentions, check whether `message.text` contains the bot display name.
- Pass normalized messages to the agent only after validation and deduplication.

## Polling Fallback

Use polling only for development, manual testing, or short-lived agent sessions where no Webhook URL is configured.

Polling request:

```yaml
method: POST
url: https://open.debox.pro/openapi/bot/getUpdates
headers:
  Content-Type: application/x-www-form-urlencoded
  X-API-KEY: <DEBOX_API_KEY>
  nonce: <random decimal string>
  timestamp: <unix seconds>
  signature: <lowercase hex sha1(DEBOX_API_SECRET + nonce + timestamp)>
body_type: form
body:
  offset: "<last_update_id_plus_1>"
  limit: "20"
  timeout: "30"
```

Polling limitations:

- DeBox polling messages are retained only briefly, about 1 minute.
- If a Webhook URL is configured in the DeBox bot panel, polling may return no messages.
- Do not use polling as the primary production channel mode.

## Send Operation

Use the bot send endpoint for replies to synced messages.

Outbound channel message shape:

```json
{
  "provider": "debox",
  "reply_target": "group:chat-id",
  "conversation_id": "chat-id",
  "conversation_type": "group",
  "text": "reply text"
}
```

HTTP request:

```yaml
method: POST
url: https://open.debox.pro/openapi/bot/sendMessage
headers:
  Content-Type: application/x-www-form-urlencoded
  X-API-KEY: <DEBOX_API_KEY>
  nonce: <random decimal string>
  timestamp: <unix seconds>
  signature: <lowercase hex sha1(DEBOX_API_SECRET + nonce + timestamp)>
body_type: form
body:
  chat_id: "<channel_message.conversation_id>"
  chat_type: "<channel_message.conversation_type>"
  text: "<reply text>"
```

Response shape:

```json
{
  "ok": true,
  "result": {
    "message_id": "sent-message-id"
  }
}
```

Signing rule:

```text
signature = lowercase_hex_sha1(DEBOX_API_SECRET + nonce + timestamp)
```

Use a fresh random `nonce` and Unix-seconds `timestamp` for each signed bot request. Keep `DEBOX_API_SECRET` in the host secret store.

Return this provider result to the host:

```json
{
  "provider": "debox",
  "ok": true,
  "conversation_id": "chat-id",
  "provider_message_id": "sent-message-id",
  "raw": {}
}
```

Outbound rules:

- Send only text in the first implementation unless the host explicitly supports richer DeBox payloads.
- Do not retry repeatedly on provider errors. Surface the DeBox error code/message to the host.
- If the host supports tracked sends, return the DeBox `message_id` as the provider message id.

## Channel Flow

```text
DeBox webhook -> host validation -> normalized channel message -> agent -> bot/sendMessage
```

## Error Handling

- On HTTP 401/403: stop and ask the user to check `DEBOX_API_KEY`, `DEBOX_API_SECRET`, and bot permissions.
- On missing inbound messages: check webhook URL configuration, webhook header validation, group monitoring settings, and whether the bot only receives mentions.
- On send failure: report the DeBox error message and do not retry repeatedly.
- Never include secret header values in error reports.

## Development Acceptance Criteria

A DeBox channel implementation should pass these checks before production use:

- Missing `X-API-KEY` is rejected.
- Mismatched `X-API-KEY` is rejected before parsing or processing the body.
- Accepted text webhook updates normalize into the channel message shape above.
- Non-text updates are ignored or mapped according to an explicit media/callback design.
- Duplicate `update.id` values do not invoke the agent twice.
- Missing `message.message_id` does not crash ingestion.
- Outbound sends reject invalid targets that lack chat type or chat id.
- Outbound sends call `POST /openapi/bot/sendMessage` with form fields `chat_id`, `chat_type`, and `text`.
- Signed requests include `X-API-KEY`, `nonce`, `timestamp`, and `signature`.
- Tests verify the SHA-1 signature with fixed secret, nonce, and timestamp.
- Logs and errors never include `DEBOX_API_KEY`, `DEBOX_API_SECRET`, `DEBOX_WEBHOOK_KEY`, signatures, or webhook header values.

## Minimal Channel Contract

A host integrating DeBox as a channel should provide:

- secret lookup for `DEBOX_API_KEY`, `DEBOX_API_SECRET`, and optionally `DEBOX_WEBHOOK_KEY`
- a public HTTPS webhook endpoint for DeBox callbacks
- webhook header validation before agent invocation
- SHA-1 signature generation for signed bot endpoints
- an HTTP request tool that supports form bodies and custom headers
- deduplication keyed by DeBox update id
- a provider-neutral inbound message contract
- a provider-neutral outbound reply contract
