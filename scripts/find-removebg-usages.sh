#!/usr/bin/env bash
# List every place a codebase talks to remove.bg, so nothing is missed during migration.
#
#   ./scripts/find-removebg-usages.sh [path]      # default: current directory
#
# Read-only: it only searches. Dependency folders (node_modules, vendor, .venv, …) are skipped.
set -euo pipefail

ROOT="${1:-.}"
if [ ! -d "$ROOT" ]; then
  echo "error: '$ROOT' is not a directory" >&2
  exit 2
fi

ROOT_ABS="$(cd "$ROOT" && pwd)"
cd "$ROOT_ABS"
ROOT="."

EXCLUDES=(.git node_modules vendor .venv venv env __pycache__ dist build .next .nuxt target .gradle .idea .terraform coverage)

search() {
  # search <regex> — prints file:line:match, case-sensitive, extended regex
  local pattern="$1"
  if command -v rg >/dev/null 2>&1; then
    local args=(--line-number --no-heading --color=never --hidden)
    for d in "${EXCLUDES[@]}"; do args+=(--glob "!**/$d/**"); done
    rg "${args[@]}" -e "$pattern" "$ROOT" 2>/dev/null || true
  else
    local args=(-rnE)
    for d in "${EXCLUDES[@]}"; do args+=(--exclude-dir="$d"); done
    grep "${args[@]}" -e "$pattern" "$ROOT" 2>/dev/null || true
  fi
}

TOTAL=0
section() {
  # section <title> <regex> <hint>
  local title="$1" pattern="$2" hint="$3" out count
  out="$(search "$pattern")"
  if [ -n "$out" ]; then
    count="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
    TOTAL=$((TOTAL + count))
    printf '\n== %s (%s)\n' "$title" "$count"
    printf '   → %s\n' "$hint"
    printf '%s\n' "$out" | sed -e 's#^\./##' -e 's/^/   /'
  fi
}

echo "Scanning $ROOT_ABS for remove.bg usage…"

section "Hard-coded remove.bg endpoints" \
  'api\.remove\.bg|remove\.bg/v1\.0' \
  "Replace the host with https://api.pixmiller.com (path /v1.0/removebg stays) — better: read it from config."

section "Python SDK (PyPI removebg / removebg-cli)" \
  '(from|import)[[:space:]]+removebg|RemoveBg\(|removebg_cli|^[[:space:]]*removebg(-cli)?[[:space:]]*([=<>~!]=|$)' \
  "Override removebg.removebg.API_ENDPOINT or switch to plain HTTP — see docs/client-libraries.md. Set size explicitly."

section "Node.js SDK (npm remove.bg)" \
  'require\(["'"'"']remove\.bg["'"'"']\)|from[[:space:]]+["'"'"']remove\.bg["'"'"']|"remove\.bg"[[:space:]]*:|removeBackgroundFromImage(File|Url|Base64)' \
  "The endpoint is a hard-coded const — replace with fetch (examples/node) or patch-package. Set size explicitly."

section "Other remove.bg wrappers (Ruby / PHP / Go / …)" \
  'remove_bg|remove-bg|RemoveBg|removebg' \
  "Check whether the wrapper accepts a base URL; otherwise replace it with the HTTP call from examples/."

section "API key settings and headers" \
  'REMOVE_?BG_?(API_?)?KEY|REMOVEBG_?(API_?)?KEY|X-Api-Key' \
  "Point these at your PixMiller key (https://pixmiller.com/en/users/~api/). Never commit the key."

section "size parameter values" \
  '["'"'"']?size["'"'"']?[[:space:]]*[:=,][[:space:]]*["'"'"'](preview|small|regular|medium|hd|4k|full|auto|50MP)["'"'"']' \
  "preview / small / regular = free WATERMARKED image on PixMiller. Use auto or a paid tier for production."

echo
if [ "$TOTAL" -eq 0 ]; then
  echo "No remove.bg usage found under $ROOT_ABS."
  echo "Also check: CI secrets, infrastructure config, and no-code automations (Zapier, Make, n8n)."
else
  echo "$TOTAL matching line(s). Some lines may appear in more than one section."
  echo "Next: docs/migration-guide.md · docs/production-checklist.md"
fi
