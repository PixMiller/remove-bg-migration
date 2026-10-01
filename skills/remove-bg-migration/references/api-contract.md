# PixMiller remove.bg-compatible API: contract

Source of truth: https://pixmiller.com/en/api-docs/remove-bg-migration/ (checked 2026-10-01).

## Endpoints

| | URL | Cost |
|---|---|---|
| Remove background | `POST https://api.pixmiller.com/v1.0/removebg` | `preview` free, paid tiers 1 credit/image |
| Account | `GET https://api.pixmiller.com/v1.0/account` | free |

Auth: header `X-Api-Key: <key>`. The body may be multipart, form-urlencoded or JSON.

## Parameters

| Parameter | Status | Notes |
|---|---|---|
| `image_file` / `image_url` / `image_file_b64` | same | JPG/PNG/WebP, max **20 MB** (remove.bg 22 MB) |
| `size` | **different** | see below; default `preview` |
| `format` | same | `auto`/`png`/`jpg`/`webp`/`zip` (zip = `color.jpg` + `alpha.png`); PNG capped at 10 MP |
| `type`, `type_level` | different | accepted; `X-Type` is coarse: person/product/animal/car/other |
| `crop`, `crop_margin`, `roi`, `scale`, `position`, `channels` | same | same syntax and caps as remove.bg |
| `bg_color` | same | hex with or without `#` (3/4/6/8 digits) or colour name |
| `bg_image_file`, `bg_image_url` | same | cover + centred; not combinable with `bg_color` |
| `add_shadow`, `shadow_type`, `shadow_opacity`, `semitransparency` | **no effect** | validated, never rendered |

Invalid values return `400 invalid_parameter`. They are never ignored silently.

## size

| Sent | Result | Credits |
|---|---|---|
| `preview` / `small` / `regular` (default) | **watermarked**, ≤ 640 px | 0 |
| `medium` / `hd` / `4k` / `full` / `50MP` | full resolution, no watermark, tier cap 1.5/4/25/25/50 MP | 1 |
| `auto` | full while credits remain, otherwise preview | 1 or 0 |

## Response

- `200` with the image bytes. `Content-Type` follows the format.
- `Accept: application/json` returns `{"data":{"result_b64":"…","foreground_top":…,…}}`.
- Headers: `X-Credits-Charged`, `X-Width`, `X-Height`, `X-Type`,
  `X-Foreground-Top/-Left/-Width/-Height`, `X-RateLimit-Limit/-Remaining/-Reset`, and
  `Retry-After` on 429.
- The credit is charged only after the result is fetched. A failed call costs nothing.

## Errors: `{"errors":[{"code":"…","title":"…"}]}`

| Status | code |
|---|---|
| 400 | `invalid_parameter`, `file_too_large`, `unknown_foreground` |
| 402 | `insufficient_credits` (nothing charged) |
| 403 | `auth_failed` (no key) / `invalid_api_key` (wrong key) |
| 429 | `rate_limit_exceeded`, honour `Retry-After` |
| 502 | `result_fetch_failed` (nothing charged, retry) |

## Account response

```json
{"data":{"attributes":{"credits":{"total":200,"subscription":0,"payg":200,"enterprise":0},
                       "api":{"free_calls":0,"sizes":"all"}}}}
```

## Limits and billing

- 40 images per minute per key (remove.bg: 500). One call is one image.
- No free monthly HD calls (`free_calls` is always 0). Preview is free with no quota.
- Pay-as-you-go credits never expire. Subscription credits last one month. The website and the
  API share one balance.
- Card, PayPal, Alipay, WeChat Pay. Prices: https://pixmiller.com/en/pricing/

## Not the same as PixMiller's native API

`POST /v1/remove` is a different endpoint: it returns `201` with `{"url": …}`. When migrating
from remove.bg, always use `/v1.0/removebg`.
