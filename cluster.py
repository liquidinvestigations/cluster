#!/usr/bin/env python3

"""
Manage a Consul + Vault + Nomad cluster.
"""

import os
import logging
from pathlib import Path
import tempfile
import subprocess
import configparser
from time import time, sleep
import json
from urllib.request import Request, urlopen
from urllib.error import URLError
from urllib.parse import urlencode
import sys
import signal
import shutil
import socket

import click
from jinja2 import Template

log = logging.getLogger(__name__)

config = configparser.ConfigParser()
config.read('cluster.ini')


class PATH:
    executable = sys.executable
    root = Path(__file__).parent.resolve()

    cluster_py = root / 'cluster.py'
    cluster_ini = root / 'cluster.ini'

    bin = root / 'bin' if not os.getenv('DOCKER_BIN') else Path(os.environ['DOCKER_BIN'])  # noqa: E501

    etc = root / 'etc'
    templates = root / 'templates'

    var = root / 'var'
    consul_var = var / 'consul'
    nomad_var = var / 'nomad'
    vault_secrets = var / 'vault-secrets.ini'

    supervisord_conf = etc / 'supervisord.conf'
    supervisord_sock = var / 'supervisor' / 'supervisor.sock'


def render(template_filename, options):
    with open(template_filename, 'r') as f:
        template = Template(f.read())
        return template.render(**options)


def run(cmd, **kwargs):
    log.debug('+ %s', cmd)
    return subprocess.check_output(cmd, shell=True, **kwargs).decode('latin1')


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


ALL_JOBS = ['fabio', 'prometheus', 'alertmanager', 'grafana', 'dnsmasq']
SYSTEM_JOBS = ['dnsmasq', 'fabio']


class OPTIONS:
    network_address = config.get('network', 'address', fallback=None)
    network_interface = config.get('network', 'interface', fallback=None)
    network_create_bridge = config.getboolean('network', 'create_bridge',
                                              fallback=False)
    network_forward_ports = config.get('network', 'forward_ports', fallback='')
    network_forward_address = config.get('network', 'forward_address', fallback='')  # noqa: E501

    consul_address = network_address

    vault_address = network_address
    vault_disable_mlock = config.getboolean('vault', 'disable_mlock', fallback=False)  # noqa: E501

    nomad_address = network_address
    nomad_advertise = network_address
    nomad_interface = network_interface
    _nomad_meta = {key: config.get('nomad_meta', key) for key in config['nomad_meta']} if 'nomad_meta' in config else {}  # noqa: E501
    nomad_meta = "\n".join(f'{key} = "{value}"' for key, value in _nomad_meta.items())  # noqa: E501
    nomad_memory = config.get('nomad', 'memory', fallback=0)
    nomad_zombie_time = config.get('nomad', 'zombie_time', fallback='4h')
    nomad_delete_data_on_start = config.getboolean(
        'nomad', 'delete_data_on_start', fallback=False)
    nomad_drain_on_stop = config.getboolean(
        'nomad', 'drain_on_stop', fallback=True)

    versions = {
        'consul': config.get('consul', 'version', fallback='1.5.1'),
        'vault': config.get('vault', 'version', fallback='1.1.3'),
        'nomad': config.get('nomad', 'version', fallback='0.9.3'),
    }

    node_name = config.get('cluster', 'node_name',
                           fallback=socket.gethostname())
    dev = config.getboolean('cluster', 'dev', fallback=False)
    debug = config.getboolean('cluster', 'debug', fallback=False)

    _disable = config.get('cluster', 'disable', fallback='all').strip().split(',')  # noqa: E501
    nomad_vault_token = read_vault_secrets()['root_token']

    bootstrap_expect = config.getint('cluster', 'bootstrap_expect', fallback=1)
    _retry_join = config.get('cluster', 'retry_join', fallback='')
    retry_join = _retry_join.split(',') if _retry_join else []
    nomad_retry_join = nomad_retry_join_section(retry_join)
    consul_retry_join = consul_retry_join_section(retry_join)
    nomad_client_servers = nomad_client_servers_section(retry_join)

    wait_max = config.getfloat('deploy', 'wait_max_sec', fallback=240)
    wait_interval = config.getfloat('deploy', 'wait_interval', fallback=3)
    wait_green_count = config.getint('deploy', 'wait_green_count', fallback=3)

    @classmethod
    def get_jobs(cls):
        if cls._disable == ['all']:
            return []
        elif not cls._disable or cls._disable == ['none']:
            return ALL_JOBS
        return [s for s in ALL_JOBS if s not in cls._disable]

    @classmethod
    def validate(cls):
        assert cls.network_address, \
            "cluster.ini: network.address not set"
        assert cls.network_interface, \
            "cluster.ini: network.interface not set"
        if not sys.platform.startswith('linux'):
            assert not cls.network_create_bridge, \
                "cluster.ini: network.create_bridge must be unset on macOS"
            assert not cls.network_forward_ports, \
                "cluster.ini: network.forward_ports must be unset on macOS"
        if cls._disable and cls._disable not in (['all'], ['none']):
            assert all(s in ALL_JOBS for s in cls._disable), \
                'unidentified service in "cluster.disable" list'


class JsonApi:
    def __init__(self, endpoint):
        self.endpoint = endpoint

    def send(self, req):
        log.debug('%s %s', req.get_method(), req.get_full_url())
        with urlopen(req) as res:
            if res.status == 200:
                res_body = json.load(res)
                return res_body

    def get(self, url, data=None):
        params = '?' + urlencode(data) if data else ''
        req = Request(f'{self.endpoint}{url}{params}')
        return self.send(req)

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


@click.group()
def cli():
    pass


@cli.command()
def install():
    """ Install Consul, Vault and Nomad. """

    log.info("Installing...")
    PATH.bin.mkdir(exist_ok=True)

    with tempfile.TemporaryDirectory() as _tmp:
        tmp = Path(_tmp)
        sysname = os.uname().sysname.lower()

        for name in ['consul', 'vault', 'nomad']:
            version = OPTIONS.versions[name]
            zip_path = tmp / f'{name}_{version}_{sysname}_amd64.zip'
            url = f'https://releases.hashicorp.com/{name}/{version}/{zip_path.name}'  # noqa: E501
            download(url, zip_path)
            unzip(zip_path, cwd=tmp)
            (tmp / name).rename(PATH.bin / name)
    for name in ['consul', 'vault', 'nomad']:
        log.info(run(f'{PATH.bin}/{name} --version'))
    log.info('Done.')


def _writefile(path, content):
    with path.open('w') as f:
        f.write(content)


@cli.command()
def configure():
    """ Generate configuration files by rendering templates from templates into
    etc. """

    log.info("Configuring...")

    OPTIONS.validate()

    for dir in [PATH.etc, PATH.var]:
        dir.mkdir(exist_ok=True)

    for template in PATH.templates.iterdir():
        with open(PATH.etc / template.name, 'w') as dest:
            log.info('rendering %s', str(template))
            dest.write(render(template, {'OPTIONS': OPTIONS, 'PATH': PATH}))
    log.info('Done.')


def consul_args():
    yield from [PATH.bin / 'consul', 'agent']
    if OPTIONS.dev:
        yield '-dev'
    yield from ['-config-file', PATH.etc / 'consul.hcl']


def vault_args():
    yield from [PATH.bin / 'vault', 'server']
    yield from ['-config', PATH.etc / 'vault.hcl']


def nomad_args():
    yield from [PATH.bin / 'nomad', 'agent']
    if OPTIONS.dev:
        yield '-dev'
    yield from ['-config', PATH.etc / 'nomad.hcl']


@cli.command()
@click.argument('name', type=str)
def runserver(name):
    """ Run server [name] in foreground. """

    log.info("Running %s server...", name)
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


def nomad_drain(enabled):
    """Forcefully drain nomad jobs on the current node."""

    if enabled:
        log.info("Draining nomad jobs...")
    else:
        log.info("Disabling nomad drain...")
    args = [PATH.bin / 'nomad', 'node', 'drain', '-self']
    if enabled:
        args += ['-force', '-enable']
    else:
        args += ['-disable']

    env = dict(os.environ)
    env['NOMAD_ADDR'] = 'http://' + OPTIONS.nomad_address + ':4646'
    subprocess.check_call(args, env=env)
    log.info("Drain set.")


@cli.command()
def stop():
    """Drains Nomad jobs and stops all supervisor services."""
    _stop()


def _stop():
    """Implements draining Nomad jobs and stopping supervisor with SIGQUIT."""

    log.info("Stopping cluster...")
    if OPTIONS.nomad_drain_on_stop:
        try:
            nomad_drain(True)
        except subprocess.CalledProcessError as e:
            log.warning(e)
            log.warning("Nomad drain failed, it's probably dead.")

    pid = supervisor_pid()
    log.info(f"Supervisor has PID={pid}")
    os.kill(pid, signal.SIGQUIT)
    log.info("SIGQUIT sent to supervisor!")

    STOP_TIMEOUT = 15
    t0 = time()
    while time() < t0 + STOP_TIMEOUT:
        try:
            sleep(1)
            supervisor_pid()
        except subprocess.CalledProcessError:
            log.info("Everything stopped.")
            return
    log.warning(f"Supervisor didn't die in {STOP_TIMEOUT} seconds...")


@cli.command()
def run_jobs():
    """ Install all *.nomad jobs under etc/ """

    log.info("Running nomad jobs...")
    env = dict(os.environ)
    env['NOMAD_ADDR'] = 'http://' + OPTIONS.nomad_address + ':4646'

    for job in OPTIONS.get_jobs():
        nomad_job_file = PATH.etc / f'{job}.nomad'
        log.info('running job %s', nomad_job_file)
        subprocess.check_call(f'{PATH.bin / "nomad"} job run {nomad_job_file}',
                              env=env, shell=True)
    log.info("Done.")


@cli.command()
@click.argument('timeout', default=60, type=int)
def autovault(timeout):
    """ Set up Vault automatically (initialize, unseal). """

    vault = JsonApi(f'http://{OPTIONS.vault_address}:8200/v1')

    log.info('Unsealing vault...')
    t0 = time()
    while time() - t0 < int(timeout):
        try:
            status = vault.get('/sys/seal-status')

            if not status['sealed']:
                return

            break

        except URLError:
            sleep(.5)

    if not PATH.vault_secrets.exists():
        resp = vault.put('/sys/init', {
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
    vault.put('/sys/unseal', {'key': secrets['keys']})
    log.info('Done.')


@cli.command()
@click.pass_context
@click.option('-d', '--detach', is_flag=True)
def supervisord(ctx, detach):
    """ Run the supervisor daemon in the foreground with the current user. """

    log.info("setting signal handler")
    signal.signal(signal.SIGTERM, lambda _signum, _frame: _stop())

    ctx.invoke(configure)
    (PATH.var / 'supervisor').mkdir(exist_ok=True)

    log.info("Starting supervisord...")
    pid = os.fork()
    if pid == 0:
        args = ['supervisord', '-c', str(PATH.supervisord_conf), '-n']
        sleep(5)
        log.debug('+ %s', ' '.join(args))
        os.execvp(args[0], args)

    wait_for_supervisor()
    if detach:
        return

    # wait for signal and stop if supervisor dies
    while True:
        try:
            supervisor_pid()
        except subprocess.CalledProcessError:
            log.info('Supervisor stopped.')
            return
        sleep(1)


def _supervisorctl(*args):
    joined_args = " ".join(args)
    conf = PATH.etc / "supervisord.conf"
    subprocess.check_call(f'supervisorctl -c {conf} {joined_args}',
                          shell=True)


def supervisor_pid():
    cmd = f'supervisorctl -c {PATH.supervisord_conf} pid'
    return int(subprocess.check_output(cmd, shell=True).decode('latin1'))


def wait_for_supervisor():
    SUPERVISOR_TIMEOUT = 15
    t0 = time()
    while time() < t0 + SUPERVISOR_TIMEOUT:
        try:
            supervisor_pid()
            break
        except subprocess.CalledProcessError as e:
            log.warning(e)
        sleep(2)
    else:
        raise RuntimeError('supervisord did not start')


@cli.command()
@click.argument('args', nargs=-1, type=str)
def supervisorctl(args):
    """ Runs a supervisorctl command. """

    wait_for_supervisor()
    _supervisorctl(*args)


def get_checks(service, self_only):
    consul = JsonApi(f'http://{OPTIONS.consul_address}:8500/v1')
    if self_only:
        node_name = consul.get('/agent/self')['Config']['NodeName']
        return consul.get(f'/health/checks/{service}', data={
            'filter': f'Node == "{node_name}"'
        })
    else:
        return consul.get(f'/health/checks/{service}')


def get_failed_checks(health_checks, self_only):
    """Generates a sequence of (service, check, status)
    tuples for all failing checks after checking with Consul"""

    consul_status = {}
    for service in health_checks:
        consul_checks = get_checks(service, self_only)
        for s in consul_checks:
            key = service, s['Name']
            if key in consul_status:
                consul_status[key] = 'appears twice'
                continue
            consul_status[key] = s['Status']

    for service, checks in health_checks.items():
        for check in checks:
            status = consul_status.get((service, check), 'missing')
            if 'Prometheus' in checks:
                log.error('prom status: %s', status)
            if status != 'passing':
                yield service, check, status


def wait_for_checks(health_checks, self_only=False):
    """Waits health checks to become green for green_count times in a row.

    If self_only is True we only look at health checks registered on the
    current node."""

    services = sorted(health_checks.keys())
    if not services:
        return
    log.info("Waiting on %s health checks for %s %s",
             sum(map(len, health_checks.values())),
             str(services),
             '(self only)' if self_only else '')

    t0 = time()
    greens = 0
    timeout = t0 + OPTIONS.wait_max + \
        OPTIONS.wait_interval * OPTIONS.wait_green_count
    last_spam = t0 - 1000
    while time() < timeout:
        sleep(OPTIONS.wait_interval)
        failed = sorted(get_failed_checks(health_checks, self_only))

        if failed:
            greens = 0
        else:
            greens += 1

        if greens >= OPTIONS.wait_green_count:
            log.info(f"Checks for {services} green after {time() - t0:.02f}s")
            return

        # No chance to get enough greens
        no_chance_timestamp = timeout - \
            OPTIONS.wait_interval * OPTIONS.wait_green_count
        if greens == 0 and time() >= no_chance_timestamp:
            break

        if time() - last_spam > 10.0:
            failed_text = ''
            for service, check, status in failed:
                failed_text += f'\n - {service}: check "{check}" is {status}'
            if failed:
                failed_text += '\n'
            log.debug(f'greens: {greens}, failed: {len(failed)}{failed_text}')
            last_spam = time()

    msg = f'Checks are failing after {time() - t0:.02f}s: \n - {failed_text}'
    raise RuntimeError(msg)


HEALTH_CHECKS = {
    'nomad': ['Nomad Server RPC Check',
              'Nomad Server HTTP Check',
              'Nomad Server Serf Check'],
    'nomad-client': ['Nomad Client HTTP Check'],
    'vault': ['Vault Sealed Status'],
    'grafana': ['Grafana alive on HTTP'],
    'prometheus': ['Prometheus alive on HTTP'],
    'fabio': ["Service 'fabio' check"],
}


def wait_for_consul():
    consul = JsonApi(f'http://{OPTIONS.consul_address}:8500/v1')
    CONSUL_TIMEOUT = 15
    t0 = time()
    while time() < t0 + CONSUL_TIMEOUT:
        try:
            leader = consul.get('/status/leader')
            assert leader, 'Consul has no leader'
            node_name = consul.get('/agent/self')['Config']['NodeName']
            node_health = consul.get('/health/service/consul', data={
                'filter': f'Node.Node == "{node_name}"'
            })
            assert node_health[0]['Checks'][0]['Status'] == 'passing'
            log.info("Consul UP and running with leader %s", leader)
            break
        except TypeError:
            log.warning('Consul health check not registered')
        except AssertionError as e:
            log.warning('Consul not healthy: %s', e)
        except URLError as e:
            log.warning('Consul %s', e)
        sleep(2)
    else:
        raise RuntimeError('Consul did not start.')


@cli.command()
def wait():
    """ Wait for all services to be up and running. """

    wait_for_supervisor()
    wait_for_consul()
    wait_for_checks({
        k: v for k, v in HEALTH_CHECKS.items()
        if k in ['vault', 'nomad', 'nomad-client']
    }, self_only=True)

    wait_for_checks({
        k: v for k, v in HEALTH_CHECKS.items()
        if k in OPTIONS.get_jobs() and k not in SYSTEM_JOBS
    })


def restart_nomad_until_it_works():
    nomad = JsonApi(f'http://{OPTIONS.nomad_address}:4646/v1')
    NOMAD_MAX_RESTARTS = 5
    NOMAD_LEADERLESS_TIMEOUT = 15

    for i in range(1, NOMAD_MAX_RESTARTS + 1):
        t0 = time()
        while time() < t0 + NOMAD_LEADERLESS_TIMEOUT:
            try:
                leader = nomad.get('/status/leader')
                assert leader
                assert leader != 'No cluster leader'
                log.info("Nomad UP and running with leader %s", leader)
                return
            except AssertionError:
                log.warning('Nomad has no leader...')
            except URLError as e:
                log.warning('Waiting for Nomad... %s', e)
            sleep(2)
        log.warning('nomad restart #%s/%s', i, NOMAD_MAX_RESTARTS)
        _supervisorctl('restart', 'nomad')
    else:
        raise RuntimeError('Nomad did not start.')


@cli.command()
@click.pass_context
def start(ctx):
    """ Configures and starts all services if they're not already up. """

    wait_for_supervisor()
    _supervisorctl("stop", "nomad", "consul", "vault", "autovault")
    _supervisorctl("update")

    # delete consul health checks so they won't get doubled
    log.info("Deleting old Consul health checks...")
    shutil.rmtree(PATH.var / 'consul' / 'checks', ignore_errors=True)
    ctx.invoke(supervisorctl, args=["start", "consul"])
    wait_for_consul()

    _supervisorctl("start", "vault")
    _supervisorctl("start", "autovault")
    wait_for_checks({'vault': HEALTH_CHECKS['vault']}, self_only=True)

    if OPTIONS.nomad_delete_data_on_start:
        log.info("Deleting old Nomad data...")
        shutil.rmtree(PATH.var / 'nomad', ignore_errors=True)

    _supervisorctl("start", "nomad")
    restart_nomad_until_it_works()
    wait_for_checks({
        'nomad': HEALTH_CHECKS['nomad'],
        'nomad-client': HEALTH_CHECKS['nomad-client'],
    }, self_only=True)
    nomad_drain(False)

    ctx.invoke(run_jobs)

    # mark that something's up by failing this "start" job
    ctx.invoke(wait)
    log.info("All done.")


@cli.command()
def configure_network():
    """Configures network according to the ini file [network] settings."""

    assert sys.platform.startswith('linux'), \
        'configure-network is only available on Linux'

    create_script = str((PATH.root / 'scripts' / 'create-bridge.sh'))
    forward_script = str((PATH.root / 'scripts' / 'forward-ports.sh'))

    if OPTIONS.network_create_bridge:
        env = dict(os.environ)
        env['bridge_name'] = OPTIONS.network_interface
        env['bridge_address'] = OPTIONS.network_address

        log.info("Creating network bridge...")
        subprocess.check_call([create_script], env=env)
    else:
        log.info("Skipping bridge creation.")

    if OPTIONS.network_forward_ports:
        env = dict(os.environ)
        env['bridge_name'] = OPTIONS.network_interface
        env['bridge_address'] = OPTIONS.network_address
        env['forward_address'] = OPTIONS.network_forward_address
        env['forward_ports'] = OPTIONS.network_forward_ports

        log.info("Forwarding network ports...")
        subprocess.check_call([forward_script], env=env)
    else:
        log.info("Skipping port forwarding.")

    log.info("Network setup done.")


if __name__ == '__main__':
    level = logging.DEBUG if OPTIONS.debug else logging.INFO
    log.setLevel(level)
    logging.basicConfig(
        level=level,
        format='%(asctime)s %(levelname)s %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S',
    )

    cli()
