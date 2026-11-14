# luks-unlock

Command-line front end of `unlock_core`: unlocks LUKS servers waiting at the Dropbear pre-boot prompt, several in parallel, and confirms that they booted. SSH keys and LUKS passphrases come from files and stdin, or from an encrypted vault.

```sh
luks-unlock unlock --config hosts.yaml (--host NAME ... | --group G | --all) \
    [--accept-new-host-key] [--passphrase-fd N] [--vault PATH] [--password-fd N]

luks-unlock vault  init | status | passwd
luks-unlock key    generate --label L [--comment C] | import --label L FILE | list | show LABEL | rm LABEL
luks-unlock secret add --label L [--secret-fd N] | list | rm LABEL
```

`luks-unlock <command> --help` lists every option.

## unlock

| Option | Meaning |
| --- | --- |
| `--config`, `-c` | YAML file with the hosts (below). |
| `--host NAME` | Unlock this host; repeat for several. Runs the host even if `enabled: false`. |
| `--group G` | Every enabled host whose `group` is `G`; repeatable. |
| `--all` | Every enabled host. Exactly one of `--host`, `--group`, `--all` is required. |
| `--accept-new-host-key` | Trust a pre-boot host key that is not pinned yet (trust on first use). The key is printed so you can pin it; the config file is never changed. |
| `--passphrase-fd N` | Read the passphrase from file descriptor `N`, byte for byte (no newline is stripped). |
| `--vault PATH` | Vault for `key:`, `secret:` and `disk_secrets:` labels (default below). |
| `--password-fd N` | Read the vault password from file descriptor `N`, byte for byte. |

**Passphrase.** One passphrase serves every selected host that has neither `passphrase_file` nor `secret`. It is read from stdin: on a terminal with a `Passphrase:` prompt and echo off, up to Enter; from a pipe up to end of file, with exactly one trailing newline removed. With `--passphrase-fd` the bytes are used exactly as read. `passphrase_file` and `disk_passphrase_files` are read like a pipe (one trailing newline removed). Passphrases are sent as these exact bytes, never logged, and overwritten when the run ends.

**Vault.** If any selected host uses a label, the vault is unlocked once before the run: one `Vault password:` prompt on the terminal, or `--password-fd`. Labels are checked before the prompt. Only the records the selected hosts use are decrypted, the vault key is dropped right after, and the decrypted keys and passphrases are overwritten when the run ends. Hosts with labels and hosts with files or stdin can be mixed in one run; the stdin passphrase is read after the vault password. When stdin is not a terminal (for example the passphrase is piped in), the vault password must come from `--password-fd`.

**Output.** One line per event, `[host] state: message`, where `state` is the phase (`checking-if-up`, `waiting-for-preboot`, `verifying-host-key`, `authenticating`, `unlocking`, `waiting-for-boot`) or, on the last line of a host, its result. Server output appears as `stdout: ...` / `stderr: ...` with any passphrase replaced by `[redacted]`. A summary table follows, then hints for keys to pin.

**Exit status.** `0` if every selected host ended `Unlocked` or `Already up`; `1` otherwise (also after Ctrl-C, which cancels all hosts, a wrong vault password, or a damaged vault); `64` for usage errors, an unreadable or invalid config, a missing key file, an empty passphrase, a label that is not in the vault, or no vault at all.

**Unpinned host keys.** Without `--accept-new-host-key`, a host with no `preboot_host_key` is refused before login and ends as `Host key mismatch` with the message `pre-boot host key is not pinned; server presented ...`. The hint at the end shows the line to add after you checked the key on the server (`dropbearkey -y -f /etc/dropbear/initramfs/dropbear_ed25519_host_key`).

## Config file

```yaml
defaults:                      # optional; any of user, key_file, key, postboot_check,
  user: root                   # wait_timeout, boot_timeout, legacy_algorithms, command
  key_file: ~/keys/unlock_ed25519

hosts:
  - name: nas                  # required, unique; used by --host
    group: home                # optional; used by --group
    preboot: [nas.lan:2222, 10.0.0.5:2222]   # required; host[:port] or a list, tried in order; port defaults to 22
    user: root                 # default root
    key_file: keys/nas         # unencrypted OpenSSH, PKCS#1 or SEC1 PEM
    # key: laptop              # or a key label from the vault (exactly one of key_file and key)
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
    # secret: nas              # or a secret label from the vault (not both)
    disk_passphrase_files:                   # optional per-disk overrides
      sdb1_crypt: secrets/nas-data.pass
    disk_secrets:                            # optional per-disk overrides from the vault
      sdc1_crypt: nas-backup
```

Relative paths are relative to the config file; a leading `~/` is the home directory. Unknown keys are errors. With `postboot_check: tcp` the post-boot port must differ from every pre-boot port.

Every host needs `key_file` or `key`, from the host or from `defaults`; one set on the host replaces the one from `defaults`, and setting both on one level is an error. `secret` and `passphrase_file` exclude each other, and a disk may appear in `disk_passphrase_files` or `disk_secrets`, not both.

When the type is given in `preboot_host_key`, only that host-key type is offered to the server, so a server with several host keys cannot cause a false mismatch. Use the type and fingerprint exactly as `ssh-keygen -lf` or `bench-ctl fingerprint` print them; RSA keys are `ssh-rsa`.

## Vault

The vault keeps SSH private keys and LUKS passphrases encrypted (XChaCha20-Poly1305 under a random vault key, which is wrapped by an Argon2id key from the master password: 19 MiB, 2 passes, 1 lane). It is meant for headless Linux use.

**Location.** `--vault PATH`, else `$LUKS_UNLOCK_VAULT`, else `$XDG_DATA_HOME/luks-remote-unlocker/vault.json`, else `~/.local/share/luks-remote-unlocker/vault.json`. Next to `NAME.json` live:

| File | Content |
| --- | --- |
| `NAME.json` | The vault: metadata, password slot, encrypted records (mode 0600). |
| `NAME.index.json` | Labels: for each key its label, record id, type, public line and fingerprint; for each secret its label and record id. No secrets (mode 0600). |
| `NAME.lock` | Empty; writers hold a lock on it so two commands do not overwrite each other. |

A new directory is created with mode 0700. Every file is replaced atomically (temp file and rename). A record is written before its label, and a label is removed before its record, so an interruption can at worst leave an unlabelled record, which `vault status` reports.

**Master password.** Read from the terminal with echo off, or from `--password-fd N` (exact bytes, no newline stripped); never from arguments or the environment. Without a terminal and without `--password-fd`, commands fail with exit status 64. A new password is asked twice on a terminal and needs at least 10 characters.

| Command | Password | Does |
| --- | --- | --- |
| `vault init [--password-fd N]` | new | Creates the vault. Refuses if one exists. |
| `vault status` | no | Path, `exists`, id, password slot, record counts by kind, label counts, and warnings about records without label or labels without record. Exit 1 if there is no vault. |
| `vault passwd [--password-fd N] [--new-password-fd M]` | current, new | Re-wraps the vault key under a new password; records stay as they are. |
| `key generate --label L [--comment C]` | yes | New Ed25519 key. Prints the public line (comment defaults to the label) and the `SHA256:` fingerprint, one per line. Add the public line to the server's `authorized_keys`. |
| `key import --label L FILE [--key-passphrase-fd N]` | yes | Imports an OpenSSH (Ed25519, RSA, ECDSA), PKCS#1 RSA or SEC1 EC private key. An encrypted key's passphrase is asked on the terminal (`Key passphrase:`) or read from `--key-passphrase-fd`. Prints public line and fingerprint. |
| `key list` | no | Table of label, type and fingerprint. |
| `key show LABEL` | no | Public line and fingerprint. |
| `key rm LABEL` | yes | Deletes label and record. |
| `secret add --label L [--secret-fd N]` | yes | Stores a LUKS passphrase, typed twice after the vault password, or read from `--secret-fd` byte for byte. |
| `secret list` | no | Labels, one per line. |
| `secret rm LABEL` | yes | Deletes label and record. |

Every command takes `--vault PATH`; those that need the password take `--password-fd N`. No command prints a private key or passphrase.

Labels are 1 to 64 letters, digits and `._@+-`, starting with a letter or digit. Keys and secrets have separate labels, so a key and a secret may both be called `nas`. Whether a label is still used by some config is not checked.

**Exit status.** `0` on success; `1` when the operation fails (no vault, a vault already exists, wrong vault or key passphrase, unusable key file, duplicate or unknown label, damaged vault or index, I/O error); `64` for usage errors (bad options or arguments, unreadable `FILE` or file descriptor, no terminal, empty, short or mismatched new password or passphrase).

## Against the test bench

`example/bench.yaml` describes `target1` and `target2` as seen from a container on the `luks-bench` network:

```sh
make bench-up && make cli
docker compose -f bench/compose.yaml exec -T target1 bench-ctl fingerprint   # pin these, or:
make run-dart DOCKER_OPTS="--network luks-bench" \
  CMD="printf %s correct-horse-bench | build/luks-unlock unlock -c packages/unlock_cli/example/bench.yaml --group bench --accept-new-host-key"
```

`make test-bench` runs the engine and CLI tests against `target1` and `target2`, including a vault run: `vault init`, `key generate`, `bench-ctl authorize` of the new public line, `secret add`, then `unlock` with `key:` and `secret:` labels.
