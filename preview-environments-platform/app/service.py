import os

def ready():
    return True

def greeting(name):
    if not isinstance(name, str) or not 1 <= len(name.strip()) <= 60:
        raise ValueError('name must contain 1-60 characters')
    return {'message': 'Hello, ' + name.strip(), 'review': os.getenv('REVIEW_ID', 'local')}

def handle(method, path, data, headers):
    if path in ('/', '/version'):
        return 200, {'application':'preview-demo', 'release':os.getenv('RELEASE','local'), 'review':os.getenv('REVIEW_ID','local')}
    if path == '/greet' and method == 'POST':
        if not isinstance(data, dict): raise ValueError('Expected a JSON object')
        return 200, greeting(data.get('name'))
    return 404, {'error':'not found'}
