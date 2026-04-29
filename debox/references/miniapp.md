# DeBox MiniApp

Use this reference when the user wants to adapt a web product to run inside DeBox.

## Core Model

A DeBox MiniApp is an H5/web application opened inside DeBox's built-in browser. Existing HTML/CSS/JavaScript applications can often run with minimal changes, but must be mobile-friendly and served over HTTPS.

## Detect DeBox Browser

Use user agent detection:

```javascript
const isDeBox = !!window?.navigator?.userAgent?.includes("DeBox");
```

Use this only as an environment check. Keep a normal browser fallback.

## Wallet Environment

Inside DeBox, the app may have injected wallet objects such as `window.ethereum` or `window.solana`. Use them for wallet authorization, address access, signatures, and transactions only after explicit user action.

## Secret Handling

Do not put `DEBOX_API_KEY`, `DEBOX_APP_SECRET`, or equivalent OpenPlatform credentials in frontend code. If a DeBox OpenPlatform call needs secrets, place it behind a private backend endpoint.

## Agent Guidance

For MiniApp requests, provide an integration checklist and minimal examples. Do not generate transaction-executing code unless the user explicitly asks and confirms the asset-moving behavior.
