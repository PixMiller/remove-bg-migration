<?php
// Remove the background of one image — PHP 7.4+ with the curl extension.
//
//   PIXMILLER_API_KEY=... php remove-background.php product.jpg [out.png]
//
// Env: PIXMILLER_API_BASE (default https://api.pixmiller.com), PIXMILLER_SIZE (default auto).

$apiBase = getenv('PIXMILLER_API_BASE') ?: 'https://api.pixmiller.com'; // was https://api.remove.bg
$apiKey = getenv('PIXMILLER_API_KEY');
$size = getenv('PIXMILLER_SIZE') ?: 'auto'; // preview/small/regular = free, watermarked

if (!$apiKey) {
    fwrite(STDERR, "Set PIXMILLER_API_KEY (https://pixmiller.com/en/users/~api/)\n");
    exit(2);
}
if ($argc < 2) {
    fwrite(STDERR, "usage: php remove-background.php input-image [output.png]\n");
    exit(2);
}
$input = $argv[1];
$output = $argv[2] ?? 'out.png';

function removeBackground(string $apiBase, string $apiKey, string $input, string $size): array
{
    $headers = [];
    $ch = curl_init("$apiBase/v1.0/removebg");
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_HTTPHEADER => ["X-Api-Key: $apiKey"],
        CURLOPT_POSTFIELDS => ['image_file' => new CURLFile($input), 'size' => $size],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 120,
        CURLOPT_HEADERFUNCTION => function ($ch, $line) use (&$headers) {
            $parts = explode(':', $line, 2);
            if (count($parts) === 2) {
                $headers[strtolower(trim($parts[0]))] = trim($parts[1]);
            }
            return strlen($line);
        },
    ]);
    $body = curl_exec($ch);
    if ($body === false) {
        throw new RuntimeException('network error: ' . curl_error($ch));
    }
    $status = curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    curl_close($ch);
    return [$status, $headers, $body];
}

for ($attempt = 0; ; $attempt++) {
    [$status, $headers, $body] = removeBackground($apiBase, $apiKey, $input, $size);
    if ($status === 429 && $attempt < 3) {
        $wait = (int) ($headers['retry-after'] ?? 5);
        fwrite(STDERR, "rate limited, retrying in {$wait}s\n");
        sleep($wait);
        continue;
    }
    break;
}

if ($status !== 200) {
    // Same envelope as remove.bg: {"errors":[{"code":"…","title":"…"}]}
    $error = json_decode($body, true)['errors'][0] ?? [];
    fwrite(STDERR, sprintf("error: HTTP %d %s: %s\n", $status, $error['code'] ?? '?', $error['title'] ?? $body));
    exit(1);
}

file_put_contents($output, $body);
printf(
    "saved %s · %sx%s px · credits charged: %s · type: %s\n",
    $output,
    $headers['x-width'] ?? '?',
    $headers['x-height'] ?? '?',
    $headers['x-credits-charged'] ?? '?',
    $headers['x-type'] ?? '?'
);
