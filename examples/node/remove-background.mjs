// Remove the background of one image — Node.js 18+, no dependencies.
//
//   PIXMILLER_API_KEY=... node remove-background.mjs product.jpg [out.png]
//
// Env: PIXMILLER_API_BASE (default https://api.pixmiller.com), PIXMILLER_SIZE (default auto).
// Replaces the npm `remove.bg` package, whose endpoint is hard-coded (see docs/client-libraries.md).
import { readFile, writeFile } from "node:fs/promises";
import { basename } from "node:path";

const API_BASE = process.env.PIXMILLER_API_BASE ?? "https://api.pixmiller.com"; // was https://api.remove.bg
const API_KEY = process.env.PIXMILLER_API_KEY;
const SIZE = process.env.PIXMILLER_SIZE ?? "auto"; // preview/small/regular = free, watermarked

export async function removeBackground(path, { size = SIZE, maxRetries = 3 } = {}) {
  const bytes = await readFile(path);
  for (let attempt = 0; ; attempt++) {
    const form = new FormData();
    form.append("image_file", new Blob([bytes]), basename(path));
    form.append("size", size);

    const resp = await fetch(`${API_BASE}/v1.0/removebg`, {
      method: "POST",
      headers: { "X-Api-Key": API_KEY },
      body: form,
    });

    if (resp.status === 429 && attempt < maxRetries) {
      const wait = Number(resp.headers.get("retry-after") ?? 5);
      console.error(`rate limited, retrying in ${wait}s`);
      await new Promise((r) => setTimeout(r, wait * 1000));
      continue;
    }
    if (!resp.ok) {
      // Same envelope as remove.bg: {"errors":[{"code":"…","title":"…"}]}
      const body = await resp.json().catch(() => ({}));
      const error = body.errors?.[0] ?? {};
      throw Object.assign(new Error(`HTTP ${resp.status} ${error.code}: ${error.title}`), {
        status: resp.status,
        code: error.code,
      });
    }
    return {
      image: Buffer.from(await resp.arrayBuffer()),
      creditsCharged: resp.headers.get("x-credits-charged"),
      width: resp.headers.get("x-width"),
      height: resp.headers.get("x-height"),
      type: resp.headers.get("x-type"),
      rateLimitRemaining: resp.headers.get("x-ratelimit-remaining"),
    };
  }
}

const [input, output = "out.png"] = process.argv.slice(2);
if (!API_KEY) {
  console.error("Set PIXMILLER_API_KEY (https://pixmiller.com/en/users/~api/)");
  process.exit(2);
}
if (!input) {
  console.error("usage: node remove-background.mjs input-image [output.png]");
  process.exit(2);
}

try {
  const result = await removeBackground(input);
  await writeFile(output, result.image);
  console.log(
    `saved ${output} · ${result.width}x${result.height} px · credits charged: ${result.creditsCharged} · type: ${result.type}`,
  );
} catch (err) {
  console.error(`error: ${err.message}`);
  process.exit(1);
}
