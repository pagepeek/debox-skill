# DeBox Troubleshooting

Use this reference when `debox/scripts/debox.sh` fails, DeBox OpenPlatform returns an error, or the user reports missing messages or setup issues.

## Common Wrapper Bootstrap Errors

This list is not exhaustive; for unlisted bootstrap failures, inspect the JSON `error.code` and follow `error.hint`.

- `BINARY_CACHE_PATH_INVALID`: cached CLI path is not a regular file. Remove the path or use another cache directory.
- `BINARY_CHMOD_FAILED`: the wrapper could not mark the cached CLI executable. Check cache permissions.
- `BINARY_CACHE_WRITE_FAILED`: the wrapper could not write the downloaded CLI into cache. Check cache permissions and disk space.
- `CACHE_DIR_CREATE_FAILED`: the wrapper could not create cache directories. Check `DEBOX_SKILL_CACHE_DIR`.
- `CHECKSUM_CACHE_PATH_INVALID`: cached checksum path is not a regular file. Remove the path or use another cache directory.
- `CHECKSUM_CACHE_WRITE_FAILED`: the wrapper could not write checksum metadata into cache. Check cache permissions and disk space.
- `CHECKSUM_DOWNLOAD_FAILED`: release is missing `checksums.txt` or the base URL is wrong.
- `CHECKSUM_MISMATCH`: do not run the binary; verify the release source.
- `CHECKSUM_NOT_FOUND`: `checksums.txt` lacks the platform binary entry.
- `CHECKSUM_READ_FAILED`: the wrapper could not read cached checksum metadata. Remove the cached checksum file.
- `CLI_DOWNLOAD_FAILED`: check network access or set `DEBOX_SKILL_CLI_BASE_URL`.
- `CLI_EXEC_FAILED`: cached CLI could not start cleanly. Remove the cached binary and retry.
- `HOME_NOT_SET`: set `DEBOX_SKILL_CACHE_DIR` or run with `HOME` set.
- `MISSING_CURL`: install `curl` or pre-populate the cache.
- `MISSING_SHA256`: install `shasum` or `sha256sum`, or use `DEBOX_SKILL_SKIP_CHECKSUM=1` for local development only.
- `SHA256_FAILED`: checksum calculation failed. Check cache readability or remove the cached binary.
- `TEMP_FILE_FAILED`: temporary file creation failed. Check `TMPDIR`.
- `UNSUPPORTED_PLATFORM`: supported platforms are `darwin-arm64`, `darwin-amd64`, `linux-arm64`, and `linux-amd64`.

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
- DeBox Go SDK polling with `GetUpdates` or `GetUpdatesChan` can miss messages if polling is delayed. Unread messages are retained only briefly, about 1 minute per DeBox Go SDK docs, so delayed polling may look like missing messages.
- Webhook callbacks should verify the `X-API-KEY` header against `DEBOX_WEBHOOK_KEY`.

## Redirect URI Issues

For DeBox authorization flows, use HTTPS redirect URIs and encode special characters with `encodeURIComponent` when building URLs.
