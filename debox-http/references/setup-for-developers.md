# DeBox Copy-Paste Setup

Use this reference when a new DeBox user does not know how to configure a project and can only copy values from DeBox pages into chat. The agent must turn pasted values into working local or deployment configuration before channel development starts.

Primary DeBox docs:

```text
https://docs.debox.pro/APIs/BotGuide/
https://docs.debox.pro/zh/APIs/BotGuide/
https://docs.debox.pro/ApiOnePage/
```

The developer platform page alone may not provide enough context for a new user. Treat the official Bot Guide as the primary setup source, and use `https://developer.debox.pro` only to tell the user where to find fields or to operate the browser when browser access is available.

Observed pitfall: `https://developer.debox.pro/accounts` can show only an `Unauthorized 403` page with `Docs` and `Return home`. That page is not enough to continue setup. If the human sees this state, stop and resolve account access before discussing channel code.

## Operating Rule

The agent owns setup. The user may be non-technical and may only be able to copy text into chat.

Agent responsibilities:

- Ask the user to paste the DeBox values they can see.
- Accept messy pasted text, screenshots transcribed by the user, or partial values.
- Identify `API Key`, `Webhook Key`, `App ID`, `App Secret`, `App Domain`, and `Webhook URL` from the pasted content.
- Ask one short follow-up only for missing required values.
- Choose a working storage target for the current project.
- Store real secrets in local runtime config or deployment secrets.
- Add or update a committed template such as `.env.example` when useful.
- Add local secret files such as `.env.local` to `.gitignore` when needed.
- Report only status and destination names, for example `DEBOX_API_KEY saved to .env.local`.

The user may directly provide DeBox secret values to the agent for setup. This is the default simple path. After receiving them, do not echo the values back. Store them, verify the destination, and report only which variables were saved and where.

Do not hard-code real DeBox keys into source code or commit them to git. If the user asks to "upload config", upload code/config templates and set real values through the deployment secret mechanism. For a local prototype, write real values only to an uncommitted local env file such as `.env.local` and ensure it is ignored by git.

## Copy-Paste Prompt

When setup starts, ask the user to paste whatever they have in this simple format. Tell them to leave unknown fields blank.

```text
Please paste the DeBox values you can see. Leave unknown fields blank.

API Key:
Webhook Key:
App ID:
App Secret:
App Domain:
Webhook URL:
Monitor group message: on/off/unknown
```

After the user responds:

1. Parse the pasted text.
2. Save known values immediately.
3. Ask only for values still required for the next step.
4. Do not ask the user to choose file paths unless there are multiple reasonable project-specific options.

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

Secrets can come from user-pasted chat text, the DeBox UI, or an existing deployment secret store. The agent should place them into the target project's runtime configuration and avoid exposing values in later chat output.

## Storage Decision

Pick the first matching option:

1. If the project already documents an env file or secret store, use that.
2. If the project has a deployment provider configured, use its secret mechanism when available.
3. Otherwise, create or update an uncommitted local env file such as `.env.local`.
4. Also create or update `.env.example` with placeholder names, not real values.
5. Ensure the real local env file is ignored by git.

Minimum local env content:

```text
DEBOX_API_KEY=<real value>
DEBOX_WEBHOOK_KEY=<real value>
DEBOX_OPENAPI_BASE_URL=https://open.debox.pro
DEBOX_APP_ID=<real value if available>
DEBOX_APP_SECRET=<real value if available>
```

## Step 1: Create Or Choose The Bot Account

DeBox Chat Bot is a DeBox user account with Bot features enabled.

If the user already pasted keys, skip account creation instructions and save the values. Only return here if required values are missing.

Agent steps when values are missing:

1. Open `https://app.debox.pro/`.
2. Ask the user to approve wallet connection for the wallet that should own the Bot account.
3. Guide the user through any wallet signature or DeBox registration prompt.
4. Help set or verify the account nickname, avatar, and profile as the public Bot identity.

Important:

- The Bot's DeBox user profile is visible to users.
- Do not use a wallet or profile that should remain private.
- Never ask for wallet private keys, mnemonics, or seed phrases.

## Step 2: Open The Developer Platform

If the user already pasted keys, do not make them navigate this page. Use this step only to help them find missing values.

Agent steps when values are missing:

1. Open `https://developer.debox.pro`.
2. Click `Connect your wallet` when present.
3. Ask the user to approve wallet connection and signature prompts.
4. Navigate to the account or Bot information page.
5. Confirm the Bot information page is visible before continuing.

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
2. If the human sees `Unauthorized 403` on `/accounts`, treat it as an access/session problem, not as a configured developer account.
3. Re-open `https://app.debox.pro/` and verify the user is registered.
4. Re-open `https://developer.debox.pro` and connect the same wallet.
5. Open the official Bot Guide and compare the current page with the documented Bot information page.
6. Help the user complete any missing DeBox account or Bot registration step shown by the platform.
7. If the platform still does not show `App ID`, `API Key`, `App Domain`, and the `Bot` tab, tell the human that setup is blocked by DeBox platform state and they should contact DeBox support or platform maintainers.

Do not invent API keys, webhook keys, or undocumented page locations. Do not proceed to channel design while the developer platform does not expose the required Bot configuration fields.

## Step 3: Get The API Key

If the user pasted an API Key, save it and skip UI retrieval.

Agent steps when API Key is missing:

1. On the Bot information page, find `API Key`.
2. Click `Get`.
3. Ask the user to approve the wallet verification prompt.
4. Copy the returned value from the UI.
5. Store it as `DEBOX_API_KEY` in the target project's approved secret store.
6. Report the storage destination, not the value.

Use:

- `DEBOX_API_KEY` authenticates DeBox OpenPlatform and Bot HTTP requests.
- Prefer a server-side secret store or local uncommitted env file.

## Step 4: Configure App Domain

The App Domain is the trusted domain allowlist for external webhook callbacks.

If the user pasted App Domain, save or record it. If it is missing and webhook setup is needed, ask the user to copy the App Domain field or let the agent operate the browser.

Agent steps when App Domain must be configured:

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

If the user pasted Webhook URL, save or record it. If the host does not have a public HTTPS webhook URL yet, generate or identify the intended URL during channel deployment.

Agent steps when Webhook URL must be configured:

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

If the user pasted a Webhook Key, save it and skip UI retrieval.

Agent steps when Webhook Key is missing:

1. Copy the generated `Webhook Key` from the UI.
2. Store it as `DEBOX_WEBHOOK_KEY` in the target project's approved secret store.
3. Configure the webhook handler to compare incoming `X-API-KEY` against this value.
4. Report the storage destination, not the value.

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

## Step 9: Setup Status

Report this setup status before moving to channel development:

```text
DeBox account registered: yes/no
Developer platform accessible: yes/no
API Key obtained from UI or user and stored by agent: yes/no
App Domain configured: yes/no
Webhook URL configured: yes/no
Webhook Key obtained from UI or user and stored by agent: yes/no
Bot added to target group, if group testing is needed: yes/no
Monitor group message setting chosen intentionally: yes/no
Secret storage destination documented: yes/no
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
