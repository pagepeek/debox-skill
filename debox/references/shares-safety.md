# DeBox Shares and Chain Safety

Use this reference for Shares, signing, transfers, Swap, chain buttons, or any request that could move assets or authorize wallet actions.

## Default Stance

Treat these tasks as high risk. By default, generate templates, explain parameters, or review user-provided code. Do not auto-execute real asset-moving actions.

## Hard Rules

- Never ask for private keys, mnemonics, or seed phrases.
- Never hide recipient, token, chain ID, amount, allowance, calldata, or contract address from the user.
- Do not construct a real transfer, Swap, signing, or Shares execution without explicit user confirmation.
- Do not place App Secret or API keys in frontend code.
- Prefer testnet or dry-run examples when possible.

## Allowed Without Extra Confirmation

- Explain DeBox Shares concepts.
- Generate a non-executed contract or frontend template.
- Decode or summarize user-provided transaction parameters.
- Identify which fields need user review.

## Requires Explicit Confirmation

- Sending a transaction.
- Creating calldata for a specific real recipient and amount.
- Enabling ERC20 allowance.
- Calling Swap.
- Integrating production Shares contract addresses into deployable code.

When confirmation is needed, summarize the exact chain, token, amount, recipient, contract, and risk before proceeding.
