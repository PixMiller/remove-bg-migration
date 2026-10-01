// Remove the background of one image — Java 11+, standard library only.
//
//   PIXMILLER_API_KEY=... java RemoveBackground.java product.jpg [out.png]
//
// Env: PIXMILLER_API_BASE (default https://api.pixmiller.com), PIXMILLER_SIZE (default auto).

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class RemoveBackground {
    static final String API_BASE = envOr("PIXMILLER_API_BASE", "https://api.pixmiller.com"); // was https://api.remove.bg
    static final String API_KEY = System.getenv("PIXMILLER_API_KEY");
    static final String SIZE = envOr("PIXMILLER_SIZE", "auto"); // preview/small/regular = free, watermarked

    static String envOr(String key, String fallback) {
        String value = System.getenv(key);
        return value == null || value.isEmpty() ? fallback : value;
    }

    static byte[] multipartBody(String boundary, Path image) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        String head = "--" + boundary + "\r\n"
                + "Content-Disposition: form-data; name=\"image_file\"; filename=\"" + image.getFileName() + "\"\r\n"
                + "Content-Type: application/octet-stream\r\n\r\n";
        out.write(head.getBytes(StandardCharsets.UTF_8));
        out.write(Files.readAllBytes(image));
        String tail = "\r\n--" + boundary + "\r\n"
                + "Content-Disposition: form-data; name=\"size\"\r\n\r\n" + SIZE + "\r\n"
                + "--" + boundary + "--\r\n";
        out.write(tail.getBytes(StandardCharsets.UTF_8));
        return out.toByteArray();
    }

    static HttpResponse<byte[]> removeBackground(Path image) throws IOException, InterruptedException {
        HttpClient client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(30)).build();
        String boundary = "----pixmiller" + UUID.randomUUID();
        byte[] body = multipartBody(boundary, image);
        for (int attempt = 0; ; attempt++) {
            HttpRequest request = HttpRequest.newBuilder(URI.create(API_BASE + "/v1.0/removebg"))
                    .timeout(Duration.ofSeconds(120))
                    .header("X-Api-Key", API_KEY)
                    .header("Content-Type", "multipart/form-data; boundary=" + boundary)
                    .POST(HttpRequest.BodyPublishers.ofByteArray(body))
                    .build();
            HttpResponse<byte[]> response = client.send(request, HttpResponse.BodyHandlers.ofByteArray());
            if (response.statusCode() == 429 && attempt < 3) {
                long wait = response.headers().firstValue("Retry-After").map(Long::parseLong).orElse(5L);
                System.err.println("rate limited, retrying in " + wait + "s");
                Thread.sleep(wait * 1000);
                continue;
            }
            return response;
        }
    }

    // Pulls one string field out of the remove.bg error envelope without a JSON dependency.
    static String field(String json, String name) {
        Matcher m = Pattern.compile("\"" + name + "\"\\s*:\\s*\"([^\"]*)\"").matcher(json);
        return m.find() ? m.group(1) : "?";
    }

    public static void main(String[] args) throws Exception {
        if (API_KEY == null || API_KEY.isEmpty()) {
            System.err.println("Set PIXMILLER_API_KEY (https://pixmiller.com/en/users/~api/)");
            System.exit(2);
        }
        if (args.length < 1) {
            System.err.println("usage: java RemoveBackground.java input-image [output.png]");
            System.exit(2);
        }
        Path output = Path.of(args.length > 1 ? args[1] : "out.png");

        HttpResponse<byte[]> response = removeBackground(Path.of(args[0]));
        if (response.statusCode() != 200) {
            // Same envelope as remove.bg: {"errors":[{"code":"…","title":"…"}]}
            String body = new String(response.body(), StandardCharsets.UTF_8);
            System.err.printf("error: HTTP %d %s: %s%n", response.statusCode(), field(body, "code"), field(body, "title"));
            System.exit(1);
        }
        Files.write(output, response.body());
        var h = response.headers();
        System.out.printf("saved %s · %sx%s px · credits charged: %s · type: %s%n", output,
                h.firstValue("X-Width").orElse("?"), h.firstValue("X-Height").orElse("?"),
                h.firstValue("X-Credits-Charged").orElse("?"), h.firstValue("X-Type").orElse("?"));
    }
}
