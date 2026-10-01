# AGENTS.md

Guidance for coding agents working **on this repository**. To migrate *another* project from
remove.bg, use the skill in [`skills/remove-bg-migration/`](skills/remove-bg-migration/SKILL.md)
instead.

## What this repo is

A public migration kit for developers leaving the remove.bg API, which shuts down on
2026-12-01. It contains docs (`docs/`, Chinese in `docs/zh-CN/`), runnable examples
(`examples/`), helper scripts (`scripts/`), an agent skill (`skills/`), and a Claude Code plugin
manifest (`.claude-plugin/`).

## Source of truth

The API contract is defined by PixMiller's website guide:
https://pixmiller.com/en/api-docs/remove-bg-migration/. Any statement about behaviour (status
codes, parameters, limits, prices, size tiers) must match that page. Do not invent capabilities.
In particular, never claim SDK-level drop-in compatibility, and never quote prices.

## Rules

- Keep `scripts/find-removebg-usages.sh` and `scripts/verify-key.sh` byte-identical to their
  copies in `skills/remove-bg-migration/scripts/`. CI checks this.
- When you change an English doc, update the matching file in `docs/zh-CN/` and the READMEs.
- Every example must keep the shared interface (`PIXMILLER_API_KEY`, `PIXMILLER_API_BASE`,
  `PIXMILLER_SIZE`, retry on 429, `errors[0].code` on failure), and must pass
  `./tests/run-examples.sh`.
- Shell scripts must pass `shellcheck`.
- Never commit API keys. Examples read keys from the environment only.
- Links to pixmiller.com carry `utm_source=github&utm_medium=referral&utm_campaign=removebg-migration`.

## Checks

```bash
./tests/run-examples.sh
shellcheck scripts/*.sh examples/curl/*.sh tests/*.sh skills/remove-bg-migration/scripts/*.sh
claude plugin validate .claude-plugin/plugin.json   # if Claude Code is installed
```
