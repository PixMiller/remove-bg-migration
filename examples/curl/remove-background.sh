#!/usr/bin/env bash
# Remove the background of one image with curl.
#
#   PIXMILLER_API_KEY=... ./remove-background.sh product.jpg [out.png]
#
# Env: PIXMILLER_API_BASE (default https://api.pixmiller.com), PIXMILLER_SIZE (default auto)
set -euo pipefail

: "${PIXMILLER_API_KEY:?Set PIXMILLER_API_KEY (https://pixmiller.com/en/users/~api/)}"
BASE="${PIXMILLER_API_BASE:-https://api.pixmiller.com}"
SIZE="${PIXMILLER_SIZE:-auto}"
IN="${1:?usage: $0 input-image [output.png]}"
OUT="${2:-out.png}"

headers="$(mktemp)"
trap 'rm -f "$headers"' EXIT

for attempt in 1 2 3 4; do
  status="$(curl -sS -X POST "$BASE/v1.0/removebg" \
    -H "X-Api-Key: $PIXMILLER_API_KEY" \
    -F "image_file=@$IN" \
    -F "size=$SIZE" \
    -D "$headers" -o "$OUT" -w '%{http_code}')"

  if [ "$status" = "429" ] && [ "$attempt" -lt 4 ]; then
    wait="$(grep -i '^retry-after:' "$headers" | tr -d '\r' | awk '{print $2}')"
    echo "rate limited, retrying in ${wait:-5}s" >&2
    sleep "${wait:-5}"
    continue
  fi
  break
done

if [ "$status" != "200" ]; then
  # Errors come back as {"errors":[{"code":"…","title":"…"}]}
  echo "error: HTTP $status $(cat "$OUT")" >&2
  rm -f "$OUT"
  exit 1
fi

h() { grep -i "^$1:" "$headers" | tr -d '\r' | awk '{print $2}'; }
echo "saved $OUT · $(h x-width)x$(h x-height) px · credits charged: $(h x-credits-charged) · type: $(h x-type)"
