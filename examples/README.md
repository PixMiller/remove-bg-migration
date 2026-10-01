# Examples

Minimal, dependency-light clients for `POST https://api.pixmiller.com/v1.0/removebg`, the
remove.bg-compatible endpoint. They all work the same way:

```text
PIXMILLER_API_KEY=... <run> input.jpg [out.png]
```

| Variable | Default | Meaning |
|---|---|---|
| `PIXMILLER_API_KEY` | (required) | Your key from https://pixmiller.com/en/users/~api/ |
| `PIXMILLER_API_BASE` | `https://api.pixmiller.com` | Change it for tests or proxies |
| `PIXMILLER_SIZE` | `auto` | `preview` is free and watermarked; `auto` / `full` / `hd` / `4k` cost 1 credit |

Every example:

- uploads the file as multipart `image_file` with `size`;
- writes the returned bytes to the output file and prints `X-Width`, `X-Height`,
  `X-Credits-Charged` and `X-Type`;
- waits for `Retry-After` and retries on `429` (up to 3 times);
- on any other error, prints `HTTP <status> <errors[0].code>: <errors[0].title>` and exits 1.

| Directory | Runtime | Notes |
|---|---|---|
| [`curl/`](curl) | bash + curl | `remove-background.sh`, `account.sh` |
| [`python/`](python) | Python 3.9+, `pip install requests` | single image, batch folder, PyPI `removebg` SDK patch |
| [`node/`](node) | Node.js 18+ | no dependencies (built-in `fetch`) |
| [`php/`](php) | PHP 7.4+ with ext-curl | |
| [`go/`](go) | Go 1.20+ | `go run . in.jpg out.png` from that folder |
| [`ruby/`](ruby) | Ruby 2.7+ | standard library only |
| [`java/`](java) | Java 11+ | `java RemoveBackground.java in.jpg out.png` (single-file launch) |

Test them all without a key, against a local stub of the API contract:

```bash
./tests/run-examples.sh               # every runtime found on PATH
ONLY="python node" ./tests/run-examples.sh
```

To try the real API for free, set `PIXMILLER_SIZE=preview`. You get a watermarked preview and
no credit is charged.

Sample photo: https://pixmiller.com/static/img/demo/2-photo.webp
