from service import db
with db() as conn:
    conn.execute('CREATE TABLE IF NOT EXISTS products (sku TEXT PRIMARY KEY, name TEXT NOT NULL, price_cents INT NOT NULL, stock INT NOT NULL)')
    conn.execute("INSERT INTO products VALUES ('book','Notebook',1250,100) ON CONFLICT (sku) DO NOTHING")
