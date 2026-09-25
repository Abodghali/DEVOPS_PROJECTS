import hmac
import json
import logging
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit
from db import connect, secret
from domain import validate_order

logging.basicConfig(level=logging.INFO)

class Handler(BaseHTTPRequestHandler):
    def setup(self):
        super().setup()
        self.connection.settimeout(10)

    def reply(self, code, data):
        body = json.dumps(data, default=str).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def authorized(self):
        expected = "Bearer " + secret("API_TOKEN")
        if not hmac.compare_digest(self.headers.get("Authorization", "").encode(), expected.encode()):
            self.reply(401, {"error": "unauthorized"})
            return False
        return True

    def do_GET(self):
        path = urlsplit(self.path).path
        if path == "/healthz":
            return self.reply(200, {"status": "alive"})
        if path == "/readyz":
            try:
                with connect() as conn:
                    conn.execute("SELECT id FROM orders LIMIT 1")
                return self.reply(200, {"status": "ready"})
            except Exception:
                return self.reply(503, {"status": "database unavailable"})
        if not self.authorized():
            return
        if not path.startswith("/orders/"):
            return self.reply(404, {"error": "not found"})
        try:
            order_id = uuid.UUID(path.removeprefix("/orders/"))
        except ValueError:
            return self.reply(400, {"error": "invalid order ID"})
        try:
            with connect() as conn:
                row = conn.execute("SELECT id, item, quantity, status, total_cents FROM orders WHERE id=%s", (order_id,)).fetchone()
            if not row:
                return self.reply(404, {"error": "not found"})
            self.reply(200, dict(zip(("id", "item", "quantity", "status", "total_cents"), row)))
        except Exception:
            logging.exception("order lookup failed")
            self.reply(503, {"error": "database unavailable"})

    def do_POST(self):
        if not self.authorized():
            return
        if self.path != "/orders":
            return self.reply(404, {"error": "not found"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not 1 <= length <= 4096 or self.headers.get("Transfer-Encoding"):
                raise ValueError("Expected a JSON body of at most 4096 bytes")
            key = self.headers.get("Idempotency-Key", "")
            if not 1 <= len(key) <= 100:
                raise ValueError("Idempotency-Key header required (1-100 characters)")
            item, quantity, price = validate_order(json.loads(self.rfile.read(length)))
        except (ValueError, UnicodeError):
            return self.reply(400, {"error": "invalid JSON, order fields or Idempotency-Key"})
        try:
            with connect() as conn:
                row = conn.execute("""INSERT INTO orders (id, request_key, item, quantity, unit_price_cents)
                    VALUES (%s,%s,%s,%s,%s) ON CONFLICT (request_key) DO NOTHING RETURNING id""",
                    (uuid.uuid4(), key, item, quantity, price)).fetchone()
                if row:
                    code, order_id = 202, row[0]
                else:
                    existing = conn.execute("SELECT id,item,quantity,unit_price_cents FROM orders WHERE request_key=%s", (key,)).fetchone()
                    if tuple(existing[1:]) != (item, quantity, price):
                        return self.reply(409, {"error": "key already used for another order"})
                    code, order_id = 200, existing[0]
            self.reply(code, {"id": str(order_id)})
        except Exception:
            logging.exception("order submission failed")
            self.reply(503, {"error": "database unavailable"})

if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
