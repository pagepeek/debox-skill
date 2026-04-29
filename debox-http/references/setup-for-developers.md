# DeBox Developer Setup

Use this reference to guide a human developer who is new to DeBox through Bot setup, API key retrieval, webhook configuration, and secret storage before channel development starts.

Primary DeBox docs:

```text
https://docs.debox.pro/APIs/BotGuide/
https://docs.debox.pro/zh/APIs/BotGuide/
https://docs.debox.pro/ApiOnePage/
```

The developer platform page alone may not provide enough context for a new user. Treat the official Bot Guide as the primary setup source, and use `https://developer.debox.pro` only as the place where the human performs the account-specific actions.

## Setup Goal

Before implementing a DeBox channel, the developer should have:

```text
DEBOX_API_KEY
DEBOX_WEBHOOK_KEY
DEBOX_OPENAPI_BASE_URL=https://open.debox.pro
```

Some integrations also need:

```text
DEBOX_APP_ID
DEBOX_APP_SECRET
```

Do not ask the developer to paste real secret values into chat. Ask them to confirm whether each item has been created and stored in their server-side secret manager.

## Step 1: Create Or Choose The Bot Account

DeBox Chat Bot is a DeBox user account with Bot features enabled.

Human steps:

1. Open `https://app.debox.pro/`.
2. Connect the wallet that should own the Bot account.
3. Complete DeBox user registration if the wallet is not registered.
4. Set the account nickname, avatar, and profile as the public Bot identity.

Important:

- The Bot's DeBox user profile is visible to users.
- Do not use a wallet or profile that should remain private.
- Never ask for wallet private keys, mnemonics, or seed phrases.

## Step 2: Open The Developer Platform

Human steps:

1. Open `https://developer.debox.pro`.
2. Click `Connect your wallet`.
3. Connect the wallet for the DeBox account that should become the Bot.
4. Sign in to verify account ownership.
5. Confirm the Bot information page is visible.

According to the official Bot Guide, the Bot information page should expose:

```text
App ID
API Key
App Secret
App Domain
Bot tab
Webhook Url
Webhook Key
Monitor group message
```

If the page does not expose these fields:

1. Stop the channel development flow.
2. Ask the human to confirm the wallet is registered on `https://app.debox.pro/`.
3. Ask the human to confirm they connected the same wallet on `https://developer.debox.pro`.
4. Ask the human to open the official Bot Guide and compare their page with the documented Bot information page.
5. Ask the human to complete any missing DeBox account or Bot registration step shown by the platform.
6. If the platform still does not show `App ID`, `API Key`, `App Domain`, and the `Bot` tab, tell the human that setup is blocked by DeBox platform state and they should contact DeBox support or platform maintainers.

Do not invent API keys, webhook keys, or undocumented page locations. Do not proceed to channel design while the developer platform does not expose the required Bot configuration fields.

## Step 3: Get The API Key

Human steps:

1. On the Bot information page, find `API Key`.
2. Click `Get`.
3. Sign the wallet verification prompt.
4. Store the returned value as `DEBOX_API_KEY` in the server-side secret store.

Use:

- `DEBOX_API_KEY` authenticates DeBox OpenPlatform and Bot HTTP requests.
- Do not put it in frontend code, URLs, logs, shell history, or committed config files.

## Step 4: Configure App Domain

The App Domain is the trusted domain allowlist for external webhook callbacks.

Human steps:

1. Decide the public HTTPS host that will receive DeBox webhook callbacks.
2. On the Bot information page, set `App Domain` to that trusted domain.
3. Save or apply the setting in the DeBox developer platform.

Example mapping:

```text
Webhook URL: https://agent.example.com/debox/webhook
App Domain: agent.example.com
```

Use the exact domain format accepted by the DeBox developer platform UI. The later Webhook URL must be under the trusted domain.

## Step 5: Configure Webhook URL

The developer's host application must expose a public HTTPS endpoint before production use.

Generic endpoint shape:

```text
POST https://<trusted-domain>/<debox-webhook-path>
```

Human steps:

1. Open the Bot tab in the DeBox developer platform.
2. Find `Webhook Url`.
3. Enter the public HTTPS webhook endpoint.
4. Click `Apply`.
5. Confirm the Bot webhook callback is activated.

Important:

- When a Webhook URL is configured, DeBox pushes messages to the webhook.
- Polling with `bot/getUpdates` may receive nothing while a Webhook URL is configured.
- Use webhook mode for production channel integrations.

## Step 6: Save The Webhook Key

After configuring the Webhook URL, DeBox generates a `Webhook Key`.

Human steps:

1. Copy the generated `Webhook Key`.
2. Store it as `DEBOX_WEBHOOK_KEY` in the server-side secret store.
3. Configure the webhook handler to compare incoming `X-API-KEY` against this value.

Important:

- DeBox sends `Webhook Key` in the callback header `X-API-KEY`.
- The Webhook Key changes after the Webhook URL is modified.
- Every Webhook URL change requires updating `DEBOX_WEBHOOK_KEY` in the host application.

## Step 7: Decide Group Message Monitoring

The Bot configuration includes `Monitor group message`.

Guidance:

- Disabled: the Bot receives group callbacks only when users mention the Bot.
- Enabled: the Bot receives all messages from groups where the Bot is present.
- Do not enable it unless the product needs all group messages, because callback volume can increase quickly.

For first channel development, prefer mention-only behavior unless the use case clearly requires full group monitoring.

## Step 8: Understand Incoming Webhook Shape

Official DeBox Chat Bot webhook callbacks use this high-level JSON shape:

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

Callback header:

```text
X-API-KEY: <Webhook Key>
```

Mapping guidance:

- `from_user_id` becomes sender id.
- `to_user_id` becomes Bot id.
- `group_id` determines conversation type: non-empty means group, empty means private chat.
- `message` is the text to pass to the agent.
- `message_raw` can be preserved for debugging or mention detection.

## Step 9: Development Readiness Checklist

Ask the human developer to confirm this without revealing secrets:

```text
DeBox account registered: yes/no
Developer platform accessible: yes/no
API Key obtained and stored server-side: yes/no
App Domain configured: yes/no
Webhook URL configured: yes/no
Webhook Key obtained and stored server-side: yes/no
Bot added to target group, if group testing is needed: yes/no
Monitor group message setting chosen intentionally: yes/no
```

If any answer is `no`, finish setup before implementing the channel adapter.

## Step 10: Hand Off To Channel Development

After setup is complete, use:

```text
references/channel-integration.md
references/webhook-http.md
references/message-http.md
references/auth-http.md
```

The channel adapter should own webhook validation, message normalization, deduplication, outbound DeBox HTTP calls, and secret-safe error handling.
