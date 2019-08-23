#!/usr/bin/env python3

import json
import os

daemon = {}
daemon['registry-mirrors'] = ['https://registry-1.docker.io']
daemon['insecure-registry'] = []

registry_ip = os.environ.get("REGISTRY_ADDRESS")
registry_port = os.environ.get("REGISTRY_PORT")
registry_address = f'{registry_ip}:{registry_port}'

if registry_ip and registry_port:
    daemon['registry-mirrors'].insert(0, f'http://{registry_address}')
    daemon['insecure-registry'].insert(0, registry_address)

with open('daemon.json', 'w') as f:
    print(json.dumps(daemon, indent=2), file=f)
