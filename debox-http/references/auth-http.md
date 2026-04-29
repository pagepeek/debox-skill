# DeBox HTTP Auth

Use this reference before building any direct DeBox HTTP request.

## Base URL

Default base URL: `https://open.debox.pro`.

## Basic Headers

Always include `X-API-KEY` with the DeBox API key value from the HTTP tool's secret store.

Some OpenPlatform endpoints also use an `app_id` header.

## Bot Endpoint Signature

The official Go SDK signs bot endpoints such as `bot/getUpdates` and `bot/sendMessage` with:

```text
signature = lowercase_hex_sha1(DEBOX_API_SECRET + nonce + timestamp)
```

Use Unix seconds for `timestamp`, a random decimal string for `nonce`, and lowercase hex SHA-1 for `signature`.

Signed bot endpoint headers:

```text
X-API-KEY: <api key>
nonce: <random decimal string>
timestamp: <unix seconds>
signature: <lowercase hex sha1>
```

If the HTTP-only environment cannot compute SHA-1, ask the user or a trusted backend to provide `nonce`, `timestamp`, and `signature` for the request. Do not fabricate or guess a signature.

## Secret Safety

- Never print full `DEBOX_API_KEY`, `DEBOX_API_SECRET`, or `DEBOX_WEBHOOK_KEY`.
- Never put secrets into query strings.
- Never ask for wallet private keys, mnemonics, or seed phrases.
- Do not show shell commands, curl snippets, SDK snippets, or local scripts in this HTTP-only skill.
