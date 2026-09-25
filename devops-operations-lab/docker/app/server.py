"""Operations API exposing health checks and Prometheus metrics."""
import json
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

START = time.monotonic()
LOCK = threading.Lock()
REQUESTS = 0

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        global REQUESTS
        with LOCK:
            REQUESTS += 1
            count = REQUESTS
        status, content_type = 200, "application/json"
        if self.path in ("/healthz", "/readyz"):
            body = {"status": "ok"}
        elif self.path == "/":
            body = {"service": "ops-api", "version": os.getenv("APP_VERSION", "1.0.0")}
        elif self.path == "/metrics":
            content_type = "text/plain; version=0.0.4"
            body = ("# HELP ops_requests_total HTTP requests including probes.\n"
                    "# TYPE ops_requests_total counter\n"
                    f"ops_requests_total {count}\n"
                    "# HELP ops_uptime_seconds Process uptime.\n"
                    "# TYPE ops_uptime_seconds gauge\n"
                    f"ops_uptime_seconds {time.monotonic() - START:.2f}\n")
        else:
            status, body = 404, {"error": "not found"}
        data = (body if isinstance(body, str) else json.dumps(body)).encode()
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        print(json.dumps({"time": self.log_date_time_string(), "message": fmt % args}), flush=True)

if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", int(os.getenv("PORT", "8080"))), Handler).serve_forever()
