#!/usr/bin/env python3

"""
Manage a nomad + consul cluster.
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


def run(cmd, **kwargs):
    log.debug("+ %s", cmd)
    return subprocess.check_output(cmd, shell=True, **kwargs).decode('latin1')


def detect_interface():
    return run("ip route get 8.8.8.8 | awk '{ print $5; exit }'").strip()


class OPTIONS:
    interface = get_config(
        'NOMAD_NETWORK_INTERFACE',
        'network:interface',
        None,
    ) or detect_interface()

    http_address = get_config(
        'NOMAD_HTTP_ADDRESS',
        'network:http_address',
        '127.0.0.1',
    )


class VERSION:
    nomad = '0.8.7'
    consul = '1.4.3'


class PATH:
    root = Path(__file__).parent.resolve()

    bin = root / 'bin'
    nomad_bin = bin / 'nomad'
    consul_bin = bin / 'consul'

    etc = root / 'etc'
    nomad_hcl = etc / 'nomad.hcl'
    consul_hcl = etc / 'consul.hcl'
    supervisor_conf = etc / 'supervisor-cluster.conf'

    var = root / 'var'
    tmp = var / 'tmp'
    nomad_var = var / 'nomad'
    consul_var = var / 'consul'


class URL:
    consul = (
        'https://releases.hashicorp.com/consul/'
        f'{VERSION.consul}/consul_{VERSION.consul}_linux_amd64.zip'
    )
    nomad = (
        'https://releases.hashicorp.com/nomad/'
        f'{VERSION.nomad}/nomad_{VERSION.nomad}_linux_amd64.zip'
    )


class CONFIG:
    pass


CONFIG.supervisor = lambda username: f'''\
[program:nomad]
user = {username}
command = {PATH.nomad_bin} agent -config {PATH.nomad_hcl}
redirect_stderr = true

[program:consul]
user = {username}
command = {PATH.consul_bin} agent -config-file {PATH.consul_hcl}
redirect_stderr = true
'''


CONFIG.consul = lambda: f'''\
bind_addr = "127.0.0.1"
data_dir = "{PATH.consul_var}"
datacenter = "dc1"
server = true
ui = true
bootstrap_expect = 1
'''


CONFIG.nomad = lambda http_address, interface: f'''\
bind_addr = "{{{{ GetInterfaceIP `{interface}` }}}}"
data_dir = "{PATH.nomad_var}"
leave_on_interrupt = true
leave_on_terminate = true
disable_update_check = true

addresses {{
  http = "{http_address}"
}}

advertise {{
  http = "{http_address}"
}}

server {{
  enabled = true
  bootstrap_expect = 1
}}

client {{
  enabled = true
  network_interface = "{interface}"
}}
'''


def _download(url, path):
    run(f'curl -Ls "{url}" -o "{path}"')


def _unzip(zip_path, **kwargs):
    run(f'unzip "{zip_path}"', **kwargs)


def install():
    """ Install Consul and Nomad. """

    for dir in [PATH.root, PATH.bin, PATH.etc, PATH.var, PATH.tmp]:
        dir.mkdir(exist_ok=True)

    with tempfile.TemporaryDirectory(dir=PATH.tmp) as _tmp:
        tmp = Path(_tmp)

        consul_zip = tmp / 'consul.zip'
        _download(URL.consul, consul_zip)
        _unzip(consul_zip, cwd=tmp)
        (tmp / 'consul').rename(PATH.consul_bin)

        nomad_zip = tmp / 'consul.zip'
        _download(URL.nomad, nomad_zip)
        _unzip(nomad_zip, cwd=tmp)
        (tmp / 'nomad').rename(PATH.nomad_bin)


def _writefile(path, content):
    with path.open('w') as f:
        f.write(content)


def _username():
    return run("whoami").strip()


def configure():
    """ Generate configuration files. """
    http_address = OPTIONS.http_address
    interface = OPTIONS.interface

    _writefile(PATH.supervisor_conf, CONFIG.supervisor(_username()))
    _writefile(PATH.consul_hcl, CONFIG.consul())
    _writefile(PATH.nomad_hcl, CONFIG.nomad(http_address, interface))


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
