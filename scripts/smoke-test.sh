#!/usr/bin/env bash
# End-to-end check of the remove.bg-compatible endpoint with a real key.
#
#   PIXMILLER_API_KEY=... ./scripts/smoke-test.sh           # free checks only
#   PIXMILLER_API_KEY=... ./scripts/smoke-test.sh --paid    # + one paid call (spends 1 credit)
#
# Optional: PIXMILLER_API_BASE (default https://api.pixmiller.com), SMOKE_IMAGE=path/to/photo.jpg
set -uo pipefail

BASE="${PIXMILLER_API_BASE:-https://api.pixmiller.com}"
KEY="${PIXMILLER_API_KEY:-}"
SAMPLE_URL="https://pixmiller.com/static/img/demo/2-photo.webp"
PAID=0
[ "${1:-}" = "--paid" ] && PAID=1

if [ -z "$KEY" ]; then
  echo "Set PIXMILLER_API_KEY first." >&2
  exit 2
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
FAILS=0

pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAILS=$((FAILS + 1)); }
header() { grep -i "^$1:" "$2" | tail -1 | cut -d: -f2- | tr -d ' \r'; }
balance() {
  curl -sS -H "X-Api-Key: $KEY" "$BASE/v1.0/account" |
    sed -n 's/.*"total":[[:space:]]*\([0-9.]*\).*/\1/p'
}
if [ -n "${SMOKE_IMAGE:-}" ]; then SRC=(-F "image_file=@$SMOKE_IMAGE"); else SRC=(-F "image_url=$SAMPLE_URL"); fi

echo "Smoke test against $BASE"

# 1. Missing key → 403 auth_failed in remove.bg's error envelope
code="$(curl -sS -o "$tmp/e.json" -w '%{http_code}' -X POST "$BASE/v1.0/removebg")"
if [ "$code" = "403" ] && grep -q '"auth_failed"' "$tmp/e.json"; then pass "no key → 403 auth_failed"; else fail "no key → got $code $(cat "$tmp/e.json")"; fi

# 2. Account
code="$(curl -sS -o "$tmp/a.json" -w '%{http_code}' -H "X-Api-Key: $KEY" "$BASE/v1.0/account")"
before="$(sed -n 's/.*"total":[[:space:]]*\([0-9.]*\).*/\1/p' "$tmp/a.json")"
if [ "$code" = "200" ] && [ -n "$before" ]; then pass "GET /v1.0/account → 200, credits.total = $before"; else fail "GET /v1.0/account → $code $(cat "$tmp/a.json")"; fi

# 3. Default size (preview) → free watermarked image
code="$(curl -sS -D "$tmp/h3" -o "$tmp/preview.png" -w '%{http_code}' -H "X-Api-Key: $KEY" "${SRC[@]}" "$BASE/v1.0/removebg")"
charged="$(header x-credits-charged "$tmp/h3")"
if [ "$code" = "200" ] && [ "$charged" = "0" ]; then
  pass "default size → 200, X-Credits-Charged: 0, $(header x-width "$tmp/h3")x$(header x-height "$tmp/h3") px"
else
  fail "default size → $code, X-Credits-Charged: ${charged:-missing}"
fi

# 4. JSON envelope
code="$(curl -sS -o "$tmp/j.json" -w '%{http_code}' -H "Accept: application/json" -H "X-Api-Key: $KEY" "${SRC[@]}" -F "size=preview" "$BASE/v1.0/removebg")"
if [ "$code" = "200" ] && grep -q '"result_b64"' "$tmp/j.json"; then pass "Accept: application/json → data.result_b64"; else fail "JSON envelope → $code $(head -c 200 "$tmp/j.json")"; fi

# 5. Invalid parameter → 400 invalid_parameter
code="$(curl -sS -o "$tmp/p.json" -w '%{http_code}' -H "X-Api-Key: $KEY" "${SRC[@]}" -F "size=gigantic" "$BASE/v1.0/removebg")"
if [ "$code" = "400" ] && grep -q '"invalid_parameter"' "$tmp/p.json"; then pass "size=gigantic → 400 invalid_parameter"; else fail "invalid size → $code $(cat "$tmp/p.json")"; fi

if [ "$PAID" = "1" ]; then
  # 6. Paid call → watermark-free result, exactly 1 credit, rate-limit headers
  code="$(curl -sS -D "$tmp/h6" -o out.png -w '%{http_code}' -H "X-Api-Key: $KEY" "${SRC[@]}" -F "size=auto" "$BASE/v1.0/removebg")"
  charged="$(header x-credits-charged "$tmp/h6")"
  if [ "$code" = "200" ] && [ "$charged" = "1" ]; then
    pass "size=auto → 200, X-Credits-Charged: 1, $(header x-width "$tmp/h6")x$(header x-height "$tmp/h6") px → out.png"
  else
    fail "size=auto → $code, X-Credits-Charged: ${charged:-missing} $( [ "$code" != 200 ] && cat out.png)"
  fi
  limit="$(header x-ratelimit-limit "$tmp/h6")"
  remaining="$(header x-ratelimit-remaining "$tmp/h6")"
  if [ -n "$limit" ] && [ -n "$remaining" ]; then pass "X-RateLimit-Limit: $limit, Remaining: $remaining"; else fail "X-RateLimit-* headers missing"; fi
  after="$(balance)"
  if [ -n "$before" ] && [ -n "$after" ] && awk "BEGIN{exit !($before - $after == 1)}"; then
    pass "balance $before → $after (exactly 1 credit)"
  else
    fail "balance $before → ${after:-?} (expected a drop of 1; other traffic on this key can skew it)"
  fi
else
  echo "  ----  paid call skipped (run with --paid to spend 1 credit)"
fi

echo
if [ "$FAILS" -eq 0 ]; then echo "All checks passed."; else echo "$FAILS check(s) failed."; exit 1; fi
