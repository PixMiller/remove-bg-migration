#!/usr/bin/env bash
# Check a PixMiller API key without spending any credit.
#
#   PIXMILLER_API_KEY=... ./scripts/verify-key.sh [image-file]
#
# 1. GET  /v1.0/account                 → key valid? current balance
# 2. POST /v1.0/removebg  size=preview  → full request path works (free, watermarked result)
#
# Uses the bundled sample image URL when no file is given. Writes the preview to ./preview.png.
set -euo pipefail

BASE="${PIXMILLER_API_BASE:-https://api.pixmiller.com}"
SAMPLE_URL="https://pixmiller.com/static/img/demo/2-photo.webp"
KEY="${PIXMILLER_API_KEY:-}"

if [ -z "$KEY" ]; then
  echo "Set PIXMILLER_API_KEY first. Get it at https://pixmiller.com/en/users/~api/" >&2
  exit 2
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "1/2  GET $BASE/v1.0/account"
status="$(curl -sS -o "$tmp/account.json" -w '%{http_code}' -H "X-Api-Key: $KEY" "$BASE/v1.0/account")"
if [ "$status" != "200" ]; then
  echo "     ✗ HTTP $status: $(cat "$tmp/account.json")" >&2
  echo "     A 403 invalid_api_key means the key is wrong or was reset." >&2
  exit 1
fi
balance="$(sed -n 's/.*"total":[[:space:]]*\([0-9.]*\).*/\1/p' "$tmp/account.json")"
echo "     ✓ key accepted · credits.total = ${balance:-?}"

echo "2/2  POST $BASE/v1.0/removebg (size=preview, free)"
if [ $# -ge 1 ]; then
  source_args=(-F "image_file=@$1")
else
  source_args=(-F "image_url=$SAMPLE_URL")
fi
status="$(curl -sS -D "$tmp/headers.txt" -o preview.png -w '%{http_code}' \
  -H "X-Api-Key: $KEY" "${source_args[@]}" -F "size=preview" "$BASE/v1.0/removebg")"
if [ "$status" != "200" ]; then
  echo "     ✗ HTTP $status: $(cat preview.png)" >&2
  rm -f preview.png
  exit 1
fi
charged="$(grep -i '^x-credits-charged:' "$tmp/headers.txt" | tr -d '\r' | awk '{print $2}')"
size="$(grep -i -E '^x-(width|height):' "$tmp/headers.txt" | tr -d '\r' | awk '{print $2}' | paste -sd x -)"
echo "     ✓ 200 · ${size:-?} px · X-Credits-Charged: ${charged:-?} → preview.png (watermarked)"
echo
echo "Your key works. For watermark-free output send size=auto (1 credit per image)."
