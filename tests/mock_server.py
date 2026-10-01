"""Local stub of the remove.bg-compatible endpoint, used to test the examples offline.

    python tests/mock_server.py 8787

It reproduces the documented *contract* (status codes, headers, error envelope), not the
image processing: every successful call returns the same 1×1 transparent PNG.

Keys:  test-key → 200 · ratelimit-key → alternates 429 (Retry-After: 1) and 200
       anything else → 403 invalid_api_key · missing header → 403 auth_failed
"""

import base64
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PNG_1X1 = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg=="
)
VALID_KEYS = {"test-key", "ratelimit-key"}
SIZES = {"preview", "small", "regular", "medium", "hd", "4k", "full", "50MP", "auto"}
ratelimit_calls = [0]  # odd calls are throttled, so each example sees one 429 then a 200


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):  # keep test output quiet
        pass

    def _json(self, status, payload, headers=None):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _error(self, status, code, title, headers=None):
        self._json(status, {"errors": [{"code": code, "title": title}]}, headers)

    def _auth(self):
        key = self.headers.get("X-Api-Key")
        if not key:
            self._error(403, "auth_failed", "Missing API Key")
            return None
        if key not in VALID_KEYS:
            self._error(403, "invalid_api_key", "Invalid API Key")
            return None
        return key

    def do_GET(self):
        if self.path != "/v1.0/account":
            return self._error(404, "not_found", "Not found")
        if self._auth():
            credits = {"total": 10, "subscription": 0, "payg": 10, "enterprise": 0}
            self._json(200, {"data": {"attributes": {"credits": credits, "api": {"free_calls": 0, "sizes": "all"}}}})

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length)  # always drain the body before answering
        if self.path != "/v1.0/removebg":
            return self._error(404, "not_found", "Not found")
        key = self._auth()
        if not key:
            return

        if key == "ratelimit-key":
            ratelimit_calls[0] += 1
        if key == "ratelimit-key" and ratelimit_calls[0] % 2 == 1:
            return self._error(429, "rate_limit_exceeded", "Rate limit exceeded", {"Retry-After": "1"})

        text = body.decode("latin-1")
        if not any(f'name="{f}"' in text or f"{f}=" in text for f in ("image_file", "image_url", "image_file_b64")):
            return self._error(400, "invalid_parameter", "No image given.")
        size = "preview"
        marker = 'name="size"'
        if marker in text:
            size = text.split(marker, 1)[1].split("\r\n\r\n", 1)[1].split("\r\n", 1)[0]
        if size not in SIZES:
            return self._error(400, "invalid_parameter", f"Invalid value for size: {size}")

        charged = "0" if size in ("preview", "small", "regular") else "1"
        headers = {
            "X-Credits-Charged": charged,
            "X-Width": "1",
            "X-Height": "1",
            "X-Type": "product",
            "X-RateLimit-Limit": "40",
            "X-RateLimit-Remaining": "39",
            "X-RateLimit-Reset": "1767225600",
        }
        if "application/json" in (self.headers.get("Accept") or ""):
            return self._json(200, {"data": {"result_b64": base64.b64encode(PNG_1X1).decode()}}, headers)
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(PNG_1X1)))
        for k, v in headers.items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(PNG_1X1)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
