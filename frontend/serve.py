"""Serve the frontend and forward same-origin API requests to the Go backend."""

import argparse
from functools import partial
from http.client import HTTPException
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen


class MarketplaceHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.is_api_request():
            self.proxy()
        else:
            super().do_GET()

    def do_POST(self):
        self.proxy()

    do_PUT = do_POST
    do_DELETE = do_POST

    def is_api_request(self):
        path = urlsplit(self.path).path
        return path.startswith("/v1/") or path == "/health"

    def proxy(self):
        if not self.is_api_request():
            self.send_error(404)
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_error(400)
            return
        if not 0 <= length <= 52 << 20:
            self.send_error(413)
            return

        content = self.rfile.read(length) if length else None
        headers = {}
        if self.headers.get("Content-Type"):
            headers["Content-Type"] = self.headers["Content-Type"]
        request = Request(
            self.server.api_origin + self.path,
            data=content,
            headers=headers,
            method=self.command,
        )

        try:
            upstream = urlopen(request, timeout=15)
        except HTTPError as error:
            upstream = error
        except (URLError, HTTPException, TimeoutError):
            body = b'{"error":"Could not reach the listings API. Check that the backend is running."}'
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        with upstream:
            self.send_response(upstream.code)
            for header in ("Content-Type", "Content-Length", "Cache-Control"):
                if value := upstream.headers.get(header):
                    self.send_header(header, value)
            self.end_headers()
            while chunk := upstream.read(64 * 1024):
                self.wfile.write(chunk)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=5173)
    parser.add_argument("--api", default="http://localhost:8080")
    options = parser.parse_args()
    origin = urlsplit(options.api)
    if origin.scheme not in ("http", "https") or not origin.hostname or origin.path not in ("", "/") or origin.query or origin.fragment:
        parser.error("--api must be an HTTP(S) origin, such as http://localhost:8080")

    handler = partial(MarketplaceHandler, directory=str(Path(__file__).resolve().parent))
    with ThreadingHTTPServer(("127.0.0.1", options.port), handler) as server:
        server.api_origin = options.api.rstrip("/")
        print(f"Listings is running at http://localhost:{options.port}", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
