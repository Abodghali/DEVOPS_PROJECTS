"""Render one bounded review environment from validated CI identifiers."""
import copy
import datetime
import json
import os
import re
from pathlib import Path

def namespace(project, mr):
    if not re.fullmatch(r'[1-9][0-9]{0,11}',str(project)) or not re.fullmatch(r'[1-9][0-9]{0,11}',str(mr)):
        raise ValueError('Project and MR IDs must be positive integers')
    return f'review-{project}-{mr}'

def owned(name,labels,project,mr):
    return name == namespace(project,mr) and labels.get('preview-owner')=='gitlab' and labels.get('gitlab-project')==str(project)

def render(project,mr,image,domain):
    name=namespace(project,mr)
    if not re.fullmatch(r'[a-z0-9]+(?:[.-][a-z0-9]+)*',domain): raise ValueError('Invalid base domain')
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._/:@-]+',image): raise ValueError('Invalid image')
    docs=json.loads((Path(__file__).parents[1]/'kubernetes/template.json').read_text())
    raw=json.dumps(docs).replace('NAMESPACE',name).replace('APP_IMAGE',image).replace('REVIEW_HOST',name+'.'+domain).replace('PROJECT_ID',str(project)).replace('MR_ID',str(mr))
    docs=json.loads(raw)
    docs[0]['metadata']['annotations']={'expires-at':(datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=1)).isoformat()}
    return docs

if __name__=='__main__':
    for doc in render(os.environ['CI_PROJECT_ID'],os.environ['CI_MERGE_REQUEST_IID'],os.environ['IMAGE'],os.environ['REVIEW_BASE_DOMAIN']):
        print(json.dumps(doc)); print('---')
