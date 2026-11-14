# luks-unlock

Command-line front end of `unlock_core`: unlocks LUKS servers waiting at the Dropbear pre-boot prompt, several in parallel, and confirms that they booted.

```sh
luks-unlock unlock --config hosts.yaml (--host NAME ... | --group G | --all) \
    [--accept-new-host-key] [--passphrase-fd N]
```

| Option | Meaning |
| --- | --- |
| `--config`, `-c` | YAML file with the hosts (below). |
| `--host NAME` | Unlock this host; repeat for several. Runs the host even if `enabled: false`. |
| `--group G` | Every enabled host whose `group` is `G`; repeatable. |
| `--all` | Every enabled host. Exactly one of `--host`, `--group`, `--all` is required. |
| `--accept-new-host-key` | Trust a pre-boot host key that is not pinned yet (trust on first use). The key is printed so you can pin it; the config file is never changed. |
| `--passphrase-fd N` | Read the passphrase from file descriptor `N`, byte for byte (no newline is stripped). |

**Passphrase.** One passphrase serves every selected host that has no `passphrase_file`. It is read from stdin: on a terminal with a `Passphrase:` prompt and echo off, up to Enter; from a pipe up to end of file, with exactly one trailing newline removed. With `--passphrase-fd` the bytes are used exactly as read. `passphrase_file` and `disk_passphrase_files` are read like a pipe (one trailing newline removed). Passphrases are sent as these exact bytes, never logged, and overwritten when the run ends.

**Output.** One line per event, `[host] state: message`, where `state` is the phase (`checking-if-up`, `waiting-for-preboot`, `verifying-host-key`, `authenticating`, `unlocking`, `waiting-for-boot`) or, on the last line of a host, its result. Server output appears as `stdout: ...` / `stderr: ...` with any passphrase replaced by `[redacted]`. A summary table follows, then hints for keys to pin.

**Exit status.** `0` if every selected host ended `Unlocked` or `Already up`; `1` otherwise (also after Ctrl-C, which cancels all hosts); `64` for usage errors, an unreadable or invalid config, a missing key file, or an empty passphrase.

**Unpinned host keys.** Without `--accept-new-host-key`, a host with no `preboot_host_key` is refused before login and ends as `Host key mismatch` with the message `pre-boot host key is not pinned; server presented ...`. The hint at the end shows the line to add after you checked the key on the server (`dropbearkey -y -f /etc/dropbear/initramfs/dropbear_ed25519_host_key`).

## Config file

```yaml
defaults:                      # optional; any of user, key_file, postboot_check,
  user: root                   # wait_timeout, boot_timeout, legacy_algorithms, command
  key_file: ~/keys/unlock_ed25519

hosts:
  - name: nas                  # required, unique; used by --host
    group: home                # optional; used by --group
    preboot: [nas.lan:2222, 10.0.0.5:2222]   # required; host[:port] or a list, tried in order; port defaults to 22
    user: root                 # default root
    key_file: keys/nas         # required (here or in defaults); unencrypted OpenSSH, PKCS#1 or SEC1 PEM
    preboot_host_key: "ssh-ed25519 SHA256:..."   # pinned Dropbear key; "SHA256:..." alone matches any key type
    postboot: nas.lan:22       # default: first pre-boot host, port 22
    postboot_check: ssh-hostkey  # ssh-hostkey (default) | tcp | none
    postboot_host_key: "ssh-ed25519 SHA256:..."  # optional; once set, boot is confirmed only by this key
    wait_timeout: 10m          # waiting for pre-boot SSH; seconds or 30s / 10m / 1h
    boot_timeout: 5m           # waiting for the booted system
    legacy_algorithms: false   # also offer ssh-rsa (SHA-1) host keys, SHA-1 key exchange and CBC
    enabled: true              # false: skipped by --all and --group
    command: cryptroot-unlock  # unlock command (Debian/Ubuntu default)
    passphrase_file: secrets/nas.pass        # optional; this host does not use the stdin passphrase
    disk_passphrase_files:                   # optional per-disk overrides
      sdb1_crypt: secrets/nas-data.pass
```

Relative paths are relative to the config file; a leading `~/` is the home directory. Unknown keys are errors. With `postboot_check: tcp` the post-boot port must differ from every pre-boot port.

When the type is given in `preboot_host_key`, only that host-key type is offered to the server, so a server with several host keys cannot cause a false mismatch. Use the type and fingerprint exactly as `ssh-keygen -lf` or `bench-ctl fingerprint` print them; RSA keys are `ssh-rsa`.

## Against the test bench

`example/bench.yaml` describes `target1` and `target2` as seen from a container on the `luks-bench` network:

```sh
make bench-up && make cli
docker compose -f bench/compose.yaml exec -T target1 bench-ctl fingerprint   # pin these, or:
make run-dart DOCKER_OPTS="--network luks-bench" \
  CMD="printf %s correct-horse-bench | build/luks-unlock unlock -c packages/unlock_cli/example/bench.yaml --group bench --accept-new-host-key"
```

`make test-bench` runs the engine and CLI tests against `target1` and `target2`.
