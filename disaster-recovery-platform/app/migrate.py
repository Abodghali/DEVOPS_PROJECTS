from service import db
with db() as conn:
    conn.execute('CREATE TABLE IF NOT EXISTS notes (id BIGSERIAL PRIMARY KEY, body TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp())')
