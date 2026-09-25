import sys
import json
import threading
import unittest
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parents[1]/'app'))
from runtime import Handler

class HTTPTransportTest(unittest.TestCase):
    def test_health_and_metrics_over_http(self):
        server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
        thread=threading.Thread(target=server.serve_forever,daemon=True)
        thread.start()
        try:
            base=f'http://127.0.0.1:{server.server_port}'
            with urllib.request.urlopen(base+'/healthz',timeout=3) as response:
                self.assertEqual(json.load(response)['status'],'alive')
            with urllib.request.urlopen(base+'/metrics',timeout=3) as response:
                self.assertIn('lab_requests_total',response.read().decode())
        finally:
            server.shutdown()
            server.server_close()
            thread.join()
