"""Local test fixture only; never used to report real GitLab activity."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if '/runners' in self.path:
            body=[{'id':1,'status':'online'}]
        elif self.path.split('?')[0].endswith('/pipelines'):
            body=[{'id':42,'status':'success','created_at':'2026-01-01T00:00:00Z'}]
        else: body={'id':42,'duration':12}
        data=json.dumps(body).encode()
        self.send_response(200)
        self.send_header('Content-Length',str(len(data)))
        self.end_headers()
        self.wfile.write(data)
if __name__ == '__main__':
    ThreadingHTTPServer(('0.0.0.0',8081),Handler).serve_forever()
