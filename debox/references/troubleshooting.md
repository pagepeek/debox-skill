# DeBox Troubleshooting

Use this reference when `debox/scripts/debox.sh` fails, DeBox OpenPlatform returns an error, or the user reports missing messages or setup issues.

## Wrapper Bootstrap Errors

- `UNSUPPORTED_PLATFORM`: supported platforms are `darwin-arm64`, `darwin-amd64`, `linux-arm64`, and `linux-amd64`.
- `CLI_DOWNLOAD_FAILED`: check network access or set `DEBOX_SKILL_CLI_BASE_URL`.
- `CHECKSUM_DOWNLOAD_FAILED`: release is missing `checksums.txt` or the base URL is wrong.
- `CHECKSUM_NOT_FOUND`: `checksums.txt` lacks the platform binary entry.
- `CHECKSUM_MISMATCH`: do not run the binary; verify the release source.
- `CURL_NOT_FOUND`: install `curl` or pre-populate the cache.

## Common DeBox API Errors

- `-2004`: invalid parameter. Check group ID, user ID, message type, and required content.
- `-2013`: access token expired. Re-authorize the relevant user flow.
- `-2015`: access token check failure. Verify token source and headers.
- `-7048`: insufficient balance. Do not retry blindly.

## Group ID Issues

A DeBox group invite URL can contain `id=<group_id>`. Use:

```bash
debox/scripts/debox.sh group parse-id --url "https://m.debox.pro/group?id=fxi3hqo5" --json
```

## Bot Message Receiving Issues

This skill does not manage Bot runtime. If the user is using a Bot outside this skill:

- If Webhook URL is configured, SDK polling may not receive messages.
- If group full-message monitoring is off, the Bot may only receive messages that mention it.
- Webhook callbacks should verify the `X-API-KEY` header against `DEBOX_WEBHOOK_KEY`.

## Redirect URI Issues

For DeBox authorization flows, use HTTPS redirect URIs and encode special characters with `encodeURIComponent` when building URLs.
