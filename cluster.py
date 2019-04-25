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

LOG_LEVEL = logging.DEBUG
log = logging.getLogger(__name__)
log.setLevel(LOG_LEVEL)

config = configparser.ConfigParser()
config.read('cluster.ini')

class PATH:
    root = Path(__file__).parent.resolve()

    cluster_py = root / 'cluster.py'
    cluster_ini = root / 'cluster.ini'
    shell = os.environ.get('SHELL', '/bin/sh')

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


def run(cmd, **kwargs):
    log.debug('+ %s', cmd)
    return subprocess.check_output(cmd, shell=True, **kwargs).decode('latin1')


def exec_shell(cmd, env=os.environ):
    log.debug('+ %s', cmd)
    os.chdir(PATH.root)
    os.execve(PATH.shell, [PATH.shell, '-c', cmd], env)


def detect_interface():
    return run("ip route get 8.8.8.8 | awk '{ print $5; exit }'").strip()


config = configparser.ConfigParser()
config.read(PATH.cluster_ini)


def get_config(env_key, ini_path, default):
    value = os.environ.get(env_key)
    if value is not None:
        return value

    (section_name, key) = ini_path.split(':')
    if section_name in config:
        section = config[section_name]
        if key in section:
            return section[key]

    return default


class OPTIONS:
    nomad_interface = get_config(
        'NOMAD_INTERFACE',
        'nomad:interface',
        None,
    ) or detect_interface()

    vault_address = get_config(
        'VAULT_ADDRESS',
        'vault:address',
        '127.0.0.1',
    )

    vault_disable_mlock = get_config(
        'VAULT_DISABLE_MLOCK',
        'vault:disable_mlock',
        'false',
    )

    nomad_address = get_config(
        'NOMAD_ADDRESS',
        'nomad:address',
        '127.0.0.1',
    )

    nomad_vault_token = get_config(
        'NOMAD_VAULT_TOKEN',
        'nomad:vault_token',
        None,
    )

    nomad_zombie_time = get_config(
        'NOMAD_ZOMBIE_TIME',
        'nomad:zombie_time',
        '4h',
    )

    supervisor_autostart = get_config(
        'SUPERVISOR_AUTOSTART',
        'supervisor:autostart',
        'off',
    )

    versions = {
        'consul': get_config(
            'CONSUL_VERSION',
            'consul:version',
            '1.4.4',
        ),
        'vault': get_config(
            'VAULT_VERSION',
            'vault:version',
            '1.1.1',
        ),
        'nomad': get_config(
            'NOMAD_VERSION',
            'nomad:version',
            '0.9.0',
        ),
    }

    dev = config.getboolean('cluster', 'dev', fallback=False)


class CONFIG:
    pass


CONFIG.consul = lambda: f'''\
bind_addr = "127.0.0.1"
data_dir = "{PATH.consul_var}"
datacenter = "dc1"
server = true
ui = true
bootstrap_expect = 1
'''


CONFIG.vault = lambda: f'''\
storage "consul" {{
  address = "{OPTIONS.vault_address}:8500"
  path = "vault/"
}}

listener "tcp" {{
  address = "{OPTIONS.vault_address}:8200"
  tls_disable = 1
}}

ui = true
disable_mlock = {OPTIONS.vault_disable_mlock}
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
  http = "{OPTIONS.nomad_address}"
  rpc = "{OPTIONS.nomad_address}"
  serf = "{OPTIONS.nomad_address}"
}}

server {{
  enabled = true
  bootstrap_expect = 1
  job_gc_threshold = "{OPTIONS.nomad_zombie_time}"
}}

client {{
  enabled = true
  network_interface = "{OPTIONS.nomad_interface}"
}}
{f"""
vault {{
  enabled = true
  address = "http://{OPTIONS.vault_address}:8200"
}}
""" if OPTIONS.nomad_vault_token else ""}
'''


CONFIG.supervisor = lambda username: f'''\
[program:consul]
user = {username}
command = {PATH.cluster_py} runserver consul
redirect_stderr = true
autostart = {OPTIONS.supervisor_autostart}

[program:vault]
user = {username}
command = {PATH.cluster_py} runserver vault
redirect_stderr = true
autostart = {OPTIONS.supervisor_autostart}

[program:nomad]
user = {username}
command = {PATH.cluster_py} runserver nomad
redirect_stderr = true
autostart = {OPTIONS.supervisor_autostart}

[group:cluster]
programs = consul,vault,nomad
'''


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
            url = f'https://releases.hashicorp.com/{name}/{version}/{zip.name}'
            download(url, zip_path)
            unzip(zip_path, cwd=tmp)
            (tmp / name).rename(PATH.bin / name)


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


def exec_consul():
    exec_shell(
        f'{PATH.bin / "consul"} agent '
        f'{"-dev " if OPTIONS.dev else ""}'
        f'-config-file {PATH.consul_hcl}',
    )


def exec_vault():
    exec_shell(
        f'{PATH.bin / "vault"} server '
        f'-config {PATH.vault_hcl}',
    )


def exec_nomad():
    env = dict(os.environ, VAULT_TOKEN=OPTIONS.nomad_vault_token)
    exec_shell(
        f'{PATH.bin / "nomad"} agent '
        f'{"-dev " if OPTIONS.dev else ""}'
        f'-config {PATH.nomad_hcl}',
        env=env,
    )


def runserver(name):
    """ Run server [name] in foreground. """
    services = {
        'consul': exec_consul,
        'vault': exec_vault,
        'nomad': exec_nomad,
    }

    exec_service = services[name]
    exec_service()


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
    ])

    (options, extra_args) = parser.parse_known_args()
    options.cmd(*extra_args)


if __name__ == '__main__':
    logging.basicConfig(
        level=LOG_LEVEL,
        format='%(asctime)s %(levelname)s %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S',
    )

    main()
