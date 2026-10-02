# Production checklist

A safe way to move live traffic from remove.bg to PixMiller before **1 December 2026**,
when remove.bg's self-service API stops accepting requests.

## 1. Find every call site

```bash
# From the root of your codebase
bash <(curl -fsSL https://raw.githubusercontent.com/PixMiller/remove-bg-migration/main/scripts/find-removebg-usages.sh)
# or, after cloning this repo:
./scripts/find-removebg-usages.sh /path/to/your/project
```

The script lists hard-coded `api.remove.bg` URLs, remove.bg SDK imports, `X-Api-Key` headers
and `REMOVE_BG`-style environment variables. Check config files, infrastructure code and
no-code automations too (Zapier, Make, n8n). The script cannot see those.

## 2. Make the endpoint configurable

Do not swap one hard-coded URL for another. Read the base URL and the key from configuration,
so you can switch, and switch back, without a deploy:

```bash
REMOVE_BG_API_BASE=https://api.pixmiller.com     # was https://api.remove.bg
REMOVE_BG_API_KEY=<your PixMiller key>
```

## 3. Set `size` on every call

The default `size` (`preview`, and its aliases `small` / `regular`) returns a **watermarked**
image of up to 640 px on PixMiller. Send `size=auto` for full resolution while credits last,
or a fixed paid tier (`full`, `hd`, `4k`, `medium`, `50MP`). With `auto`, check
`X-Credits-Charged`: a value of `0` means you received a preview because the balance ran out.

## 4. Handle the differences

- [ ] **Rate limit: 40 images/min per key** (remove.bg allows 500). Throttle batch jobs and
      retry `429` after `Retry-After`. See
      [`examples/python/batch_remove_bg.py`](../examples/python/batch_remove_bg.py).
- [ ] **Input size: 20 MB** (remove.bg: 22 MB). Reject or downscale larger files first.
- [ ] **No free monthly calls.** `free_calls` is always `0`. Previews are free without a quota.
- [ ] **Shadows and semitransparency are not rendered.** If you relied on `add_shadow` for
      car photos, add the shadow yourself.
- [ ] **`X-Type` is a coarse class** (`person`, `product`, `animal`, `car`, `other`).
- [ ] **Calling from a browser?** It works (CORS is enabled; see
      [Calling from a browser](migration-guide.md#calling-from-a-browser)), but never ship your
      key in public front-end code. Route calls through your backend, or let users enter their
      own key.
- [ ] **`402 insufficient_credits`:** alert on it. Also alert on a low balance from
      `GET /v1.0/account`, so paid jobs do not stall.

## 5. Test without spending credits

- `GET /v1.0/account` is free. It confirms the key.
- `size=preview` is free. It confirms the whole request path, including your multipart or
  JSON encoding and your error handling.
- Then make **one** paid call (`size=auto`) and check `X-Credits-Charged: 1`, the output
  dimensions and the transparency.

[`scripts/verify-key.sh`](../scripts/verify-key.sh) runs the free checks.
[`scripts/smoke-test.sh`](../scripts/smoke-test.sh) adds the single paid call when you pass
`--paid`.

## 6. Roll out gradually

1. Send a small share of traffic, or one queue, to PixMiller and compare results side by side.
2. Watch the error rate by `errors[0].code`, latency, `X-Credits-Charged` and the balance.
3. Move the rest. Keep the remove.bg configuration until 30 November in case you need to roll
   back. After 1 December there is nothing to roll back to.

## 7. Clean up

- Remove the old remove.bg key from your secret store.
- Delete SDK patches or monkeypatches once your code calls the HTTP endpoint directly.
- Use any remaining remove.bg pay-as-you-go credits before 1 December. remove.bg says unused
  pay-as-you-go credits expire when the site closes.
