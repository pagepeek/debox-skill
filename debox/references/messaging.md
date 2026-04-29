# DeBox Messaging

Use this reference when the user asks to send a DeBox group message, send a DeBox private message, parse a group ID, or understand message-related CLI output.

## Always Use the Wrapper

For executable operations, use:

```bash
debox/scripts/debox.sh <command> --json
```

Do not hand-write raw DeBox API `curl` calls unless the wrapper is unavailable and the user explicitly accepts the fallback.

## Group ID Extraction

If the user gives a DeBox invite URL such as:

```text
https://m.debox.pro/group?id=fxi3hqo5
```

Run:

```bash
debox/scripts/debox.sh group parse-id \
  --url "https://m.debox.pro/group?id=fxi3hqo5" \
  --json
```

Use the returned `group_id` in message commands.

## Send Group Message

First check credentials:

```bash
debox/scripts/debox.sh env check --json
```

Then send:

```bash
debox/scripts/debox.sh message send-group \
  --group-id "fxi3hqo5" \
  --type text \
  --content "hello" \
  --json
```

Report the returned `message_id` if present. If the command fails, report `error.hint`.

## Send Private Message

First check credentials:

```bash
debox/scripts/debox.sh env check --json
```

Then send:

```bash
debox/scripts/debox.sh message send-private \
  --user-id "uvg2p6ho" \
  --type text \
  --content "hello" \
  --json
```

Report the returned `message_id` if present. If the command fails, report `error.hint`.

## Query Group or User Information

If the installed CLI exposes these commands, confirm availability with `debox/scripts/debox.sh <command> --help --json` or use them only after `env check` succeeds:

```bash
debox/scripts/debox.sh group info --group-id "fxi3hqo5" --json
debox/scripts/debox.sh user info --user-id "uvg2p6ho" --json
```

Use the output to confirm targets before sending messages.

## Message Type Rules

Use `--type text` for plain notifications. Use richer message types only when the user asks for links, images, or structured content and the CLI supports the requested format.

Do not include DeBox credentials in message content.
