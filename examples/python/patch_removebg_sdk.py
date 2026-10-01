"""Keep using the PyPI `removebg` package, pointed at PixMiller.

    pip install removebg
    PIXMILLER_API_KEY=... python patch_removebg_sdk.py product.jpg

The package reads the module constant `removebg.removebg.API_ENDPOINT` on every call, so one
assignment at startup redirects it. Tested with removebg 0.4 (published as "0.04"). This is a
convenience for existing code; new code should call the HTTP API directly (remove_background.py).
"""

import os
import sys

import removebg.removebg as removebg_module
from removebg import RemoveBg

removebg_module.API_ENDPOINT = os.environ.get("PIXMILLER_API_BASE", "https://api.pixmiller.com") + "/v1.0/removebg"


def main() -> int:
    api_key = os.environ.get("PIXMILLER_API_KEY")
    if not api_key or len(sys.argv) < 2:
        print(f"usage: PIXMILLER_API_KEY=... {sys.argv[0]} input-image", file=sys.stderr)
        return 2

    rmbg = RemoveBg(api_key, "removebg-errors.log")
    # The package defaults to size="regular", which is the FREE WATERMARKED preview on PixMiller.
    # Always pass a paid tier (or "auto") when you need the watermark-free result.
    try:
        rmbg.remove_background_from_img_file(sys.argv[1], size=os.environ.get("PIXMILLER_SIZE", "auto"))
    except Exception as exc:  # the package raises requests.HTTPError on 4xx/5xx
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(f"saved {sys.argv[1]}_no_bg.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
