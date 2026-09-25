import hmac
import os

PRICES = {"starter": 900, "team": 2400, "business": 4900}

def ready():
    return bool(os.getenv("API_TOKEN"))

def quote(plan, seats):
    if plan not in PRICES or type(seats) is not int or not 1 <= seats <= 1000:
        raise ValueError("Choose a valid plan and 1-1000 seats")
    return {"plan": plan, "seats": seats, "monthly_cents": PRICES[plan] * seats}

def handle(method, path, data, headers):
    if path == "/version":
        return 200, {"version": os.getenv("RELEASE", "local"), "environment": os.getenv("ENVIRONMENT", "local")}
    if path == "/api/plans" and method == "GET":
        return 200, PRICES
    if path == "/api/quote" and method == "POST":
        token = os.getenv("API_TOKEN", "")
        if not token or not hmac.compare_digest(headers.get("Authorization", "").encode(), ("Bearer " + token).encode()):
            return 401, {"error": "unauthorized"}
        if not isinstance(data, dict):
            raise ValueError("Expected a JSON object")
        return 200, quote(data.get("plan"), data.get("seats"))
    return 404, {"error": "not found"}
