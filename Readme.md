# Cluster - spin up a Consul + Vault + Nomad cluster
This script installs and configures [consul][], [vault][] and [nomad][]. It's
designed to be easy to use on a fresh Linux machine, therefore it's somewhat
opinionated.

It will install everything in subfolders of the repository:
* `./bin` - Consul, Vault and Nomad binaries
* `./var` - cluster state and temporary files
* `./etc` - configuration files

The script generates a [supervisord][] configuration file in
`./etc/supervisor-cluster.conf` that can be easily symlinked to e.g.
`/etc/supervisor/conf.d/cluster.conf`.

[consul]: https://www.consul.io/
[vault]: https://www.vaultproject.io/
[nomad]: https://www.nomadproject.io/
[supervisord]: http://supervisord.org/


## HowTo (Debian, Ubuntu)
```shell
sudo apt update
sudo apt install python3 git supervisor curl

./cluster.py install
./cluster.py configure

sudo ln -s $(pwd)/etc/supervisor-cluster.conf /etc/supervisor/conf.d/cluster.conf
sudo supervisorctl update
```


## Usage
* `./cluster.py install` - Download Consul, Vault and Nomad and install their
  binaries.

  If possible, allow the vault binary to call `mlock`:
  ```shell
  sudo setcap cap_ipc_lock=+ep bin/vault
  ```
  Otherwise, run it as root, or disable `mlock` entirely (after reading [the
  warning][disable_mlock]) by adding the following to `cluster.ini`:
  ```ini
  [vault]
  disable_mlock = true
  ```

* `./cluster.py configure` - Generate configuration files for Consul, Vault and
  Nomad and a `supervisord` configuration for the daemons.

* `sudo supervisorctl <start|stop|restart> cluster:` - Start, stop and restart
  Consul, Vault and Nomad as Supervisor programs.

* `./cluster.py runserver <consul|vault|nomad>` - Start Consul, Vault and Nomad
  in the foreground.

[disable_mlock]: https://www.vaultproject.io/docs/configuration/#disable_mlock

### Vault
Vault requires manual setup before using it. First, [initialize][] it:
```shell
bin/vault operator init -address http://127.0.0.1:8200
```

Check the root token by using it to authenticate into the Vault UI
(http://127.0.0.1:8200/ui). Then copy the root token to `cluster.ini`:
```ini
[nomad]
vault_token = s.MRGpK9FAMuTEBnZ3BNcWYuY2
```

Now restart nomad (`sudo supervisorctl restart cluster:nomad`) and you should
be good to go.

[initialize]: https://www.vaultproject.io/docs/commands/operator/init.html
