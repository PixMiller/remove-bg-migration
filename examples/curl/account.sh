#!/usr/bin/env bash
# Show the credit balance of a PixMiller API key (free call).
#
#   PIXMILLER_API_KEY=... ./account.sh
set -euo pipefail

: "${PIXMILLER_API_KEY:?Set PIXMILLER_API_KEY (https://pixmiller.com/en/users/~api/)}"
BASE="${PIXMILLER_API_BASE:-https://api.pixmiller.com}"

curl -sS --fail-with-body "$BASE/v1.0/account" -H "X-Api-Key: $PIXMILLER_API_KEY"
echo
# {"data":{"attributes":{"credits":{"total":200,"subscription":0,"payg":200,"enterprise":0},
#                        "api":{"free_calls":0,"sizes":"all"}}}}
