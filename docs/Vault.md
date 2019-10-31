# Vault Configuration

Vault requires initialization when installing. It also requires that the Vault
be unsealed after the daemon starts, including after reboot.

In production environments one would use the Vault commands [initialize][] and
[unseal][].

For development, to avoid manually copy/pasting keys, we are using our
`autovault` command after starting the Vault server. On first run, it
initializes the vault, stores the unseal key and root token in
`var/vault-secrets.ini` with permissions `0600`, and unseals it. On subsequent
runs, it uses the same key to unseal the vault, so it's safe to run at boot.

[initialize]: https://www.vaultproject.io/docs/commands/operator/init.html
[unseal]: https://www.vaultproject.io/docs/commands/operator/unseal.html

### Disabling mlock

Disabling mlock is [**not recommended**][disable_mlock], but if you insist, add
this to `cluster.ini`:

```ini
[vault]
disable_mlock = true
```

[disable_mlock]: https://www.vaultproject.io/docs/configuration/#disable_mlock

This flag has no effect on macOS.
