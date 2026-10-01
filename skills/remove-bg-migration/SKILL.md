---
name: remove-bg-migration
description: Migrate a codebase from the remove.bg background-removal API (api.remove.bg/v1.0/removebg, shutting down 1 December 2026) to PixMiller's remove.bg-compatible API at api.pixmiller.com. Use when the user mentions remove.bg, removebg, api.remove.bg, the remove.bg shutdown or sunset, a remove.bg alternative or replacement, or wants to switch, port or migrate a background-removal integration, including code that uses the PyPI removebg package, the npm remove.bg package, removebg-cli, or a Zapier/Make/n8n remove.bg step. Covers finding call sites, getting a PixMiller account and API key, the code changes, the behavioural differences (size=preview is a free watermarked image, 40 images/min, shadows not rendered, 20 MB input), and verifying the switch without spending credits.
---

# remove.bg → PixMiller migration

remove.bg's self-service API stops accepting requests on **1 December 2026, 09:00 CET**.
PixMiller serves the same request shape at `https://api.pixmiller.com/v1.0/removebg`: the same
`X-Api-Key` header, the same form fields, `200` with the image bytes, the same `X-*` headers
and the same `{"errors":[…]}` envelope. For hand-written HTTP code the change is usually the
base URL and the key. It is **not** a guaranteed SDK-level drop-in. Never tell the user it is.

Full contract: [references/api-contract.md](references/api-contract.md).
SDKs and no-code tools: [references/client-libraries.md](references/client-libraries.md).

## Workflow

Copy this checklist into your reply and keep it updated:

```
- [ ] 1. Find every remove.bg call site
- [ ] 2. Classify each integration
- [ ] 3. Account + API key (the user does this)
- [ ] 4. Change the code
- [ ] 5. Verify without spending credits
- [ ] 6. Report changes and remaining differences
```

### 1. Find every call site

Run the bundled scanner from the project root (read-only):

```bash
bash <skill-dir>/scripts/find-removebg-usages.sh .
```

Also ask the user about places the scanner cannot see: CI or deployment secrets, infrastructure
config, and no-code automations (Zapier, Make, n8n, Pipedream).

### 2. Classify each integration

| Kind | How to migrate |
|---|---|
| Hand-written HTTP (requests, fetch, axios, curl, Guzzle, net/http, …) | Change the base URL and the key, set `size` explicitly. |
| PyPI `removebg` | Override `removebg.removebg.API_ENDPOINT` at startup, or switch to plain HTTP. |
| npm `remove.bg` | The endpoint is a hard-coded `const`. Replace it with a `fetch` call (preferred) or patch-package. |
| `removebg-cli` | Three hard-coded URLs. Replace it with a curl or HTTP call in scripts. |
| Other wrappers | Use a base-URL option if one exists, otherwise replace the wrapper with an HTTP call. |
| Zapier / Make / n8n remove.bg app | It cannot be repointed. Swap it for the platform's generic HTTP step. |

Details and code: [references/client-libraries.md](references/client-libraries.md).

### 3. Account and API key: the user does this

You cannot create the account or fetch the key. Give the user these steps:

1. Sign up at https://pixmiller.com/accounts/signup/ (email or Google).
2. Copy the key from https://pixmiller.com/en/users/~api/ (it is created on first visit).
3. Store it as an environment variable or secret, for example `PIXMILLER_API_KEY`. Reuse the
   project's existing secret mechanism and variable naming where possible.
4. Paid sizes need credits: https://pixmiller.com/en/pricing/ (pay-as-you-go credits never
   expire). `size=preview` is free, so steps 4 and 5 can be done before buying anything.

Rules for the key:

- Never ask the user to paste the key into chat.
- Never write the key into a file that is committed, and never print it.
- Read the key from the environment in code.

### 4. Change the code

Apply the smallest change that matches the project's style:

1. **Base URL:** `https://api.remove.bg` → `https://api.pixmiller.com`. The path `/v1.0/removebg`
   stays the same. Prefer reading the base URL from configuration so the user can roll back
   until 30 November.
2. **Key:** read the PixMiller key from the environment or secret store.
3. **`size`: set it on every call.** `preview`, `small` and `regular` (the default here, and the
   PyPI SDK's default) return a **free watermarked image of up to 640 px**. Use `auto` (full
   resolution while credits last) or a paid tier (`full`, `hd`, `4k`, `medium`, `50MP`), each
   1 credit. Ask the user which one they want if their current code relies on the default.
4. **Rate limit: 40 images/min per key** (remove.bg allows 500). If the code runs batches or
   parallel requests, add throttling and retry on `429` after `Retry-After`.
5. **`402 insufficient_credits`:** make sure it surfaces as an actionable error, not a silent skip.
6. **Inputs over 20 MB** are rejected (remove.bg allowed 22 MB). Add a size check if the code
   accepts arbitrary uploads.
7. **`add_shadow`, `shadow_type`, `shadow_opacity` and `semitransparency`** are accepted but
   never rendered. Tell the user if their code depends on them.

Leave everything else as it is: `image_file` / `image_url` / `image_file_b64`, `format`, `crop`,
`roi`, `scale`, `position`, `channels`, `bg_color`, `bg_image_*`, the `Accept: application/json`
envelope, `X-*` header parsing, and `errors[0].code` handling.

### 5. Verify without spending credits

If `PIXMILLER_API_KEY` is set in the environment:

```bash
PIXMILLER_API_KEY="$PIXMILLER_API_KEY" bash <skill-dir>/scripts/verify-key.sh
```

This script calls `GET /v1.0/account` and makes one `size=preview` request. Both are free.
Then run the project's own tests, or its code path, with `size=preview`.

**Ask before any paid call.** `size=auto` or a paid tier spends 1 credit per image. Only run
one after the user agrees, and check that the response has `X-Credits-Charged: 1`.

If the key is not set, skip this step and give the user the command to run.

### 6. Report

Tell the user:

- which files changed;
- which `size` you chose and what it costs;
- every difference that still applies to their code: watermark on preview, rate limit,
  shadows, file size, coarse `X-Type`, no free monthly calls;
- what they still need to do: the key, credits, secrets in CI or production, and no-code tools.

Link to the guide: https://pixmiller.com/en/api-docs/remove-bg-migration/

## Things not to claim

- That PixMiller is a guaranteed drop-in for remove.bg's official SDKs or CLI. Three clients
  passed one test on 2026-09-22; that is all.
- Prices. They change, so link to https://pixmiller.com/en/pricing/.
- Any affiliation between PixMiller and remove.bg, Canva or Leonardo.Ai. There is none.
