#!/usr/bin/env python3

"""
Manage a Consul + Vault + Nomad cluster.
"""

import os
import logging
import argparse
from pathlib import Path
import tempfile
import subprocess
import configparser
from time import time, sleep
import json
from urllib.request import Request, urlopen
from urllib.error import URLError
import sys

log = logging.getLogger(__name__)

config = configparser.ConfigParser()
config.read('cluster.ini')

class PATH:
    root = Path(__file__).parent.resolve()

    cluster_py = root / 'cluster.py'
    cluster_ini = root / 'cluster.ini'

    bin = root / 'bin'

    etc = root / 'etc'
    consul_hcl = etc / 'consul.hcl'
    vault_hcl = etc / 'vault.hcl'
    nomad_hcl = etc / 'nomad.hcl'
    supervisor_conf = etc / 'supervisor-cluster.conf'

    var = root / 'var'
    tmp = var / 'tmp'
    consul_var = var / 'consul'
    nomad_var = var / 'nomad'
    vault_secrets = var / 'vault-secrets.ini'
    consul_socket = var / 'consul.socket'


def run(cmd, **kwargs):
    log.debug('+ %s', cmd)
    return subprocess.check_output(cmd, shell=True, **kwargs).decode('latin1')


def detect_interface():
    if sys.platform == 'darwin':
        return run("route get 8.8.8.8 | awk '/interface:/ {print $2}'").strip()
    elif sys.platform == 'linux' or sys.platform == 'linux2':
        return run("ip route get 8.8.8.8 | awk '{ print $5; exit }'").strip()
    raise RuntimeError(f'Unsupported platform {sys.platform}')


config = configparser.ConfigParser()
config.read(PATH.cluster_ini)


def read_vault_secrets():
    secrets = configparser.ConfigParser()
    secrets.read(PATH.vault_secrets)
    return {
        'keys': secrets.get('vault', 'keys', fallback=''),
        'root_token': secrets.get('vault', 'root_token', fallback=''),
    }


def nomad_retry_join_section(servers):
    if not servers:
        return ''
    quoted = [f'"{ip}:4648"' for ip in servers]
    return f'server_join {{ retry_join = [{", ".join(quoted)}] }}'


def nomad_client_servers_section(servers):
    if not servers:
        return ''
    quoted = [f'"{ip}:4647"' for ip in servers]
    return f'servers = [{", ".join(quoted)}]'


def consul_retry_join_section(servers):
    if not servers:
        return ''
    quoted = [f'"{ip}"' for ip in servers]
    return f'retry_join = [{", ".join(quoted)}]'

class OPTIONS:
    nomad_interface = config.get('nomad', 'interface', fallback=None) or detect_interface()
    _nomad_meta = {key: config.get('nomad_meta', key) for key in config['nomad_meta']} if 'nomad_meta' in config else {}
    nomad_meta = "\n".join(f'{key} = "{value}"' for key, value in _nomad_meta.items())

    consul_address = config.get('consul', 'address', fallback='127.0.0.1')

    vault_address = config.get('vault', 'address', fallback='127.0.0.1')

    vault_disable_mlock = config.getboolean('vault', 'disable_mlock', fallback=False)

    nomad_address = config.get('nomad', 'address', fallback='127.0.0.1')

    nomad_advertise = config.get('nomad', 'advertise', fallback='127.0.0.1')

    nomad_memory = config.get('nomad', 'memory', fallback=0)

    nomad_zombie_time = config.get('nomad', 'zombie_time', fallback='4h')

    supervisor_autostart = config.getboolean('supervisor', 'autostart', fallback=False)

    versions = {
        'consul': config.get('consul', 'version', fallback='1.4.5'),
        'vault': config.get('vault', 'version', fallback='1.1.2'),
        'nomad': config.get('nomad', 'version', fallback='0.9.1'),
    }

    dev = config.getboolean('cluster', 'dev', fallback=False)

    debug = config.getboolean('cluster', 'debug', fallback=False)

    nomad_vault_token = read_vault_secrets()['root_token']

    bootstrap_expect = config.getint('cluster', 'bootstrap_expect', fallback=1)
    _retry_join = config.get('cluster', 'retry_join', fallback='')
    retry_join = _retry_join.split(',') if _retry_join else []
    nomad_retry_join = nomad_retry_join_section(retry_join)
    consul_retry_join = consul_retry_join_section(retry_join)
    nomad_client_servers = nomad_client_servers_section(retry_join)

class CONFIG:
    pass


CONFIG.consul = lambda: f'''\
bind_addr = "{OPTIONS.consul_address}"
client_addr = "{OPTIONS.consul_address}"
addresses {{
  http = "{OPTIONS.consul_address} unix://{PATH.consul_socket}"
}}
data_dir = "{PATH.consul_var}"
datacenter = "dc1"
server = true
ui = true
bootstrap_expect = {OPTIONS.bootstrap_expect}
{OPTIONS.consul_retry_join}
'''


CONFIG.vault = lambda: f'''\
storage "consul" {{
  address = "{OPTIONS.consul_address}:8500"
  path = "vault/"
}}

listener "tcp" {{
  address = "{OPTIONS.vault_address}:8200"
  tls_disable = 1
}}

ui = true
disable_mlock = {'true' if OPTIONS.vault_disable_mlock else 'false'}
api_addr = "http://{OPTIONS.vault_address}:8200"
'''


CONFIG.nomad = lambda: f'''\
data_dir = "{PATH.nomad_var}"
leave_on_interrupt = true
leave_on_terminate = true

addresses {{
  http = "{OPTIONS.nomad_address}"
  rpc = "{OPTIONS.nomad_address}"
  serf = "{OPTIONS.nomad_address}"
}}

advertise {{
  http = "{OPTIONS.nomad_advertise}"
  rpc = "{OPTIONS.nomad_advertise}"
  serf = "{OPTIONS.nomad_advertise}"
}}

server {{
  enabled = true
  bootstrap_expect = {OPTIONS.bootstrap_expect}
  job_gc_threshold = "{OPTIONS.nomad_zombie_time}"
  {OPTIONS.nomad_retry_join}
}}

client {{
  enabled = true
  network_interface = "{OPTIONS.nomad_interface}"
  memory_total_mb = {OPTIONS.nomad_memory or '0 # autodetect'}
  {OPTIONS.nomad_client_servers}
  meta {{
    {OPTIONS.nomad_meta}
  }}
  options {{
    "fingerprint.blacklist" = "env_aws"
  }}
}}

consul {{
  address = "{OPTIONS.consul_address}:8500"
}}

vault {{
  enabled = true
  address = "http://{OPTIONS.vault_address}:8200"
}}
'''


CONFIG.supervisor = lambda username: f'''\
[program:consul]
user = {username}
command = {sys.executable} {PATH.cluster_py} runserver consul
redirect_stderr = true
autostart = {OPTIONS.supervisor_autostart}

[program:vault]
user = {username}
command = {sys.executable} {PATH.cluster_py} runserver vault
redirect_stderr = true
autostart = {OPTIONS.supervisor_autostart}

[program:nomad]
user = {username}
command = {sys.executable} {PATH.cluster_py} runserver nomad
redirect_stderr = true
autostart = {OPTIONS.supervisor_autostart}

[group:cluster]
programs = consul,vault,nomad
'''


class JsonApi:

    def __init__(self, endpoint):
        self.endpoint = endpoint

    def send(self, req):
        log.debug('%s %s', req.get_method(), req.get_full_url())
        with urlopen(req) as res:
            if res.status == 200:
                res_body = json.load(res)
                log.debug('response: %r', res_body)
                return res_body

    def get(self, url):
        return self.send(Request(f'{self.endpoint}{url}'))

    def put(self, url, data):
        return self.send(Request(
            f'{self.endpoint}{url}',
            json.dumps(data).encode('utf8'),
            {'Content-Type': 'application/json'},
            method='PUT',
        ))


def download(url, path):
    run(f'curl -Ls "{url}" -o "{path}"')


def unzip(zip_path, **kwargs):
    run(f'unzip "{zip_path}"', **kwargs)


def install():
    """ Install Consul, Vault and Nomad. """

    for dir in [PATH.root, PATH.bin, PATH.etc, PATH.var, PATH.tmp]:
        dir.mkdir(exist_ok=True)

    with tempfile.TemporaryDirectory(dir=PATH.tmp) as _tmp:
        tmp = Path(_tmp)
        sysname = os.uname().sysname.lower()

        for name in ['consul', 'vault', 'nomad']:
            version = OPTIONS.versions[name]
            zip_path = tmp / f'{name}_{version}_{sysname}_amd64.zip'
            url = f'https://releases.hashicorp.com/{name}/{version}/{zip_path.name}'
            download(url, zip_path)
            unzip(zip_path, cwd=tmp)
            (tmp / name).rename(PATH.bin / name)
    log.info('Done.')


def _writefile(path, content):
    with path.open('w') as f:
        f.write(content)


def _username():
    return run("whoami").strip()


def configure():
    """ Generate configuration files. """
    _writefile(PATH.consul_hcl, CONFIG.consul())
    _writefile(PATH.vault_hcl, CONFIG.vault())
    _writefile(PATH.nomad_hcl, CONFIG.nomad())
    _writefile(PATH.supervisor_conf, CONFIG.supervisor(_username()))
    log.info('Done.')


def consul_args():
    yield from [PATH.bin / 'consul', 'agent']
    if OPTIONS.dev:
        yield '-dev'
    yield from ['-config-file', PATH.consul_hcl]


def vault_args():
    yield from [PATH.bin / 'vault', 'server']
    yield from ['-config', PATH.vault_hcl]


def nomad_args():
    yield from [PATH.bin / 'nomad', 'agent']
    if OPTIONS.dev:
        yield '-dev'
    yield from ['-config', PATH.nomad_hcl]


def runserver(name):
    """ Run server [name] in foreground. """

    services = {
        'consul': consul_args,
        'vault': vault_args,
        'nomad': nomad_args,
    }

    args = [str(a) for a in services[name]()]

    env = dict(os.environ)
    if name == 'nomad':
        env['VAULT_TOKEN'] = OPTIONS.nomad_vault_token

    log.debug('+ %s', ' '.join(args))
    os.chdir(PATH.root)
    os.execve(args[0], args, env)


def autovault(timeout=60):
    """ Set up Vault automatically (initialize, unseal). """

    vault = JsonApi(f'http://{OPTIONS.vault_address}:8200/v1/')

    t0 = time()
    while time() - t0 < int(timeout):
        try:
            status = vault.get('sys/seal-status')

            if not status['sealed']:
                return

            break

        except URLError:
            sleep(.5)

    if not PATH.vault_secrets.exists():
        resp = vault.put('sys/init', {
            'secret_shares': 1,
            'secret_threshold': 1,
        })

        _secrets_ini = os.open(
            PATH.vault_secrets,
            os.O_WRONLY | os.O_CREAT,
            0o600,
        )
        with os.fdopen(_secrets_ini, 'w') as secrets_ini:
            secrets_ini.write('[vault]\n')
            secrets_ini.write(f'keys = {",".join(resp["keys"])}\n')
            secrets_ini.write(f'root_token = {resp["root_token"]}\n')

    secrets = read_vault_secrets()
    vault.put('sys/unseal', {'key': secrets['keys']})
    log.info('Done.')


class SubcommandParser(argparse.ArgumentParser):

    def add_subcommands(self, name, subcommands):
        subcommands_map = {c.__name__: c for c in subcommands}

        class SubcommandAction(argparse.Action):
            def __call__(self, parser, namespace, values, option_string=None):
                setattr(namespace, name, subcommands_map[values])

        self.add_argument(
            name,
            choices=[c.__name__ for c in subcommands],
            action=SubcommandAction,
        )


def main():
    parser = SubcommandParser(description=__doc__)
    parser.add_subcommands('cmd', [
        install,
        configure,
        runserver,
        autovault,
    ])

    (options, extra_args) = parser.parse_known_args()
    options.cmd(*extra_args)


if __name__ == '__main__':
    level = logging.DEBUG if OPTIONS.debug else logging.INFO
    log.setLevel(level)
    logging.basicConfig(
        level=level,
        format='%(asctime)s %(levelname)s %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S',
    )

    main()
