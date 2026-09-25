"""HTTP transport and metrics shared by this project's service processes."""
import json
import os
import logging
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import service

REQUESTS = Counter('lab_requests_total', 'Completed HTTP requests', ['service', 'environment', 'status'])
DURATION = Histogram('lab_request_duration_seconds', 'HTTP handling duration', ['service', 'environment'])
ROLE = os.getenv('SERVICE', 'app')
ENV = os.getenv('ENVIRONMENT', 'local')

class Handler(BaseHTTPRequestHandler):
    def setup(self):
        super().setup()
        self.connection.settimeout(10)
    def dispatch(self):
        if self.path == '/metrics':
            body, status, content_type = generate_latest(), 200, CONTENT_TYPE_LATEST
        else:
            with DURATION.labels(ROLE, ENV).time():
                try:
                    if self.path == '/healthz':
                        status, result = 200, {'status':'alive'}
                    elif self.path == '/readyz':
                        status, result = (200, {'status':'ready'}) if service.ready() else (503, {'status':'not ready'})
                    else:
                        length = int(self.headers.get('Content-Length','0'))
                        if length < 0 or length > 65536 or self.headers.get('Transfer-Encoding'):
                            raise ValueError('invalid body length')
                        data = json.loads(self.rfile.read(length)) if length else None
                        status, result = service.handle(self.command, self.path, data, self.headers)
                except (ValueError, TypeError) as exc:
                    status, result = 400, {'error':str(exc)}
                except Exception:
                    logging.exception('request failed')
                    status, result = 503, {'error':'dependency unavailable'}
            REQUESTS.labels(ROLE, ENV, str(status)).inc()
            content_type = 'text/html; charset=utf-8' if isinstance(result, str) else 'application/json'
            body = result.encode() if isinstance(result,str) else json.dumps(result,default=str).encode()
        self.send_response(status)
        self.send_header('Content-Type',content_type)
        self.send_header('Content-Length',str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    do_GET = dispatch
    do_POST = dispatch

if __name__ == '__main__':
    if hasattr(service, 'start'): service.start()
    ThreadingHTTPServer(('0.0.0.0',int(os.getenv('PORT','8080'))),Handler).serve_forever()
