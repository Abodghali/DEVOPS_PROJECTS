import os
import psycopg

def db():
    return psycopg.connect(host=os.getenv('PGHOST','db'), dbname='app', user='app', password=os.environ['DB_PASSWORD'], connect_timeout=3)

def ready():
    with db() as conn: conn.execute('SELECT count(*) FROM notes')
    return True

def validate_note(data):
    if not isinstance(data,dict) or not isinstance(data.get('text'),str) or not 1 <= len(data['text']) <= 200:
        raise ValueError('text must contain 1-200 characters')
    return data['text']

def handle(method,path,data,headers):
    if path == '/notes' and method == 'POST':
        text = validate_note(data)
        with db() as conn:
            row = conn.execute('INSERT INTO notes(body) VALUES(%s) RETURNING id,created_at',(text,)).fetchone()
        return 201, {'id':row[0],'created_at':row[1]}
    if path == '/notes' and method == 'GET':
        with db() as conn:
            rows = conn.execute('SELECT id,body,created_at FROM notes ORDER BY id DESC LIMIT 100').fetchall()
        return 200, [{'id':r[0],'text':r[1],'created_at':r[2]} for r in rows]
    return 404, {'error':'not found'}
