#!/usr/bin/env bash
# Run every example against the local contract stub (tests/mock_server.py).
#
#   ./tests/run-examples.sh                # all languages found on PATH
#   ONLY="python node" ./tests/run-examples.sh
#
# Each example must: succeed with a valid key, survive one 429 (Retry-After) and still succeed,
# and exit non-zero printing the remove.bg error code for a wrong key.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8787}"
export PIXMILLER_API_BASE="http://127.0.0.1:$PORT"
work="$(mktemp -d)"
trap 'kill "$server" 2>/dev/null; wait "$server" 2>/dev/null; rm -rf "$work"' EXIT

python3 "$ROOT/tests/mock_server.py" "$PORT" &
server=$!
for _ in $(seq 50); do curl -s "$PIXMILLER_API_BASE/" >/dev/null 2>&1 && break; sleep 0.1; done

printf 'fake image bytes' >"$work/in.jpg"
mkdir -p "$work/batch-in" && cp "$work/in.jpg" "$work/batch-in/a.jpg" && cp "$work/in.jpg" "$work/batch-in/b.png"

# name | requirement | command (input/output appended)
EXAMPLES=(
  "curl|curl|bash $ROOT/examples/curl/remove-background.sh"
  "python|python3|python3 $ROOT/examples/python/remove_background.py"
  "node|node|node $ROOT/examples/node/remove-background.mjs"
  "php|php|php $ROOT/examples/php/remove-background.php"
  "go|go|go run $ROOT/examples/go/main.go"
  "ruby|ruby|ruby $ROOT/examples/ruby/remove_background.rb"
  "java|java|java $ROOT/examples/java/RemoveBackground.java"
)

FAILS=0
ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
ko() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAILS=$((FAILS + 1)); }
is_png() { [ "$(head -c 8 "$1" 2>/dev/null | od -An -tx1 | tr -d ' \n')" = "89504e470d0a1a0a" ]; }

for entry in "${EXAMPLES[@]}"; do
  IFS='|' read -r name need cmd <<<"$entry"
  if [ -n "${ONLY:-}" ] && [[ " $ONLY " != *" $name "* ]]; then continue; fi
  if ! command -v "$need" >/dev/null 2>&1; then echo "- $name: skipped ($need not installed)"; continue; fi
  echo "- $name"

  rm -f "$work/out.png"
  if out="$(PIXMILLER_API_KEY=test-key $cmd "$work/in.jpg" "$work/out.png" 2>&1)" && is_png "$work/out.png" &&
    grep -q "credits charged: 1" <<<"$out"; then
    ok "success → PNG written, credits charged reported"
  else
    ko "success path: $out"
  fi

  rm -f "$work/out.png"
  if out="$(PIXMILLER_API_KEY=ratelimit-key $cmd "$work/in.jpg" "$work/out.png" 2>&1)" && is_png "$work/out.png"; then
    ok "429 → waited for Retry-After and succeeded"
  else
    ko "429 retry: $out"
  fi

  if out="$(PIXMILLER_API_KEY=wrong-key $cmd "$work/in.jpg" "$work/out.png" 2>&1)"; then
    ko "wrong key should exit non-zero: $out"
  elif grep -q "invalid_api_key" <<<"$out"; then
    ok "wrong key → non-zero exit with invalid_api_key"
  else
    ko "wrong key error message: $out"
  fi
done

if [ -z "${ONLY:-}" ] || [[ " $ONLY " == *" python "* ]]; then
  echo "- python batch"
  if out="$(PIXMILLER_API_KEY=test-key python3 "$ROOT/examples/python/batch_remove_bg.py" "$work/batch-in" "$work/batch-out" 2>&1)" &&
    is_png "$work/batch-out/a.png" && is_png "$work/batch-out/b.png"; then
    ok "folder of 2 → 2 PNGs"
  else
    ko "batch: $out"
  fi
  if out="$(PIXMILLER_API_KEY=test-key python3 "$ROOT/examples/python/batch_remove_bg.py" "$work/batch-in" "$work/batch-out" 2>&1)" &&
    grep -q "already done" <<<"$out"; then
    ok "re-run skips finished images"
  else
    ko "batch re-run: $out"
  fi

  if python3 -c "import removebg" 2>/dev/null; then
    echo "- python removebg SDK (monkeypatched)"
    cp "$work/in.jpg" "$work/sdk.jpg"
    if out="$(PIXMILLER_API_KEY=test-key python3 "$ROOT/examples/python/patch_removebg_sdk.py" "$work/sdk.jpg" 2>&1)" &&
      is_png "$work/sdk.jpg_no_bg.png"; then
      ok "SDK request reached the overridden endpoint"
    else
      ko "SDK: $out"
    fi
  else
    echo "- python removebg SDK: skipped (pip install removebg)"
  fi
fi

echo "- curl account"
if out="$(PIXMILLER_API_KEY=test-key bash "$ROOT/examples/curl/account.sh" 2>&1)" && grep -q '"total"' <<<"$out"; then
  ok "account → credits.total"
else
  ko "account: $out"
fi

echo
if [ "$FAILS" -eq 0 ]; then echo "All example checks passed."; else echo "$FAILS check(s) failed."; exit 1; fi
