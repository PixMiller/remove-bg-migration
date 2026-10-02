# remove.bg API → PixMiller: full migration reference

This is the complete contract of PixMiller's remove.bg-compatible endpoint. Read the
[four caveats](#read-this-first) before you change any code. Everything below mirrors the
official guide at
[pixmiller.com/api-docs/remove-bg-migration](https://pixmiller.com/en/api-docs/remove-bg-migration/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=guide);
if the two ever disagree, the website is the source of truth. Please
[open an issue](https://github.com/PixMiller/remove-bg-migration/issues) so we can fix this copy.

- [Read this first](#read-this-first)
- [Endpoints](#endpoints)
- [Before and after](#before-and-after)
- [Request parameters](#request-parameters)
- [The `size` parameter](#the-size-parameter)
- [Response](#response)
- [Response headers](#response-headers)
- [Errors](#errors)
- [Account endpoint](#account-endpoint)
- [Rate limit](#rate-limit)
- [Calling from a browser](#calling-from-a-browser)
- [Credits and billing](#credits-and-billing)
- [Summary of differences](#summary-of-differences)

## Read this first

1. **`size` defaults to `preview`, as on remove.bg, but our preview is different.** Here it
   is a free, **watermarked** image up to 640 px. remove.bg's preview is 0.25 megapixels
   without a watermark. An integration that never sets `size` will get watermarked
   previews. Pass `size=auto` or a paid tier to get the watermark-free result.
2. **We do not claim SDK-level compatibility.** Three third-party clients passed our tests on
   22 September 2026: the PyPI `removebg` package, the official npm `remove.bg` package and
   `removebg-cli`. We do not regression-test them release by release. Hand-written HTTP clients
   are the path we support. See [client-libraries.md](client-libraries.md).
3. **`shadow_type`, `shadow_opacity`, `add_shadow` and `semitransparency` have no effect.**
   We accept and validate them, but they never change the output. remove.bg behaves the same
   way for subjects that are not cars. There is no car-specific model.
4. **The limit is 40 images per minute per key** (remove.bg allows 500). Each call counts as
   one image. Handle `429` with `Retry-After`, or
   [contact us](https://pixmiller.com/en/contact/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=rate_limit)
   to raise the limit.

## Endpoints

| | remove.bg | PixMiller |
|---|---|---|
| Remove background | `POST https://api.remove.bg/v1.0/removebg` | `POST https://api.pixmiller.com/v1.0/removebg` |
| Account / balance | `GET https://api.remove.bg/v1.0/account` | `GET https://api.pixmiller.com/v1.0/account` |
| Auth | `X-Api-Key: <key>` | `X-Api-Key: <key>`, the same header |
| Request body | multipart, form-urlencoded or JSON | multipart, form-urlencoded or JSON |

## Before and after

```bash
# remove.bg
curl -X POST "https://api.remove.bg/v1.0/removebg" \
  -H "X-Api-Key: REMOVEBG_KEY" \
  -F "image_file=@product.jpg" \
  -F "size=auto" \
  -o out.png
```

```bash
# PixMiller
curl -X POST "https://api.pixmiller.com/v1.0/removebg" \
  -H "X-Api-Key: PIXMILLER_KEY" \
  -F "image_file=@product.jpg" \
  -F "size=auto" \
  -o out.png
# 200 OK → image bytes, written straight to out.png
# X-Credits-Charged: 1   X-Width: 1200   X-Height: 1600   X-Type: product
```

The path, the header name and the form fields stay the same. In most hand-written clients the
only changes are the base URL and the key.

## Request parameters

We validate every parameter against remove.bg's own value ranges. An invalid value returns
`400 invalid_parameter`; it is never silently ignored. remove.bg answers the same way.

| Parameter | Status | Notes |
|---|---|---|
| `image_file` | ✅ same | Multipart upload. JPG / PNG / WebP, up to 20 MB (remove.bg: 22 MB). |
| `image_url` | ✅ same | Public image URL. We fetch it on our side with the same 20 MB limit. |
| `image_file_b64` | ✅ same | Base64-encoded image in the request body, as on remove.bg. |
| `size` | ⚠️ different | Same values, same default (`preview`) and same megapixel caps. But `preview` is a free watermarked image up to 640 px, not 0.25 MP without watermark. `medium` / `hd` / `4k` / `full` / `50MP` cost 1 credit each. `auto` uses the paid tier while credits remain. [Details](#the-size-parameter). |
| `format` | ✅ same | `auto` / `png` / `jpg` / `webp` / `zip`. `zip` contains `color.jpg` and `alpha.png`, as on remove.bg. `Accept: application/json` returns the base64 envelope. PNG output is capped at 10 megapixels. |
| `type`, `type_level` | ⚠️ different | Accepted. `type` is mapped onto our own models. `X-Type` reports a coarse class: `person`, `product`, `animal`, `car` or `other`. `type_level=2` and `latest` return the same coarse classes. |
| `crop`, `crop_margin` | ✅ same | Crops to the subject. Same margin syntax, same 50% / 500 px cap. |
| `roi` | ✅ same | Region of interest in pixels or percent, as on remove.bg. |
| `scale`, `position` | ✅ same | Subject scale (10%–100% or `original`) and position, as on remove.bg. |
| `channels` | ✅ same | `rgba` (default), or `alpha` for the mask only. |
| `bg_color` | ✅ same | Transparent by default. 3 / 4 / 6 / 8-digit hex with or without `#`, or a colour name. |
| `bg_image_file`, `bg_image_url` | ✅ same | Scaled to cover the output and centred. Cannot be combined with `bg_color`. |
| `add_shadow`, `shadow_type`, `shadow_opacity` | ⛔ no effect | Validated against remove.bg's values, but no shadow is ever rendered. |
| `semitransparency` | ⛔ no effect | Accepted. Semi-transparent areas are always handled automatically. |

## The `size` parameter

| You send | We use | What you get |
|---|---|---|
| `preview` / `small` / `regular` | preview | Watermarked preview, up to 640 px. Free, no credit charged. This is the default, as on remove.bg. |
| `medium` / `hd` / `4k` / `full` / `50MP` | full | Full-resolution, watermark-free result, downscaled to the tier's megapixel cap (1.5 / 4 / 25 / 25 / 50 MP; PNG output is capped at 10 MP). 1 credit per image. |
| `auto` | auto | Full resolution while credits are available, free watermarked preview otherwise. |

> [!IMPORTANT]
> `regular` is an alias of `preview` here, and it is the default of the PyPI `removebg`
> package. If you keep the SDK defaults you get watermarked previews. Set `size` explicitly.

## Response

- **Status `200 OK`** with the image bytes in the body, the same as remove.bg. Code that
  checks for `200` keeps working.
- `Content-Type` follows the output format (`image/png`, `image/jpeg`, `image/webp` or
  `application/zip`).
- Send `Accept: application/json` (or `format=json`) to get remove.bg's base64 envelope:

  ```json
  {
    "data": {
      "result_b64": "iVBORw0KGgo…",
      "foreground_top": 0,
      "foreground_left": 0,
      "foreground_width": 1200,
      "foreground_height": 1600
    }
  }
  ```

> [!NOTE]
> PixMiller also has its own native endpoint, `POST /v1/remove`, which answers `201` with JSON
> (`{"url": "…"}`). The compatibility path `/v1.0/removebg` does **not** do that on purpose.
> Use `/v1.0/removebg` when you migrate from remove.bg.

## Response headers

| Header | Meaning |
|---|---|
| `X-Credits-Charged` | Credits actually deducted by this call (`0` for the free preview tier). |
| `X-Width` / `X-Height` | Pixel dimensions of the returned image. |
| `X-Type` | Detected foreground class: `person`, `product`, `animal`, `car` or `other` (omitted with `type_level=none`). |
| `X-Foreground-Top` / `-Left` / `-Width` / `-Height` | Bounding box of the subject in the returned image. |
| `X-RateLimit-Limit` / `-Remaining` / `-Reset` | Rate-limit state for your key, counted per image. One call uses one unit. `Retry-After` is added on `429`. |

## Errors

Errors use remove.bg's JSON:API shape. It is an array, so `errors[0].title` reads the same as
before:

```json
{"errors": [{"code": "auth_failed", "title": "Missing API Key"}]}
```

| Status | `errors[0].code` | When |
|---|---|---|
| 400 | `invalid_parameter` | A value outside remove.bg's range for size / format / crop / scale / … or a missing image source. The title names the parameter. |
| 400 | `file_too_large` | The input image exceeds 20 MB. |
| 400 | `unknown_foreground` | No foreground could be found in the image. |
| 402 | `insufficient_credits` | A paid tier was requested but the balance is empty. Nothing is charged. |
| 403 | `auth_failed` / `invalid_api_key` | The `X-Api-Key` header is missing (`auth_failed`) or wrong (`invalid_api_key`). `403`, as on remove.bg, not `401`. |
| 429 | `rate_limit_exceeded` | Rate limit exceeded. Retry after the `Retry-After` header. |
| 502 | `result_fetch_failed` | The result could not be fetched from storage. Nothing was charged; retry the request. |

The status code carries the meaning and `code` uses remove.bg's own vocabulary, so a `switch`
on `errors[0].code` keeps working.

## Account endpoint

```bash
curl "https://api.pixmiller.com/v1.0/account" -H "X-Api-Key: PIXMILLER_KEY"
```

```json
{
  "data": {
    "attributes": {
      "credits": {"total": 200, "subscription": 0, "payg": 200, "enterprise": 0},
      "api": {"free_calls": 0, "sizes": "all"}
    }
  }
}
```

The balance sits under `data.attributes.credits`, so a balance check written against
remove.bg keeps its shape. There is no monthly free quota, so `free_calls` is always `0`.
Calling `/v1.0/account` is free. It is the safest way to check that a new key works.

## Rate limit

- **40 images per minute per key.** remove.bg allows 500.
- Each call to `/v1.0/removebg` counts as one image. `X-RateLimit-Limit`, `-Remaining` and
  `-Reset` report that per-image budget.
- On `429 rate_limit_exceeded`, wait for the number of seconds in `Retry-After`, then retry.
  [`examples/python/batch_remove_bg.py`](../examples/python/batch_remove_bg.py) shows a
  batch runner that stays under the limit.
- Need more? [Contact us](https://pixmiller.com/en/contact/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=rate_limit).

## Calling from a browser

`https://api.pixmiller.com/v1.0/*` (and `/v1/*`) can be called straight from a web page, a
browser extension or a plugin sandbox (Figma, Obsidian and similar):

- **Any `Origin` is allowed, and cookies are not used.** Authentication is only the
  `X-Api-Key` header, so do not send `credentials: "include"`.
- The preflight (`OPTIONS`) allows `GET` and `POST`, and the request headers `x-api-key`,
  `content-type` and `accept`. That covers multipart uploads, JSON bodies, the
  `Accept: application/json` envelope and `GET /v1.0/account`.
- The response headers are readable through `resp.headers.get(...)`: `X-Credits-Charged`,
  `X-Width`, `X-Height`, `X-Type`, `X-Foreground-Top` / `-Left` / `-Width` / `-Height`,
  `X-RateLimit-Limit` / `-Remaining` / `-Reset` and `Retry-After`.
- Error responses (`400`, `402`, `403`, `429`, …) carry the same CORS headers, so a page can
  read `errors[0].code`.

```js
// Browser: `apiKey` comes from the user (see the warning below); `file` is a File from <input type="file">.
async function removeBackground(apiKey, file) {
  const form = new FormData();
  form.append("image_file", file);
  form.append("size", "auto");

  const resp = await fetch("https://api.pixmiller.com/v1.0/removebg", {
    method: "POST",
    headers: { "X-Api-Key": apiKey }, // do not set Content-Type: the browser adds the multipart boundary
    body: form,
  });

  if (!resp.ok) {
    const { errors } = await resp.json(); // same envelope as on remove.bg
    const retryAfter = resp.headers.get("Retry-After"); // set on 429
    throw Object.assign(new Error(errors[0].title), { code: errors[0].code, retryAfter });
  }

  console.log("charged:", resp.headers.get("X-Credits-Charged")); // "0" = you got a preview
  return URL.createObjectURL(await resp.blob()); // use as <img src>
}
```

> [!WARNING]
> **Do not put your API key in public front-end code.** Anything shipped to a browser (a web
> page, a front-end bundle in a public repository) can be read by every visitor, and anyone
> who copies the key can spend your credits. Use one of these instead:
>
> - **Your own backend.** The browser calls your server, and your server calls PixMiller with
>   the key from an environment variable or secret store. Use this for any public site or app.
> - **Bring your own key (BYO-key).** The user pastes their own PixMiller key into your Figma
>   plugin, browser extension or desktop plugin, and you keep it in that tool's local storage.
>   Each user spends their own credits, and nothing of yours is exposed.

## Credits and billing

- `preview` is free. Every paid tier costs **1 credit per image**.
- A credit is charged only after the result has been fetched. A failed call never costs a
  credit.
- **Pay-as-you-go credits never expire.** There is no monthly reset, and you do not need a
  subscription. Subscription credits are also available.
- Buy credits on the [pricing page](https://pixmiller.com/en/pricing/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=guide).
  The API and the website share one balance.
- Card, PayPal, Alipay and WeChat Pay are supported where available.

## Summary of differences

| Topic | Same as remove.bg | Different |
|---|---|---|
| Path, auth header, form field names | ✅ | |
| Status code (`200` + image bytes) | ✅ | |
| JSON envelope via `Accept: application/json` | ✅ | |
| Error envelope and error codes | ✅ | |
| `X-*` response headers | ✅ | `X-Type` is a coarse class |
| Default `size` | ✅ `preview` | Our preview is watermarked, up to 640 px, free |
| Paid tiers | ✅ 1 credit each | No 0.25-credit preview tier |
| Free monthly API calls | | None (`free_calls` is always 0) |
| Shadows, semitransparency | | Accepted, never rendered |
| Max input size | | 20 MB (remove.bg: 22 MB) |
| Rate limit | | 40 images/min per key (remove.bg: 500) |
| Official SDKs / CLI | | Tested once on 2026-09-22, not guaranteed release by release |
