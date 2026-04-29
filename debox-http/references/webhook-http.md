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

The Chat Bot webhook body uses this high-level shape:

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

After parsing a message:

1. Read `from_user_id` as the sender id.
2. Read `group_id`; when it is non-empty, treat the conversation as a group, otherwise treat it as a private chat.
3. Read `message` as the agent-facing text and preserve `message_raw` only when useful for mention detection or debugging.
4. If replying, use `POST /openapi/bot/sendMessage` with the derived chat id and chat type.
5. Deduplicate by a host-generated event id or a stable hash of the callback body if the host can receive retries.
