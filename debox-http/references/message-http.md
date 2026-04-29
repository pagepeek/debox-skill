# DeBox Message HTTP

Use this reference for direct HTTP message receiving and sending with an HTTP request tool only.

## Receive Messages

Source: official Go SDK behavior for `GetUpdates`.

Request:

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
```

Form fields:

```text
offset=<last_update_id_plus_1>   # optional
limit=<max_updates>              # optional
timeout=<seconds>                # optional
allowed_updates=<json-array>     # optional
```

HTTP tool body example:

```json
{
  "offset": "0",
  "limit": "20",
  "timeout": "30"
}
```

Expected response shape follows the SDK `APIResponse` model:

```json
{
  "ok": true,
  "result": [
    {
      "id": 123,
      "message": {
        "message_id": "msg-id",
        "chat": { "id": "chat-id", "type": "group" },
        "from": { "id": "user-id", "name": "name" },
        "text": "hello"
      }
    }
  ]
}
```

Polling notes:

- Process updates in order from old to new.
- Store the largest `update.id` and next time send `offset = id + 1`.
- DeBox polling messages are retained only briefly, about 1 minute.
- If a webhook URL is configured, polling may receive nothing.

## Bot Send Message

Source: official Go SDK behavior for `Send(NewMessage(chatID, chatType, text))`.

Request:

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
```

Form fields:

```text
chat_id=<target chat id>
chat_type=group|private
text=<message text>
parse_mode=MarkdownV2|Markdown|HTML|richtext   # optional
```

HTTP tool body example:

```json
{
  "chat_id": "chat-id-from-update",
  "chat_type": "group",
  "text": "message text"
}
```

Use this for replying to a chat from received updates. For a reply, take `chat.id` and `chat.type` from the update.

## OpenPlatform Group Send

Source: DeBox OpenPlatform SendingMessages docs.

Request:

```yaml
method: POST
url: https://open.debox.pro/openapi/messages/group/send
headers:
  Content-Type: application/json
  X-API-KEY: <DEBOX_API_KEY>
  app_id: <DEBOX_APP_ID>
body_type: json
```

JSON body:

```json
{
  "group_id": "l3ixp32y",
  "object_name": "text",
  "title": "optional title",
  "content": "message text"
}
```

Send the JSON body directly through the HTTP tool's structured body field. Do not manually concatenate JSON strings.

## Choosing Send Path

- Use `bot/sendMessage` to reply to incoming bot updates by `chat_id` and `chat_type`.
- Use `messages/group/send` for OpenPlatform group pushes when you already have a DeBox `group_id`.
- Do not use either path for token transfers, Swap, signing, or Shares execution.
