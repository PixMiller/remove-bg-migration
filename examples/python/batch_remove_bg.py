"""Remove backgrounds from a whole folder while staying under the API rate limit.

    pip install requests
    PIXMILLER_API_KEY=... python batch_remove_bg.py ./photos ./cutouts

- Sends at most PIXMILLER_RATE images per minute (default 40, the per-key limit) with a few
  requests in flight, and honours Retry-After on 429.
- Skips images whose output already exists, so an interrupted run can simply be restarted.
- Stops at the first 402 (out of credits) instead of hammering the API.

Env: PIXMILLER_API_BASE, PIXMILLER_SIZE (default auto), PIXMILLER_RATE, PIXMILLER_WORKERS.
"""

import os
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import requests

API_BASE = os.environ.get("PIXMILLER_API_BASE", "https://api.pixmiller.com")
API_KEY = os.environ.get("PIXMILLER_API_KEY")
SIZE = os.environ.get("PIXMILLER_SIZE", "auto")
RATE_PER_MIN = int(os.environ.get("PIXMILLER_RATE", "40"))
WORKERS = int(os.environ.get("PIXMILLER_WORKERS", "3"))
EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
MAX_BYTES = 20 * 1024 * 1024


class RateLimiter:
    """Allow at most `per_minute` acquisitions in any rolling 60-second window."""

    def __init__(self, per_minute: int):
        self.per_minute = per_minute
        self.stamps: list[float] = []
        self.lock = threading.Lock()

    def acquire(self) -> None:
        while True:
            with self.lock:
                now = time.monotonic()
                self.stamps = [t for t in self.stamps if now - t < 60]
                if len(self.stamps) < self.per_minute:
                    self.stamps.append(now)
                    return
                wait = 60 - (now - self.stamps[0])
            time.sleep(max(wait, 0.05))


class OutOfCredits(Exception):
    pass


limiter = RateLimiter(RATE_PER_MIN)
stop = threading.Event()


def process(src: Path, dst: Path) -> tuple[str, int]:
    """Return (status, credits_charged)."""
    for _ in range(5):
        if stop.is_set():
            return "skipped", 0
        limiter.acquire()
        with src.open("rb") as image:
            resp = requests.post(
                f"{API_BASE}/v1.0/removebg",
                headers={"X-Api-Key": API_KEY},
                files={"image_file": image},
                data={"size": SIZE, "format": "png"},
                timeout=120,
            )
        if resp.status_code == 200:
            dst.write_bytes(resp.content)
            return "ok", int(resp.headers.get("X-Credits-Charged", "0"))
        if resp.status_code == 429:
            time.sleep(int(resp.headers.get("Retry-After", "5")))
            continue
        if resp.status_code == 402:
            stop.set()
            raise OutOfCredits()
        if resp.status_code in (502, 504):  # nothing was charged; retry
            time.sleep(2)
            continue
        try:
            error = resp.json()["errors"][0]
            return f"error {resp.status_code} {error.get('code')}: {error.get('title')}", 0
        except (ValueError, KeyError, IndexError):
            return f"error {resp.status_code}", 0
    return "error: gave up after retries", 0


def main() -> int:
    if not API_KEY:
        print("Set PIXMILLER_API_KEY (https://pixmiller.com/en/users/~api/)", file=sys.stderr)
        return 2
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} input-dir output-dir", file=sys.stderr)
        return 2
    src_dir, dst_dir = Path(sys.argv[1]), Path(sys.argv[2])
    dst_dir.mkdir(parents=True, exist_ok=True)

    jobs = []
    for src in sorted(src_dir.iterdir()):
        if src.suffix.lower() not in EXTENSIONS:
            continue
        dst = dst_dir / f"{src.stem}.png"
        if dst.exists():
            print(f"skip   {src.name} (already done)")
            continue
        if src.stat().st_size > MAX_BYTES:
            print(f"skip   {src.name} (larger than 20 MB)")
            continue
        jobs.append((src, dst))

    credits = failures = 0
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futures = {pool.submit(process, src, dst): src for src, dst in jobs}
        for future in as_completed(futures):
            src = futures[future]
            try:
                status, charged = future.result()
            except OutOfCredits:
                print(f"stop   {src.name}: 402 insufficient_credits — top up at https://pixmiller.com/en/pricing/")
                failures += 1
                continue
            credits += charged
            if status != "ok":
                failures += 1
            print(f"{status:<6} {src.name}" if status in ("ok", "skipped") else f"fail   {src.name}: {status}")

    print(f"\n{len(jobs) - failures}/{len(jobs)} done · {credits} credit(s) charged")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
