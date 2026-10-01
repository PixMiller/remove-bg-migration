"""Remove the background of one image through PixMiller's remove.bg-compatible API.

    pip install requests
    PIXMILLER_API_KEY=... python remove_background.py product.jpg [out.png]

Env: PIXMILLER_API_BASE (default https://api.pixmiller.com), PIXMILLER_SIZE (default auto).
Migrating from remove.bg? The only changes are API_BASE and the key.
"""

import os
import sys
import time

import requests

API_BASE = os.environ.get("PIXMILLER_API_BASE", "https://api.pixmiller.com")  # was https://api.remove.bg
API_KEY = os.environ.get("PIXMILLER_API_KEY")
SIZE = os.environ.get("PIXMILLER_SIZE", "auto")  # preview/small/regular = free, watermarked


def remove_background(path: str, size: str = SIZE, max_retries: int = 3) -> requests.Response:
    for attempt in range(max_retries + 1):
        with open(path, "rb") as image:
            resp = requests.post(
                f"{API_BASE}/v1.0/removebg",
                headers={"X-Api-Key": API_KEY},
                files={"image_file": image},
                data={"size": size},
                timeout=120,
            )
        if resp.status_code == 429 and attempt < max_retries:
            wait = int(resp.headers.get("Retry-After", "5"))
            print(f"rate limited, retrying in {wait}s", file=sys.stderr)
            time.sleep(wait)
            continue
        return resp
    return resp


def main() -> int:
    if not API_KEY:
        print("Set PIXMILLER_API_KEY (https://pixmiller.com/en/users/~api/)", file=sys.stderr)
        return 2
    if len(sys.argv) < 2:
        print(f"usage: {sys.argv[0]} input-image [output.png]", file=sys.stderr)
        return 2
    out = sys.argv[2] if len(sys.argv) > 2 else "out.png"

    resp = remove_background(sys.argv[1])
    if resp.status_code != 200:
        # Same envelope as remove.bg: {"errors": [{"code": "...", "title": "..."}]}
        try:
            error = resp.json()["errors"][0]
            print(f"error: HTTP {resp.status_code} {error.get('code')}: {error.get('title')}", file=sys.stderr)
        except (ValueError, KeyError, IndexError):
            print(f"error: HTTP {resp.status_code} {resp.text[:200]}", file=sys.stderr)
        return 1

    with open(out, "wb") as f:
        f.write(resp.content)
    h = resp.headers
    print(
        f"saved {out} · {h.get('X-Width')}x{h.get('X-Height')} px · "
        f"credits charged: {h.get('X-Credits-Charged')} · type: {h.get('X-Type')}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
