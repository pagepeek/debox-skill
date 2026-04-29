# DeBox Shares and Chain Safety

Use this reference for Shares, signing, transfers, Swap, chain buttons, or any request that could move assets or authorize wallet actions.

## Default Stance

Treat these tasks as high risk. By default, generate templates, explain parameters, or review user-provided code. Do not auto-execute real asset-moving actions.

## Hard Rules

- Never ask for private keys, mnemonics, or seed phrases.
- Never hide recipient, token, chain ID, amount, allowance, calldata, or contract address from the user.
- Even with explicit confirmation, this v1 skill does not broadcast, sign, or send real transactions, call Swap, enable real allowances, or integrate production Shares contract addresses into deployable code.
- Do not place App Secret or API keys in frontend code.
- Prefer testnet or dry-run examples when possible.

## Allowed Without Extra Confirmation

- Explain DeBox Shares concepts.
- Generate placeholder-only contract or frontend templates with no production addresses, no real amounts, and no transaction submission or signing calls.
- Decode or summarize user-provided transaction parameters.
- Identify which fields need user review.

## Explicit Confirmation Can Allow

- Review of user-provided code, calldata, or transaction parameters.
- Placeholder templates that still avoid production addresses, real amounts, and execution calls.
- Parameter explanation for a user-provided chain, token, amount, recipient, allowance, calldata, or contract.
- Instructions for the user or developer to execute outside this skill.

## Outside V1 Executable Scope

- Broadcasting, signing, or sending a real transaction.
- Creating calldata for a specific real recipient and amount.
- Enabling a real ERC20 allowance.
- Calling Swap.
- Integrating production Shares contract addresses into deployable code.

When explicit confirmation is needed for review, explanation, placeholder templates, or outside-the-skill instructions, summarize the exact chain, token, amount, recipient, contract, and risk before proceeding.
