#!/usr/bin/env python3

import json
import os

daemon = {}
daemon['registry-mirrors'] = ['https://registry-1.docker.io']
daemon['insecure-registry'] = []

local_registry = (f'{os.environ.get("REGISTRY_ADDRESS")}'
                  f':{os.environ.get("REGISTRY_PORT")}')

if local_registry.startswith('None') is False:
    daemon['registry-mirrors'].insert(0, local_registry)
    daemon['insecure-registry'].insert(0, local_registry)

with open('daemon.json', 'w') as f:
    f.write(json.dumps(daemon))
