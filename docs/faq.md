# FAQ

### Is remove.bg really shutting down?

Yes. remove.bg's site banner says its background removal is moving to Canva, and that the
standalone website will no longer be available from **1 December 2026 at 09:00 CET**. Its API
page says that from the same date, background removal moves to Leonardo.Ai, which is also part
of Canva. See [remove.bg](https://www.remove.bg/) and [remove.bg/api](https://www.remove.bg/api).

### What happens to my unused remove.bg credits?

remove.bg says unused pay-as-you-go credits expire when the site closes. Refunds are only
handled under its general 14-day policy, and annual subscriptions are refunded pro rata. Check
remove.bg's FAQ and terms for your own case.

### Will the remove.bg API keep working?

The self-service API stops accepting requests on 1 December 2026. remove.bg points those users
to Leonardo.Ai, whose own migration guide says code changes are required (a new endpoint,
Bearer auth and a JSON-only request body). remove.bg says Enterprise API contracts are not
affected.

### Can I move to PixMiller without rewriting my integration?

If you call the API with your own HTTP code, the usual change is the base URL and the API key.
PixMiller accepts `POST /v1.0/removebg` with the same `X-Api-Key` header and the same
`image_file` / `image_url` / `size` / `format` / `bg_color` names, and answers `200` with the
image bytes. Three third-party clients passed our tests, but we do not claim SDK-level
compatibility release by release. The default size returns a watermarked preview, shadow
parameters have no effect, and the rate limit is lower. [All differences](migration-guide.md#summary-of-differences).

### Can I call the API from a browser, a Figma plugin or a browser extension?

Yes. `api.pixmiller.com` allows cross-origin calls from any origin, without cookies, and
exposes the `X-Credits-Charged`, `X-Width`, `X-Height`, `X-Type`, `X-Foreground-*`,
`X-RateLimit-*` and `Retry-After` headers to your script. Error responses are readable too.
Do not ship your own key in public front-end code, because anyone can copy it and spend your
credits. Call through your own backend, or ask each user for their own key (as a Figma
plugin or extension would). A `fetch` example is in
[Calling from a browser](migration-guide.md#calling-from-a-browser).

### Why do I get a watermark?

You did not set `size`, or you set `preview`, `small` or `regular`. Those tiers are free and
watermarked on PixMiller. Send `size=auto` or a paid tier, and make sure the account has credits.

### How much does it cost?

`preview` is free. Every paid tier costs 1 credit per image, and a call that fails costs
nothing. Current prices are on the
[pricing page](https://pixmiller.com/en/pricing/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=faq).

### Do PixMiller credits expire?

Pay-as-you-go credits never expire. There is no monthly reset and no subscription is required:
you can buy a single pack and stop there. Subscription credits are delivered monthly and are
available for one month.

### Is there a free API quota?

There are no free monthly HD calls. The watermarked `preview` tier is free and has no quota,
so you can build and test an integration before you buy credits.

### What is the rate limit, and can it be raised?

40 images per minute per key. Each call counts as one image. If you need more,
[contact us](https://pixmiller.com/en/contact/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=faq).

### Which image formats and sizes are supported?

Input: JPG, PNG or WebP up to 20 MB. Output: PNG, JPG, WebP or ZIP (`color.jpg` +
`alpha.png`). PNG output is capped at 10 megapixels; other formats follow the tier's cap (up to
50 MP).

### Where are my images stored?

The processed image is stored temporarily, and the underlying file is deleted automatically
after 3 days. The compatibility endpoint returns the image bytes directly, so you do not need
to download anything from our storage.

### I don't write code. I just used the remove.bg website.

Use [pixmiller.com/remove-bg-alternative](https://pixmiller.com/en/remove-bg-alternative/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=faq)
for single images, and the
[batch background remover](https://pixmiller.com/en/remove-background/batch/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=faq)
for up to 50 images at a time (loose files or a ZIP, original file names kept).

### Is PixMiller affiliated with remove.bg, Canva or Leonardo.Ai?

No. Product names are used for identification only. Facts about those services are quoted
from their own public pages as of September 2026.
