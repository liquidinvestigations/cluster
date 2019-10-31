# Multi Host

First, configure a VPN and connect all your nodes to it. You can use [wireguard][] if you.
Use the resulting network interface name and address when configuring

Then, run an instance of this repository on each node be used. A minimal
configuration looks like this:

```ini
[network]
interface = YOUR_VPN_INTERFACE_NAME
address = YOUR_VPN_IP_ADDRESS

[cluster]
node_name = something-unique
bootstrap_expect = 3
retry_join = 10.66.60.1,10.66.60.2,10.66.60.4
```

All nodes should have `run_jobs` set to the same list.

Example set of config files: [ci/configs](ci/configs), see `triple-*.ini`.
**Note**: these configs are using `network.create_bridge = True` because they
are all running on local bridges on a single machine (for testing). You must
not set `network.create_bridge` if you configure the network externally
(e.g. a VPN or LAN).

After launching the services, all but one Vault instance will fail. The one
left running is the primary instance; you can find it in the Consul UI. To make
them all work:

* stop everything
* copy `var/vault-secrets.ini` from the primary to the other nodes
* restart everything

[wireguard]: https://www.wireguard.com/
