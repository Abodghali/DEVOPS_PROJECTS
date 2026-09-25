"""Poll configured HTTP endpoints and expose availability history."""
import json
from contextlib import closing
import os
from pathlib import Path
import re
import sqlite3
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def load_targets(path):
    targets = json.loads(Path(path).read_text())
    names = set()
    if not isinstance(targets, list) or not targets:
        raise ValueError("At least one target is required")
    for target in targets:
        name = target.get("name", "")
        if not re.fullmatch(r"[a-zA-Z0-9_-]{1,50}", name) or name in names:
            raise ValueError("Target names must be unique safe identifiers")
        if not target.get("url", "").startswith(("http://", "https://")):
            raise ValueError("Only HTTP(S) targets are allowed")
        names.add(name)
    return targets


def initialize(path):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with closing(sqlite3.connect(path)) as conn, conn:
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("CREATE TABLE IF NOT EXISTS checks (id INTEGER PRIMARY KEY, target TEXT, checked_at REAL, up INTEGER, latency_ms REAL)")
        conn.execute("CREATE INDEX IF NOT EXISTS checks_target_id ON checks(target,id)")


def record(path, name, up, latency_ms, timestamp=None):
    now = time.time() if timestamp is None else timestamp
    with closing(sqlite3.connect(path, timeout=5)) as conn, conn:
        conn.execute("INSERT INTO checks(target,checked_at,up,latency_ms) VALUES(?,?,?,?)", (name, now, int(up), latency_ms))
        conn.execute("DELETE FROM checks WHERE checked_at < ?", (now - 7 * 86400,))


def status(path, names):
    result = []
    with closing(sqlite3.connect(path, timeout=5)) as conn, conn:
        for name in names:
            rows = conn.execute("SELECT checked_at,up,latency_ms FROM checks WHERE target=? ORDER BY id DESC LIMIT 3", (name,)).fetchall()
            total, successes = conn.execute("SELECT count(*),coalesce(sum(up),0) FROM checks WHERE target=? AND checked_at>=?", (name, time.time() - 86400)).fetchone()
            result.append({"name": name, "up": bool(rows[0][1]) if rows else None,
                           "last_checked": rows[0][0] if rows else None,
                           "latency_ms": rows[0][2] if rows else None,
                           "alert": len(rows) == 3 and not any(row[1] for row in rows),
                           "availability_percent": round(100 * successes / total, 2) if total else None})
    return result


def probe(target):
    start = time.monotonic()
    try:
        # Targets are operator-controlled; response bodies are never retained.
        with urllib.request.urlopen(target["url"], timeout=3) as response:
            up = 200 <= response.status < 400
    except Exception:
        up = False
    return up, round((time.monotonic() - start) * 1000, 2)


def poll(path, targets, interval):
    while True:
        for target in targets:
            up, latency = probe(target)
            record(path, target["name"], up, latency)
        time.sleep(interval)


def serve(path, targets):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/healthz":
                data = {"status": "alive"}
            elif self.path == "/status":
                data = status(path, [t["name"] for t in targets])
            else:
                self.send_error(404)
                return
            body = json.dumps(data).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()


if __name__ == "__main__":
    db = os.getenv("DB_PATH", "/data/checks.db")
    targets = load_targets(os.getenv("TARGETS_FILE", "/app/targets.json"))
    initialize(db)
    threading.Thread(target=poll, args=(db, targets, max(1, int(os.getenv("INTERVAL", "10")))), daemon=True).start()
    serve(db, targets)
