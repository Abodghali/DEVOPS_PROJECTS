"""Run against a live API and worker; creates a uniquely keyed test order."""
import json
import os
import time
import uuid
import urllib.request
import urllib.error
from pathlib import Path

url = os.getenv("BASE_URL", "http://localhost:8082")
token = os.getenv("API_TOKEN") or Path(".secrets/api_token").read_text().strip()
key = str(uuid.uuid4())
payload = {"item": "Notebook", "quantity": 3, "unit_price_cents": 450}

def request(path, body=None, auth=True):
    headers = {"Content-Type": "application/json", "Idempotency-Key": key}
    if auth:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(url + path, data=json.dumps(body).encode() if body is not None else None, headers=headers)
    with urllib.request.urlopen(req, timeout=5) as response:
        return response.status, json.load(response)

assert request("/readyz")[0] == 200
try:
    request("/orders", payload, auth=False)
    raise AssertionError("unauthenticated submission accepted")
except urllib.error.HTTPError as exc:
    assert exc.code == 401
    exc.close()
status, order = request("/orders", payload)
assert status == 202
status, repeated = request("/orders", payload)
assert status == 200 and repeated["id"] == order["id"]
try:
    request("/orders", dict(payload, quantity=4))
    raise AssertionError("conflicting retry accepted")
except urllib.error.HTTPError as exc:
    assert exc.code == 409
    exc.close()
for attempt in range(30):
    _, result = request("/orders/" + order["id"])
    if result["status"] == "completed":
        assert result["total_cents"] == 1350
        print("PASS: authentication, idempotency, conflict and asynchronous completion")
        break
    time.sleep(1)
else:
    raise AssertionError("worker did not finish within 30 seconds")
