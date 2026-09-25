"""Versioned service used to practice blue/green release switching."""
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def response(path, version, healthy=True):
    if path == "/healthz":
        return (200 if healthy else 503), {"healthy": healthy, "version": version}
    if path == "/version":
        return 200, {"version": version}
    return 404, {"error": "not found"}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        status, payload = response(self.path, os.getenv("RELEASE", "blue"), os.getenv("HEALTHY", "true") == "true")
        data = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
