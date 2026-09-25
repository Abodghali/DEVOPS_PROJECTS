import os
from pathlib import Path
import psycopg

def secret(name):
    path = os.getenv(name + "_FILE")
    return Path(path).read_text().strip() if path else os.environ[name]

def connect():
    return psycopg.connect(host=os.getenv("PGHOST", "db"),
                           dbname=os.getenv("PGDATABASE", "orders"),
                           user=os.getenv("PGUSER", "orders"),
                           password=secret("DB_PASSWORD"), connect_timeout=3)

def migrate():
    with connect() as conn:
        conn.execute("""CREATE TABLE IF NOT EXISTS orders (
            id UUID PRIMARY KEY,
            request_key VARCHAR(100) UNIQUE NOT NULL,
            item VARCHAR(100) NOT NULL,
            quantity INTEGER NOT NULL CHECK (quantity BETWEEN 1 AND 1000),
            unit_price_cents INTEGER NOT NULL CHECK (unit_price_cents BETWEEN 1 AND 1000000),
            status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
            total_cents BIGINT,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            completed_at TIMESTAMPTZ
        )""")
        conn.execute("CREATE INDEX IF NOT EXISTS orders_pending ON orders(created_at) WHERE status='pending'")

if __name__ == "__main__":
    migrate()
