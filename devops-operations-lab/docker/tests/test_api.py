import importlib.util
from pathlib import Path
import threading
import unittest
import urllib.request
import urllib.error
import json
from http.server import ThreadingHTTPServer

spec = importlib.util.spec_from_file_location("server", Path(__file__).parents[1] / "app/server.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ApiTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), module.Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def test_health(self):
        for path in ("/healthz", "/readyz"):
            with urllib.request.urlopen(self.url + path) as response:
                self.assertEqual(json.load(response), {"status": "ok"})

    def test_service(self):
        with urllib.request.urlopen(self.url) as response:
            self.assertEqual(json.load(response)["service"], "ops-api")

    def test_metrics(self):
        def count():
            with urllib.request.urlopen(self.url + "/metrics") as response:
                lines = response.read().decode().splitlines()
            return int(next(line.split()[1] for line in lines if line.startswith("ops_requests_total ")))
        first = count()
        self.assertGreater(count(), first)

    def test_missing(self):
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            urllib.request.urlopen(self.url + "/missing")
        self.assertEqual(ctx.exception.code, 404)
        ctx.exception.close()
