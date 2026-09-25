import os
import re
import sys
from pathlib import Path
import yaml

environment = os.environ['TARGET_ENV']
if environment not in ('dev','staging','production'): raise SystemExit('Invalid environment')
image = os.environ['IMAGE']
if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._/:@-]+', image): raise SystemExit('Invalid image')
docs = list(yaml.safe_load_all((Path(__file__).parents[1]/'kubernetes'/f'{environment}.yaml').read_text()))
selected = []
for doc in docs:
    if doc['kind'] not in ('Deployment','Service','PodDisruptionBudget'): continue
    if doc['kind'] == 'Deployment':
        container = doc['spec']['template']['spec']['containers'][0]
        container['image'] = image
        for item in container['env']:
            if item['name']=='RELEASE': item['value']=os.getenv('RELEASE',image)
    selected.append(doc)
sys.stdout.write(yaml.safe_dump_all(selected,sort_keys=False))
