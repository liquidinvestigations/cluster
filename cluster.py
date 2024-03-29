#!/usr/bin/env python3

"""
Manage a Consul + Vault + Nomad cluster.
"""

import platform
import os
import multiprocessing
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
from collections import defaultdict

import click
from jinja2 import Environment, FileSystemLoader

log = logging.getLogger(__name__)


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


jinja_env = Environment(loader=FileSystemLoader(str(PATH.templates)))
jinja_env.globals['int'] = int


def render(template_filename, options):
    template = jinja_env.get_template(template_filename)
    return template.render(**options)


def run(cmd, **kwargs):
    log.info('+ %s', cmd)
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


def nomad_server_join_section(servers):
    if not servers:
        return ''
    quoted = [f'"{ip}:4648"' for ip in servers]
    return f'''
    server_join {{
        retry_join = [{", ".join(quoted)}]
        retry_interval = "6s"
        retry_max = 66
    }}'''


def consul_retry_join_section(servers):
    if not servers:
        return ''
    quoted = [f'"{ip}"' for ip in servers]
    return f'retry_join = [{", ".join(quoted)}]'


def translate_job_name(option_name):
    if option_name == 'fabio':
        return 'cluster-fabio'
    return option_name


def _get_memory_mb(memory_percent):
    mem_bytes = os.sysconf('SC_PAGE_SIZE') * os.sysconf('SC_PHYS_PAGES')
    mem_mb = mem_bytes / (1024.**2)
    mem_mb = int(mem_mb * memory_percent / 100 / 100) * 100
    log.info('configuring nomad memory: %s MB', mem_mb)
    assert mem_mb > 1000, 'memory too low <1000MB'
    return mem_mb


class OPTIONS:
    network_address = config.get('network', 'address', fallback=None)
    network_interface = config.get('network', 'interface', fallback=None)
    network_create_bridge = config.getboolean('network', 'create_bridge',
                                              fallback=False)
    network_forward_ports = config.get('network', 'forward_ports', fallback='')
    network_forward_address = config.get('network', 'forward_address', fallback='')  # noqa: E501

    consul_address = network_address

    vault_address = network_address
    vault_disable_mlock = config.getboolean('vault', 'disable_mlock', fallback=True)  # noqa: E501

    nomad_address = network_address
    nomad_advertise = network_address
    nomad_interface = network_interface
    _nomad_meta = {key: config.get('nomad_meta', key) for key in config['nomad_meta']} if 'nomad_meta' in config else {}  # noqa: E501
    nomad_meta = "\n".join(f'{key} = "{value}"' for key, value in _nomad_meta.items())  # noqa: E501
    nomad_memory_percent = config.getint('nomad', 'memory_percent',
                                         fallback=85)
    nomad_memory = _get_memory_mb(nomad_memory_percent)
    nomad_zombie_time = config.get('nomad', 'zombie_time', fallback='4h')
    nomad_delete_data_on_start = config.getboolean(
        'nomad', 'delete_data_on_start', fallback=False)
    nomad_drain_on_stop = config.getboolean(
        'nomad', 'drain_on_stop', fallback=True)
    nomad_schedulers = min(
        config.getint('nomad', 'nomad_schedulers', fallback=2),
        multiprocessing.cpu_count())

    versions = {
        'consul': config.get('consul', 'version', fallback='1.15.3'),
        'vault': config.get('vault', 'version', fallback='1.13.3'),
        'nomad': config.get('nomad', 'version', fallback='1.5.6'),
    }

    node_name = config.get('cluster', 'node_name',
                           fallback=socket.gethostname())
    dev = config.getboolean('cluster', 'dev', fallback=False)
    debug = config.getboolean('cluster', 'debug', fallback=False)
    client_only = config.getboolean('cluster', 'client', fallback=False)

    nomad_vault_token = read_vault_secrets()['root_token']

    bootstrap_expect = config.getint('cluster', 'bootstrap_expect', fallback=1)
    _retry_join = config.get('cluster', 'retry_join', fallback='')
    retry_join = _retry_join.split(',') if _retry_join else []
    nomad_server_join = nomad_server_join_section(retry_join)
    consul_retry_join = consul_retry_join_section(retry_join)

    influxdb_memory_limit = config.getint('cluster',
                                          'influxdb_memory_limit',
                                          fallback=512)
    prometheus_memory_limit = config.getint('cluster',
                                            'prometheus_memory_limit',
                                            fallback=384)

    wait_max = config.getfloat('deploy', 'wait_max_sec', fallback=333)
    wait_interval = config.getfloat('deploy', 'wait_interval', fallback=2)
    wait_green_count = config.getint('deploy', 'wait_green_count', fallback=3)

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


class JsonApi:
    def __init__(self, endpoint):
        self.endpoint = endpoint

    def send(self, req):
        with urlopen(req) as res:
            if res.status == 200:
                res_body = json.load(res)
                return res_body

    def get(self, url, params=None):
        encoded = '?' + urlencode(params) if params else ''
        req = Request(f'{self.endpoint}{url}{encoded}')
        return self.send(req)

    def put(self, url, data):
        return self.send(Request(
            f'{self.endpoint}{url}',
            json.dumps(data).encode('utf8'),
            {'Content-Type': 'application/json'},
            method='PUT',
        ))


def download(url, path):
    log.info(f'+ downloading from {url} to {path}')
    with urlopen(url) as res:
        if res.status != 200:
            return
        with open(path, 'wb') as f:
            f.write(res.read())


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

    with tempfile.TemporaryDirectory(dir=PATH.var) as _tmp:
        tmp = Path(_tmp)
        sysname = os.uname().sysname.lower()

        for name in ['consul', 'vault', 'nomad']:
            version = OPTIONS.versions[name]
            _platform = 'arm64' if platform.machine() == 'aarch64' else 'amd64'
            zip_path = tmp / f'{name}_{version}_{sysname}_{_platform}.zip'
            url = f'https://releases.hashicorp.com/{name}/{version}/{zip_path.name}'  # noqa: E501
            download(url, zip_path)
            unzip(zip_path, cwd=tmp)
            (tmp / name).rename(PATH.bin / name)
    for name in ['consul', 'vault', 'nomad']:
        log.info(run(f'{PATH.bin}/{name} --version').strip())
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
        if not template.is_file():
            continue

        with open(PATH.etc / template.name, 'w') as dest:
            log.debug('rendering %s', str(template))
            text = render(template.name, {'OPTIONS': OPTIONS, 'PATH': PATH})
            dest.write(text)
    log.info('Configuration done.')


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
    sleep(1)
    services = {
        'consul': consul_args,
        'vault': vault_args,
        'nomad': nomad_args,
    }

    args = [str(a) for a in services[name]()]

    env = dict(os.environ)
    if name == 'nomad':
        env['VAULT_TOKEN'] = OPTIONS.nomad_vault_token

    log.info('+ %s', ' '.join(args))
    os.chdir(PATH.root)
    _supervisorctl("restart", "autovault")
    os.execve(args[0], args, env)


def first(items, name_plural='items'):
    assert items, f"No {name_plural} found"

    if len(items) > 1:
        log.warning(
            f"Found multiple {name_plural}: %r, choosing the first one",
            items,
        )

    return items[0]


@cli.command()
@click.option('--tty', '-t', is_flag=True)
@click.argument('name', type=str, required=True)
@click.argument('args', type=click.UNPROCESSED, nargs=-1, required=True)
def nomad_exec(name, args, tty=False):
    """Execute command in task container using `nomad job exec`.

    :param name: string in the format JOB:TASK, for example influxdb:influxdb
    :param args: arguments to the exec function
    :param tty: if true, instruct docker to allocate a pseudo-TTY
    """

    nomad = JsonApi(f'http://{OPTIONS.nomad_address}:4646/v1')
    [job, task] = name.split(':')

    def job_allocations(job):
        return nomad.get(f'/job/{job}/allocations')

    def allocs():
        for alloc in job_allocations(job):
            if task not in (alloc.get('TaskStates', []) or []):
                continue
            if alloc['ClientStatus'] != 'running':
                continue
            yield alloc['ID']

    alloc_id = first(list(allocs()), f'{name} allocs')

    nomad_cmd = [str(PATH.bin / 'nomad'), 'alloc', 'exec']

    if tty:
        nomad_cmd += ['-t']

    nomad_cmd += [
        '-address', 'http://' + OPTIONS.nomad_address + ':4646',
        '-task', task,
        alloc_id,
    ]

    nomad_cmd += list(args)
    log.debug(f'exec {nomad_cmd}')
    os.execvp(nomad_cmd[0], nomad_cmd)


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
    _supervisorctl('stop', 'all')

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
@click.argument('timeout', default=60, type=int)
def autovault(timeout):
    """ Set up Vault automatically (initialize, unseal). """

    vault = JsonApi(f'http://{OPTIONS.vault_address}:8200/v1')

    log.info('Unsealing vault...')
    # rate limit the restarts from supervisor
    sleep(1.1)
    t0 = time()
    while time() - t0 < int(timeout):
        try:
            vault.get('/sys/health', params={
                'standbyok': 'true',
                'sealedcode': '200',
                'uninitcode': '200',

            })
            vault.get('/sys/seal-status')
            # we got a status, continue
            break

        except URLError as e:
            log.warning(e)
            sleep(2)

    # create, overwrite vault secrets file
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
    assert PATH.vault_secrets.exists(), 'no vault secrets file created!'
    userid = os.getenv('USERID', '0') + ':' + os.getenv('GROUPID', '0')
    chown_cmd = f'chown {userid} {PATH.vault_secrets}'
    try:
        log.info('chown successful: %s', str(run(chown_cmd)))
    except Exception as e:
        log.info('cannot chown the password file: %s', str(e))

    secrets = read_vault_secrets()
    vault.put('/sys/unseal', {'key': secrets['keys']})
    assert not vault.get('/sys/health', params={'standbyok': 'true'})['sealed']
    log.info('Done.')


@cli.command()
@click.pass_context
@click.option('-d', '--detach', is_flag=True)
def supervisord(ctx, detach):
    """ Run the supervisor daemon in the foreground with the current user. """

    log.info("setting signal handler")
    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGQUIT):
        signal.signal(sig, lambda _signum, _frame: _stop())

    ctx.invoke(configure)
    (PATH.var / 'supervisor').mkdir(exist_ok=True)

    log.info("Starting supervisord...")
    pid = os.fork()
    if pid == 0:
        args = ['supervisord', '-c', str(PATH.supervisord_conf), '-n']
        sleep(5)
        log.debug('+ %s', ' '.join(args))
        # Start supervisord in a new process group, so
        # SIGINT and others won't be propagated to this
        # process from the parent.
        os.setsid()
        os.execvp(args[0], args)

    wait_for_supervisor()
    if detach:
        return

    os.wait()


def _supervisorctl(*ctl_args):
    args = ['supervisorctl', '-c', str(PATH.supervisord_conf)] + list(ctl_args)
    subprocess.check_call(args, shell=False)


def supervisor_pid():
    args = ['supervisorctl', '-c', str(PATH.supervisord_conf), 'pid']
    return int(subprocess.check_output(args, shell=False).decode('latin1'))


def wait_for_supervisor():
    SUPERVISOR_TIMEOUT = 15
    t0 = time()
    while time() < t0 + SUPERVISOR_TIMEOUT:
        try:
            supervisor_pid()
            break
        except (OSError, subprocess.CalledProcessError) as e:
            log.debug('waiting for supervisor: %s', e)
        sleep(2)
    else:
        raise RuntimeError('supervisord did not start')


@cli.command()
@click.argument('args', nargs=-1, type=click.UNPROCESSED)
def supervisorctl(args):
    """ Runs a supervisorctl command. """

    wait_for_supervisor()
    _supervisorctl(*args)


def get_checks(service, self_only):
    consul = JsonApi(f'http://{OPTIONS.consul_address}:8500/v1')
    if self_only:
        node_name = consul.get('/agent/self')['Config']['NodeName']
        return consul.get(f'/health/checks/{service}', params={
            'filter': f'Node == "{node_name}"'
        })
    else:
        return consul.get(f'/health/checks/{service}')


def get_failed_checks(health_checks, self_only, allow_duplicates):
    """Generates a sequence of (service, check, status)
    tuples for all failing checks after checking with Consul"""

    def pick_worst(a, b):
        for s in ['critical', 'warning', 'passing']:
            if s in [a, b]:
                return s
        raise RuntimeError(f'Unknown status: "{a}" and "{b}"')

    consul_status = {}
    for service in health_checks:
        consul_checks = get_checks(service, self_only)
        for s in consul_checks:
            key = service, s['Name']
            if key in consul_status:
                if allow_duplicates:
                    consul_status[key] = pick_worst(
                        consul_status[key],
                        s['Status'],
                    )
                else:
                    consul_status[key] = 'appears twice'
            else:
                consul_status[key] = s['Status']

    for service, checks in health_checks.items():
        for check in checks:
            status = consul_status.get((service, check), 'missing')
            if status != 'passing':
                yield service, check, status


def wait_for_checks(health_checks, self_only=False, allow_duplicates=False):
    """Waits health checks to become green for green_count times in a row.

    If self_only is True we only look at health checks registered on the
    current node."""

    services = sorted(health_checks.keys())
    if not services:
        return

    t0 = time()
    timeout = t0 + OPTIONS.wait_max + \
        OPTIONS.wait_interval * OPTIONS.wait_green_count
    log.debug("Waiting %ss on %s health checks for %s %s",
              timeout - t0,
              sum(map(len, health_checks.values())),
              str(services),
              f'(self_only: {self_only}, duplicates: {allow_duplicates})')

    greens = 0
    last_spam = t0 + 1
    while time() < timeout:
        sleep(OPTIONS.wait_interval)
        failed = sorted(get_failed_checks(health_checks,
                                          self_only,
                                          allow_duplicates))

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
            last_spam = time()

    msg = f'Checks are failing after {time() - t0:.02f}s: \n - {failed_text}'
    raise RuntimeError(msg)


HEALTH_CHECKS = defaultdict(list)
for k, v in ({
    'nomad': [
        'Nomad Server RPC Check',
        'Nomad Server HTTP Check',
        'Nomad Server Serf Check',
    ],
    'nomad-client': ['Nomad Client HTTP Check'],
    'vault': ['Vault Sealed Status'],
    'grafana': ['Grafana alive on HTTP'],
    'telegraf': ['http'],
    # 'influxdb': ['http'],
    'prometheus': ['Prometheus alive on HTTP'],
    'cluster-fabio': ["tcp"],
}).items():
    HEALTH_CHECKS[k] = v
if OPTIONS.client_only:
    for k in list(HEALTH_CHECKS.keys()):
        if k not in ['nomad-client', 'cluster-fabio']:
            del HEALTH_CHECKS[k]


def wait_for_consul():
    consul = JsonApi(f'http://{OPTIONS.consul_address}:8500/v1')
    t0 = time()
    while time() < t0 + OPTIONS.wait_max:
        try:
            leader = consul.get('/status/leader')
            assert leader, 'Consul has no leader'
            node_name = consul.get('/agent/self')['Config']['NodeName']
            node_health = consul.get('/health/service/consul', params={
                'filter': f'Node.Node == "{node_name}"'
            })

            if not OPTIONS.client_only:
                assert node_health[0]['Checks'][0]['Status'] == 'passing', \
                    'Consul self node health check is failing'

            log.info("Consul UP and running with leader %s", leader)
            return
        except IndexError:
            log.debug('Consul self node health check not registered')
        except AssertionError as e:
            log.debug(e)
        except URLError as e:
            log.debug('Consul %s', e)
        sleep(OPTIONS.wait_interval)
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


def restart_nomad_until_it_works():
    nomad = JsonApi(f'http://{OPTIONS.nomad_address}:4646/v1')
    NOMAD_MAX_RESTARTS = 5
    NOMAD_LEADERLESS_TIMEOUT = 45

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
            sleep(3)
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
    shutil.rmtree(PATH.var / 'consul' / 'services', ignore_errors=True)
    ctx.invoke(supervisorctl, args=["start", "consul"])
    wait_for_consul()

    _supervisorctl("start", "vault")
    wait_for_checks({'vault': HEALTH_CHECKS['vault']}, self_only=True)

    if OPTIONS.nomad_delete_data_on_start:
        log.info("Deleting old Nomad data...")
        shutil.rmtree(PATH.var / 'nomad', ignore_errors=True)

    try:
        _supervisorctl("start", "nomad")
    except subprocess.CalledProcessError as e:
        log.warning('initial Nomad start failed: %s', e)
    restart_nomad_until_it_works()
    wait_for_checks({
        'nomad': HEALTH_CHECKS['nomad'],
        'nomad-client': HEALTH_CHECKS['nomad-client'],
    }, self_only=True)
    nomad_drain(False)

    # mark that something's up by failing this "start" job
    ctx.invoke(wait)
    log.info("All done.")


@cli.command()
def configure_network():
    """Configures network according to the ini file [network] settings."""

    assert sys.platform.startswith('linux'), \
        'configure-network is only available on Linux'

    configure_sysctl_parameters_script = \
        str((PATH.root / 'scripts' / 'configure-sysctl.sh'))
    create_script = str((PATH.root / 'scripts' / 'create-bridge.sh'))
    forward_script = str((PATH.root / 'scripts' / 'forward-ports.sh'))

    subprocess.check_call([configure_sysctl_parameters_script])

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
        format='%(asctime)s %(filename)s %(funcName)12s() %(levelname)8s %(message)s',  # noqa: E501
        datefmt='%Y-%m-%d %H:%M:%S',
    )

    # Avoid a return value of 1, since that coincides with
    # tar's error code when input files have changed during archiving.
    try:
        cli()
    except Exception as e:
        log.exception(e)
        sys.exit(66)
