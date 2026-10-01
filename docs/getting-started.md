# Getting started: account, API key, credits

Three steps, about five minutes. The first two are free.

## 1. Create a PixMiller account

Sign up at **[pixmiller.com/accounts/signup](https://pixmiller.com/accounts/signup/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=getting_started)**
with an email address or Google. If you sign up with email, confirm the address from the
message we send you.

The website and the API share one account and one credit balance.

## 2. Copy your API key

Open **[pixmiller.com/users/~api/](https://pixmiller.com/en/users/~api/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=getting_started)**
while signed in. Your key is created the first time you open the page. The same page has a
**Reset API Key** button. Resetting invalidates the old key at once.

Keep the key out of source control. Put it in an environment variable or your secret manager:

```bash
export PIXMILLER_API_KEY="paste-your-key-here"
```

Then check that the key works. This call is free:

```bash
curl -s "https://api.pixmiller.com/v1.0/account" -H "X-Api-Key: $PIXMILLER_API_KEY"
# {"data":{"attributes":{"credits":{"total":0,...},"api":{"free_calls":0,"sizes":"all"}}}}
```

A `403` with `invalid_api_key` means the key was copied incompletely or has been reset.

You can also run [`scripts/verify-key.sh`](../scripts/verify-key.sh). It checks the key and
makes one free preview call. It never spends a credit.

## 3. Buy credits (only for watermark-free results)

| Tier | Cost | Output |
|---|---|---|
| `size=preview` (default) | Free | Watermarked, up to 640 px |
| `size=auto`, `full`, `hd`, `4k`, `medium`, `50MP` | 1 credit per image | Full resolution, no watermark |

New accounts start with 0 credits. Free previews work right away, so you can wire up and
test your integration before you pay.

Buy credits on the **[pricing page](https://pixmiller.com/en/pricing/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=getting_started)**:

- **Pay as you go:** one-off credit packs. These credits **never expire**, renew nothing, and
  need no subscription.
- **Monthly subscription:** credits are delivered each month and are available for one month.
- Payment by card or PayPal (handled by Paddle), plus Alipay and WeChat Pay where available.
  Prices include VAT where applicable.

Credits appear on the same balance that `/v1.0/account` reports.

> [!TIP]
> Need an invoice, a larger volume or a higher rate limit than 40 images per minute?
> [Contact us](https://pixmiller.com/en/contact/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=getting_started).

## Next

- Change your code: [migration-guide.md](migration-guide.md) and the
  [examples](../examples/README.md).
- You use an SDK instead of raw HTTP: [client-libraries.md](client-libraries.md).
- Before you switch production traffic: [production-checklist.md](production-checklist.md).
