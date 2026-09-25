#!/usr/bin/env bash
set -euo pipefail
: "${KUBE_CONTEXT:?}" "${RUNNER_PRIVATE_IP:?}"
python3 - <<'PY' | kubectl --context "$KUBE_CONTEXT" apply -f -
import ipaddress,json,os
ip=str(ipaddress.ip_address(os.environ['RUNNER_PRIVATE_IP']))
for name,port in [('runner-host',9100),('runner-process',9252)]:
    print(json.dumps({'apiVersion':'v1','kind':'Service','metadata':{'name':name,'namespace':'ci-platform','labels':{'observe':'app'}},'spec':{'ports':[{'name':'http','port':port}]}}));print('---')
    print(json.dumps({'apiVersion':'v1','kind':'Endpoints','metadata':{'name':name,'namespace':'ci-platform'},'subsets':[{'addresses':[{'ip':ip}],'ports':[{'name':'http','port':port}]}]}));print('---')
PY
