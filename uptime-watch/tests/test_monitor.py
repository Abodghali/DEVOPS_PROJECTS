import json
import sys
import tempfile
import unittest
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parents[1] / "app"))
from monitor import initialize, record, status, load_targets, probe


class MonitorTest(unittest.TestCase):
    def test_live_probe_detects_http_failure(self):
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(200 if self.path == '/ok' else 503)
                self.end_headers()
        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            url = f'http://127.0.0.1:{server.server_port}'
            self.assertTrue(probe({'url': url + '/ok'})[0])
            self.assertFalse(probe({'url': url + '/fail'})[0])
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

    def test_alert_after_three_failures_and_recovery(self):
        with tempfile.TemporaryDirectory() as folder:
            path = str(Path(folder) / "db")
            initialize(path)
            record(path, "demo", False, 2)
            record(path, "demo", False, 2)
            self.assertFalse(status(path, ["demo"])[0]["alert"])
            record(path, "demo", False, 2)
            self.assertTrue(status(path, ["demo"])[0]["alert"])
            record(path, "demo", True, 1)
            current = status(path, ["demo"])[0]
            self.assertFalse(current["alert"])
            self.assertEqual(current["availability_percent"], 25)

    def test_unknown_is_not_reported_as_available(self):
        with tempfile.TemporaryDirectory() as folder:
            path = str(Path(folder) / "db")
            initialize(path)
            self.assertIsNone(status(path, ["demo"])[0]["up"])

    def test_duplicate_target_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "targets.json"
            path.write_text(json.dumps([{"name": "a", "url": "http://demo"}] * 2))
            with self.assertRaises(ValueError):
                load_targets(path)
