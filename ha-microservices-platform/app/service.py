import json
import os
import urllib.request
import psycopg
import redis

ROLE = os.getenv('SERVICE', 'frontend')

def db():
    return psycopg.connect(host=os.getenv('PGHOST','db'), dbname='app', user='app',
                          password=os.environ['DB_PASSWORD'], connect_timeout=3,
                          options='-c statement_timeout=3000')

def fetch(service, path):
    with urllib.request.urlopen(f'http://{service}:8080{path}', timeout=4) as response:
        return json.load(response)

def ready():
    if ROLE in ('catalog','inventory'):
        with db() as conn: conn.execute('SELECT sku FROM products LIMIT 1')
    return True

def price(quantity):
    if type(quantity) is not int or not 1 <= quantity <= 100:
        raise ValueError('quantity must be 1-100')
    return {'quantity':quantity, 'total_cents':quantity * 1250}

def handle(method, path, data, headers):
    if os.getenv('INJECT_HTTP_500') == 'true':
        return 500, {'error':'controlled lab fault'}
    if ROLE == 'frontend' and path == '/':
        return 200, '<!doctype html><html lang="en"><title>Service Catalog</title><body><h1>Service Catalog</h1><p>Open <a href="/api/catalog">catalog</a> or <a href="/api/inventory">inventory</a> through the gateway.</p></body></html>'
    if ROLE == 'gateway':
        routes = {'/api/catalog':('catalog','/catalog'), '/api/inventory':('inventory','/inventory'), '/api/price':('pricing','/price')}
        if path == '/':
            with urllib.request.urlopen('http://frontend:8080/', timeout=4) as response:
                return 200, response.read().decode()
        if path in routes: return 200, fetch(*routes[path])
    if ROLE == 'catalog' and path == '/catalog':
        with db() as conn:
            rows = conn.execute('SELECT sku,name,price_cents FROM products ORDER BY sku').fetchall()
        return 200, [{'sku':r[0],'name':r[1],'price_cents':r[2]} for r in rows]
    if ROLE == 'inventory' and path == '/inventory':
        cache = redis.Redis(host=os.getenv('REDIS_HOST','redis'), password=os.environ['REDIS_PASSWORD'], socket_connect_timeout=1, socket_timeout=1)
        try: cached = cache.get('inventory')
        except redis.RedisError: cached = None
        if cached: return 200, json.loads(cached)
        with db() as conn:
            result = [{'sku':r[0],'stock':r[1]} for r in conn.execute('SELECT sku,stock FROM products ORDER BY sku').fetchall()]
        try: cache.setex('inventory', 5, json.dumps(result))
        except redis.RedisError: pass
        return 200, result
    if ROLE == 'pricing' and path == '/price': return 200, price(1)
    return 404, {'error':'not found','service':ROLE}
