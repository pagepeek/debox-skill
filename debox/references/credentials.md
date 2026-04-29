# DeBox Credentials

Use this reference when the user needs to configure DeBox OpenPlatform access or when `debox/scripts/debox.sh env check --json` reports missing credentials.

## Environment Variables

The skill and CLI read credentials from environment variables:

```bash
export DEBOX_API_KEY="..."
export DEBOX_APP_ID="..."
export DEBOX_APP_SECRET="..." # optional; outside v1 normal messaging
export DEBOX_WEBHOOK_KEY="..."
```

Set real secrets through a local secret manager, CI secret store, encrypted env loader, or shell-history-safe mechanism. Do not paste real secrets into recorded commands.

`DEBOX_API_KEY` is required for one-shot message sending and most OpenPlatform calls. `DEBOX_APP_ID` identifies the developer app or Bot. `DEBOX_APP_SECRET` is optional for normal messaging and only for sensitive APIs such as payment, transfer, or point-related calls, which are outside this skill's v1 executable scope. `DEBOX_WEBHOOK_KEY` is used to verify DeBox webhook callbacks.

## Agent Rules

- Do not ask for wallet private keys, mnemonics, or seed phrases.
- Do not pass API keys or app secrets as command-line arguments.
- Do not put secrets in frontend code, examples, logs, commits, or screenshots.
- Do not echo full secrets back to the user.
- If a secret must be discussed, refer to it by variable name.

## Readiness Check

Run:

```bash
debox/scripts/debox.sh env check --json
```

If this fails, report the CLI's `error.hint` and ask the user to set the missing environment variable locally.

## Where Values Come From

The user obtains DeBox OpenPlatform values from the DeBox developer portal after connecting the wallet that owns the DeBox account:

- App ID: application or Bot identifier.
- API Key: primary API credential for OpenPlatform calls.
- App Secret: sensitive credential, usually available after advanced developer verification.
- Webhook Key: generated after webhook configuration and sent by DeBox in the `X-API-KEY` callback header.
