import sys
import unittest
import json
import threading
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parents[1] / "app"))
from server import response, Handler


class ReleaseTest(unittest.TestCase):
    def test_version_identifies_release(self):
        self.assertEqual(response("/version", "green"), (200, {"version": "green"}))

    def test_bad_candidate_fails_health(self):
        self.assertEqual(response("/healthz", "green", False)[0], 503)

    def test_unknown_path(self):
        self.assertEqual(response("/missing", "blue")[0], 404)

    def test_live_http_endpoint(self):
        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            with urllib.request.urlopen(f'http://127.0.0.1:{server.server_port}/version', timeout=3) as result:
                self.assertIn('version', json.load(result))
        finally:
            server.shutdown()
            server.server_close()
            thread.join()
