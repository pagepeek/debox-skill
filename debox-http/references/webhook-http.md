# DeBox Webhook HTTP

Use this reference when DeBox sends updates to a user-managed webhook endpoint.

## Webhook vs Polling

If a Webhook URL is configured in the DeBox bot control page, DeBox sends updates to the webhook first and SDK-style polling with `bot/getUpdates` may receive nothing.

Use webhook for high-traffic bots. Use polling for short, controlled HTTP-tool tasks where the bot panel has no Webhook URL configured.

## Verify Callback Header

DeBox callbacks include an `X-API-KEY` header. Compare it to `DEBOX_WEBHOOK_KEY`.

Rules:

- Use constant-time comparison in application code when possible.
- Never log the full received header or `DEBOX_WEBHOOK_KEY`.
- Reject missing or mismatched headers before processing the body.

Minimal pseudocode:

```text
if request.headers["X-API-KEY"] != env.DEBOX_WEBHOOK_KEY:
    return 401
parse JSON body as update
process update.message or update.callback_query
```

## Update Handling

The webhook body follows the same high-level model as SDK updates:

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

After parsing a message:

1. Read `message.chat.id` and `message.chat.type`.
2. Read `message.text`.
3. If replying, use `POST /openapi/bot/sendMessage` with those chat fields.
4. Deduplicate by update `id` or message identifier if your server can receive retries.
