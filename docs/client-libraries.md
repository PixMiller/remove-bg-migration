# Using remove.bg client libraries with PixMiller

**The short answer:** if a library lets you set the base URL, point it at
`https://api.pixmiller.com` and set `size` explicitly. If it does not, replace it with the
plain HTTP call from [`examples/`](../examples/README.md). That call is about 20 lines in any
language, and it is the path we support.

We tested the three most-used third-party clients against our compatibility endpoint on
**22 September 2026**. All three passed their main paths. We do **not** re-test them on every
release, and they may change. Treat this page as a starting point, not a guarantee.

| Library | Version tested | Can the endpoint be changed? | Default `size` | Result |
|---|---|---|---|---|
| PyPI [`removebg`](https://pypi.org/project/removebg/) | 0.4 (`0.04`) | Yes, module constant at runtime | `regular` (= watermarked preview) | ✅ file / URL / base64, `bg_color`, `403` on a bad key |
| npm [`remove.bg`](https://www.npmjs.com/package/remove.bg) | 1.3.0 | No, hard-coded `const`; patch the file | `preview` (watermarked) | ✅ file / URL / base64, headers parsed, errors rejected correctly |
| PyPI [`removebg-cli`](https://pypi.org/project/removebg-cli/) | 1.0.0 | No, three hard-coded URLs | `auto` | ✅ account panel, preview, full, zip, webp, URL source, `-b 81d4fa` |

> [!WARNING]
> Both SDKs default to the free **watermarked** preview tier on PixMiller. Pass
> `size="auto"` (or `full`, `hd`, `4k`) on every call where you want a watermark-free image.

## Python: `removebg` (PyPI)

The library reads the module-level constant `removebg.removebg.API_ENDPOINT` on every call,
so you can override it once at startup:

```python
import os
import removebg.removebg as _removebg_module
from removebg import RemoveBg

_removebg_module.API_ENDPOINT = "https://api.pixmiller.com/v1.0/removebg"

rmbg = RemoveBg(os.environ["PIXMILLER_API_KEY"], "removebg-errors.log")
rmbg.remove_background_from_img_file("product.jpg", size="auto")  # writes product.jpg_no_bg.png
```

Notes:

- `size="regular"` is the library default. On PixMiller that is the watermarked preview.
- The library calls `raise_for_status()` before it reads the error body, so a `402` or `403`
  surfaces as `requests.HTTPError`. It also behaves this way against remove.bg.

A runnable version is in [`examples/python/patch_removebg_sdk.py`](../examples/python/patch_removebg_sdk.py).

## Node.js: `remove.bg` (npm)

Version 1.3.0 hard-codes the endpoint as a `const` in `dist/index.js`, and nothing reads an
environment variable. You have two options.

**Option A (recommended): replace the library.** The library is a thin wrapper.
[`examples/node/remove-background.mjs`](../examples/node/remove-background.mjs) does the same
job with Node 18+'s built-in `fetch` and has no dependencies.

**Option B: patch the installed package** with
[patch-package](https://www.npmjs.com/package/patch-package), so the change survives
`npm install`:

```bash
sed -i.bak 's#https://api.remove.bg/v1.0/removebg#https://api.pixmiller.com/v1.0/removebg#' \
  node_modules/remove.bg/dist/index.js
npx patch-package remove.bg
```

Then pass the PixMiller key as `apiKey` and set `size: "auto"`:

```js
const { removeBackgroundFromImageFile } = require("remove.bg");

const result = await removeBackgroundFromImageFile({
  path: "product.jpg",
  apiKey: process.env.PIXMILLER_API_KEY,
  size: "auto",
  outputFile: "out.png",
});
console.log(result.creditsCharged, result.resultWidth, result.resultHeight);
```

The library always sends `Accept: application/json` and decodes `data.result_b64`. PixMiller
returns the same envelope. `creditsCharged`, `detectedType`, `rateLimit*` and `retryAfter` are
filled from our response headers.

## CLI: `removebg-cli` (PyPI)

The CLI reads the key from `REMOVE_BG_API_KEY`, but `https://api.remove.bg/...` is hard-coded
in three places in `removebg_cli.py`. To repoint it, edit the installed file:

```bash
FILE="$(python3 -c 'import removebg_cli; print(removebg_cli.__file__)')"
sed -i.bak 's#https://api.remove.bg/v1.0/#https://api.pixmiller.com/v1.0/#g' "$FILE"
export REMOVE_BG_API_KEY="$PIXMILLER_API_KEY"
removebg product.jpg -s auto
```

Reinstalling the package undoes the edit. For scripts and CI, the
[curl example](../examples/curl/remove-background.sh) is easier to maintain.

## Other libraries and no-code tools

We have not tested other wrappers: Ruby gems, PHP or Laravel packages, WordPress plugins,
Go modules, and so on. For each one:

1. Look for a base-URL, endpoint or host option. If there is one, set it to
   `https://api.pixmiller.com` (the path `/v1.0/removebg` stays the same).
2. Otherwise replace the wrapper with the HTTP call from [`examples/`](../examples/README.md).
3. Always set `size` explicitly, and run [`scripts/verify-key.sh`](../scripts/verify-key.sh)
   before the first paid call.

**Zapier, Make, n8n, Pipedream:** their built-in remove.bg apps call remove.bg directly, and
you cannot repoint them. Use the platform's generic HTTP step instead (Zapier "Webhooks",
Make "HTTP", n8n "HTTP Request"):

| Field | Value |
|---|---|
| Method | `POST` |
| URL | `https://api.pixmiller.com/v1.0/removebg` |
| Header | `X-Api-Key: <your PixMiller key>` |
| Body | multipart form: `image_url` (or `image_file`), `size=auto` |
| Response | binary image (or JSON with `result_b64` if you send `Accept: application/json`) |

Did you get another library working? A pull request that adds it to this page is welcome.
