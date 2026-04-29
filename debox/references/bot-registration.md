# DeBox Bot Registration

Use this reference when the user asks how to create or configure a DeBox Bot. This skill does not run a Bot runtime.

## Ownership Boundary

The user must register and authorize the Bot with their own DeBox wallet account. Do not ask for private keys, mnemonics, or seed phrases. Do not attempt to operate the user's wallet.

## Registration Flow

1. The user creates or selects a DeBox account in the DeBox app or web app.
2. The user opens the DeBox developer portal.
3. The user connects the wallet that owns the DeBox account and signs in.
4. The user creates or enables the Bot.
5. The user configures nickname, avatar, profile, App Domain, and optional Webhook URL.
6. The user copies the required non-wallet credentials into local environment variables.

## Fields

- App ID: unique application or Bot identifier.
- API Key: required for most OpenPlatform and Bot API calls.
- App Secret: required only for sensitive APIs, outside this skill's v1 executable scope.
- App Domain: trusted domain for webhook callbacks.
- Webhook URL: HTTPS endpoint that receives DeBox message callbacks.
- Webhook Key: sent by DeBox in the callback `X-API-KEY` header.

## When to Use CLI Instead

If the user only needs to send a group notification or private message, prefer `debox/scripts/debox.sh` one-shot commands. Do not introduce runtime, polling, or webhook server design for simple sending tasks.
