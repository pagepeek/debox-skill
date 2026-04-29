# DeBox Channel Integration

Use this reference when a Claude-style agent needs to treat DeBox as a messaging channel using only an HTTP request tool.

## Channel Model

Represent DeBox as one channel adapter with two host-facing operations:

```text
ingest_webhook(http_request) -> inbound_message
send(channel_message) -> provider_result
```

Webhook is the preferred channel mode. DeBox pushes updates to the host runtime; the host validates and normalizes them; Claude receives normalized channel messages. The agent should not expose a public webhook server by itself.

## Channel State

Persist this state outside the model context when possible:

```json
{
  "provider": "debox",
  "mode": "webhook",
  "base_url": "https://open.debox.pro",
  "last_webhook_update_id": null,
  "last_received_at": null
}
```

State rules:

- Store state per bot identity, not globally across all DeBox bots.
- Deduplicate by `update.id`; use `message.message_id` as a secondary key.
- Store the latest accepted webhook update id in `last_webhook_update_id`.

## Ingest Webhook Operation

Configure the DeBox Bot Webhook URL to point at the host runtime's channel endpoint. The host endpoint receives DeBox callbacks and validates the `X-API-KEY` request header against `DEBOX_WEBHOOK_KEY`.

Host webhook endpoint shape:

```yaml
method: POST
url: https://<host-runtime>/channels/debox/webhook
headers:
  X-API-KEY: <webhook header from DeBox>
body_type: json
```

Validation rules:

- Reject missing or mismatched `X-API-KEY`.
- Do not log the received header or `DEBOX_WEBHOOK_KEY`.
- Parse the JSON body only after header validation.
- Deduplicate before invoking the agent.

Expected DeBox update body shape:

```json
{
  "id": 123,
  "message": {
    "message_id": "msg-id",
    "chat": { "id": "chat-id", "type": "group" },
    "from": { "id": "user-id", "name": "name" },
    "text": "hello"
  }
}
```

Map the webhook body into the agent channel message shape:

```json
{
  "provider": "debox",
  "provider_message_id": "msg-id",
  "provider_update_id": 123,
  "conversation_id": "chat-id",
  "conversation_type": "group",
  "sender_id": "user-id",
  "sender_name": "name",
  "text": "hello",
  "raw": {}
}
```

Filtering rules:

- Ignore webhook updates without `message.text` unless the agent explicitly handles callbacks or media.
- Deduplicate by `provider_update_id`; use `provider_message_id` as a secondary key.
- If the bot should only respond to mentions, check whether `message.text` contains the bot display name.
- Pass normalized messages to Claude only after validation and deduplication.

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

## Channel Flow

```text
DeBox webhook -> host runtime validation -> normalized channel message -> Claude agent -> bot/sendMessage
```

## Error Handling

- On HTTP 401/403: stop and ask the user to check `DEBOX_API_KEY`, `DEBOX_API_SECRET`, and bot permissions.
- On missing inbound messages: check webhook URL configuration, webhook header validation, group monitoring settings, and whether the bot only receives mentions.
- On send failure: report the DeBox error message and do not retry repeatedly.
- Never include secret header values in error reports.

## Minimal Channel Contract

A host integrating this skill should provide:

- secret lookup for `DEBOX_API_KEY`, `DEBOX_API_SECRET`, and optionally `DEBOX_WEBHOOK_KEY`
- a public HTTPS webhook endpoint for DeBox callbacks
- webhook header validation before agent invocation
- SHA-1 signature generation for signed bot endpoints
- an HTTP request tool that supports form bodies and custom headers
- deduplication keyed by DeBox update id
