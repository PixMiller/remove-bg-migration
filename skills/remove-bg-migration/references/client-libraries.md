# remove.bg client libraries and no-code tools

Tested against PixMiller on 2026-09-22. They are not regression-tested after that, so verify
with `size=preview` after any change.

## PyPI `removebg` (0.4, published as "0.04")

```python
import removebg.removebg as _rb
from removebg import RemoveBg

_rb.API_ENDPOINT = "https://api.pixmiller.com/v1.0/removebg"   # read at call time
RemoveBg(os.environ["PIXMILLER_API_KEY"], "errors.log").remove_background_from_img_file(path, size="auto")
```

- The default `size="regular"` is the **watermarked preview**. Always pass `size`.
- The package calls `raise_for_status()`, so errors surface as `requests.HTTPError`.

## npm `remove.bg` (1.3.0)

- The endpoint is `const API_ENDPOINT` in `dist/index.js`. No option or environment variable
  changes it.
- Preferred fix: replace the calls with `fetch` (Node 18+):

```js
const form = new FormData();
form.append("image_file", new Blob([await fs.promises.readFile(path)]), "image.jpg");
form.append("size", "auto");
const resp = await fetch("https://api.pixmiller.com/v1.0/removebg", {
  method: "POST", headers: { "X-Api-Key": process.env.PIXMILLER_API_KEY }, body: form,
});
if (!resp.ok) throw new Error((await resp.json()).errors?.[0]?.code);
await fs.promises.writeFile(out, Buffer.from(await resp.arrayBuffer()));
```

- Alternative: `sed` the URL in `node_modules/remove.bg/dist/index.js`, then
  `npx patch-package remove.bg`.
- The default `size: "preview"` is the watermarked preview. Pass `size: "auto"`.

## `removebg-cli` (PyPI 1.0.0)

The key comes from `REMOVE_BG_API_KEY`. The URLs are hard-coded in three places in
`removebg_cli.py`. Replace the CLI in scripts with:

```bash
curl -sS -X POST https://api.pixmiller.com/v1.0/removebg \
  -H "X-Api-Key: $PIXMILLER_API_KEY" -F "image_file=@in.jpg" -F "size=auto" -o out.png
```

## Other wrappers (Ruby, PHP, Laravel, WordPress, Go, …)

These are untested. If the wrapper has a base-URL or host option, set it to
`https://api.pixmiller.com`. Otherwise replace the wrapper with an HTTP call. Always set `size`.

## Zapier, Make, n8n, Pipedream

The built-in remove.bg apps cannot be repointed. Use the generic HTTP step:

- `POST https://api.pixmiller.com/v1.0/removebg`
- header `X-Api-Key`
- multipart body `image_url` (or `image_file`) plus `size=auto`
- the response is binary, or JSON with `result_b64` when you send `Accept: application/json`
