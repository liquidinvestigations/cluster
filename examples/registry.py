#!/usr/bin/env python3

import json
import os

daemon = {}
daemon['registry-mirrors'] = ['https://registry-1.docker.io']
daemon['insecure-registry'] = []

registry_address = os.environ.get("REGISTRY_ADDRESS")
registry_port = os.environ.get("REGISTRY_PORT")

if registry_address and registry_port:
    local_registry = f'{registry_address}:{registry_port}'
    daemon['registry-mirrors'].insert(0, local_registry)
    daemon['insecure-registry'].insert(0, local_registry)

with open('daemon.json', 'w') as f:
    print(json.dumps(daemon, indent=2), file=f)
