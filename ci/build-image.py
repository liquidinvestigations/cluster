#!/usr/bin/env python3

# apt install cloud-image-utils qemu-kvm

import logging
from pathlib import Path
from argparse import ArgumentParser
from tempfile import TemporaryDirectory
import subprocess
import shlex
from base64 import b64encode

log_level = logging.DEBUG
log = logging.getLogger(__name__)
log.setLevel(log_level)

CACHE = Path.home() / '.cache/vmck-build'
DISK_SIZE = '35G'

BIONIC_URL = (
    'https://cloud-images.ubuntu.com/bionic/current/'
    'bionic-server-cloudimg-amd64.img'
)

SSH_PUBKEY = 'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key'  # noqa: E501

CLOUD_INIT_YML = f"""\
#cloud-config
ssh_authorized_keys: ['{SSH_PUBKEY}']
packages: ['build-essential', 'curl', 'less', 'vim']
system_info:
   default_user:
     name: vagrant
     lock_passwd: true
     sudo: ["ALL=(ALL) NOPASSWD:ALL"]
     shell: /bin/bash
runcmd:
  - "echo 'vmck' > /etc/hostname"
  - "echo '127.0.1.1 vmck' >> /etc/hosts"
  - "touch /etc/cloud/cloud-init.disabled"
  - "systemctl disable apt-daily.service"
  - "systemctl disable apt-daily.timer"
  - "touch /home/vagrant/.hushlogin"
  - "/tmp/script_*.sh"
  - "apt-get clean"
  - "cat /dev/zero > /ZERO || rm /ZERO"
  - "poweroff"
"""


def shq(value):
    return shlex.quote(str(value))


def sh(cmd):
    log.debug('+ %s', cmd)
    subprocess.run(cmd, shell=True, check=True)


def download(url, dest):
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.parent / f'{dest.name}.tmp'
    sh(f'curl -L {shq(url)} -o {shq(tmp)}')
    Path(tmp).rename(dest)


def build(tmp, output, scripts, files_to_copy):
    upstream = CACHE / 'bionic-server-cloudimg-amd64.img'
    if not upstream.exists():
        log.info("Downloading cloud image from %r", BIONIC_URL)
        download(BIONIC_URL, upstream)

    log.info("Preparing disk image")
    disk = tmp / 'disk.img'
    sh(f'qemu-img create -q -f qcow2 -b {shq(upstream)} {shq(disk)}')
    sh(f'qemu-img resize {shq(disk)} {DISK_SIZE}')

    log.info("Preparing cloud-init image")
    cloud_init_yml = tmp / 'cloud-init.yml'
    cloud_init_img = tmp / 'cloud-init.img'
    with cloud_init_yml.open('w', encoding='utf8') as f:
        f.write(CLOUD_INIT_YML)
        if scripts or files_to_copy:
            f.write('write_files:\n')
            for n, script in enumerate(scripts):
                with script.open('rb') as s:
                    script_b64 = b64encode(s.read()).decode('latin1')
                f.write(f'  - encoding: b64\n')
                f.write(f'    content: {script_b64}\n')
                f.write(f'    path: /tmp/script_{n}.sh\n')
                f.write(f'    permissions: "0755"\n')
            for host_path, guest_path in files_to_copy:
                with host_path.open('rb') as s:
                    file_b64 = b64encode(s.read()).decode('latin1')
                f.write(f'  - encoding: b64\n')
                f.write(f'    content: {file_b64}\n')
                f.write(f'    path: {str(guest_path)}\n')
                f.write(f'    permissions: "0644"\n')

    sh(f'cloud-localds {shq(cloud_init_img)} {shq(cloud_init_yml)}')

    log.info("Running qemu")
    sh(
        'qemu-system-x86_64 -enable-kvm -nographic -m 512 '
        '-netdev user,id=user -device virtio-net-pci,netdev=user '
        f'-drive discard=unmap,detect-zeroes=unmap,file={shq(disk)} '
        f'-drive format=raw,file={shq(cloud_init_img)}'
    )

    log.info("Exporting disk image")
    sh(f'qemu-img convert -O qcow2 -p {shq(disk)} {shq(output)}')


def main():
    parser = ArgumentParser()
    parser.add_argument('output', type=Path)
    parser.add_argument('--script', type=Path, action='append', default=[])
    parser.add_argument('--copy-file', action='append', metavar='HOST:GUEST',
                        default=[])
    options = parser.parse_args()

    files_to_copy = [tuple(map(Path, s.split(':'))) for s in options.copy_file]

    with TemporaryDirectory() as tmp:
        build(Path(tmp), options.output, options.script, files_to_copy)


if __name__ == '__main__':
    logging.basicConfig(level=log_level)
    main()
