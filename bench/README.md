# Test bench

Three Docker targets that act like a Debian server waiting at the `dropbear-initramfs` prompt and then "boot".

- **Pre-boot:** real Dropbear (Debian stable `dropbear-bin`) on port 2222 with forced command `fake-cryptroot-unlock`, a stand-in for Debian's `cryptroot-unlock` with the same modes, texts and exit codes. Public-key login as `root` only.
- **Boot:** after the last disk unlocks, Dropbear and its sessions are stopped, and `BOOT_DELAY` seconds later OpenSSH `sshd` starts on port 22 with different host keys. It only completes a key exchange; nobody can log in.
- Each target has its own Dropbear and sshd host keys (ed25519, ecdsa, rsa), created on first start. They stay the same across `reset` and change only with `rotate-hostkey` or when the container is recreated.

| Service | Pre-boot (host → container) | Post-boot | Default disks |
| --- | --- | --- | --- |
| `target1` | `127.0.0.1:2201` → 2222 | `127.0.0.1:2301` → 22 | `sda3_crypt` |
| `target2` | `127.0.0.1:2202` → 2222 | `127.0.0.1:2302` → 22 | `sda3_crypt sdb1_crypt` |
| `target3` | `127.0.0.1:2203` → 2222 | `127.0.0.1:2303` → 22 | `sda3_crypt` |

Containers on the Docker network `luks-bench` reach them as `target1:2222`, `target1:22`, and so on.

## Commands

```sh
docker compose -f bench/compose.yaml up -d --build --wait   # make bench-up
docker compose -f bench/compose.yaml down -v                # make bench-down
B="docker compose -f bench/compose.yaml exec -T"
$B target1 bench-ctl reset            # back to locked pre-boot in well under 2 s
$B target3 bench-ctl set NOT_READY_SECONDS=5 MAX_TRIES=1   # override, then reset
$B target3 bench-ctl clear            # drop overrides and authorized extra keys, then reset
$B target1 bench-ctl rotate-hostkey   # new Dropbear host keys, then reset
$B target1 bench-ctl authorize < key.pub   # allow another login key (kept across reset)
$B target1 bench-ctl status           # preboot|booting|booted, unlocked/locked disks, tries, listening port
$B target1 bench-ctl fingerprint      # "preboot|postboot <type> SHA256:..." per host key
bench/test.sh                         # self-test; brings the bench up and leaves it down
```

`reset` and `set` return once Dropbear is listening, unless `PREBOOT_DELAY` is set.

## Parameters

Set them per service under `environment:` in `compose.yaml`, or at runtime with `bench-ctl set`, which overrides them until `clear`.

| Variable | Default | Meaning |
| --- | --- | --- |
| `PASSPHRASE` | `correct-horse-bench` | Passphrase for every disk. It is compared byte for byte, so a trailing newline makes it wrong. |
| `DISKS` | `sda3_crypt` | Disk names, separated by spaces, unlocked in this order. |
| `DISK_PASSPHRASES` | empty | Per-disk passphrases as `name=pass` pairs, separated by spaces. A passphrase listed here cannot contain spaces. |
| `NOT_READY_SECONDS` | `0` | For this long after Dropbear starts, the script answers `Try again later` and exits 1. |
| `MAX_TRIES` | `3` | Tries per disk, as crypttab `tries=`. `0` means unlimited. |
| `BOOT_DELAY` | `3` | Seconds between stopping Dropbear and starting sshd. |
| `PREBOOT_DELAY` | `0` | Seconds after a (re)start before Dropbear listens. |
| `UNLOCK_DELAY` | `0.7` | Simulated cryptsetup time between receiving the passphrase and printing the result. |

## Fake script behaviour

- Without a TTY, it prints `Please unlock disk <name>` on stdout, reads stdin to EOF as the passphrase, prints one result on stderr, and exits 0 or 1.
- With a TTY, it shows the prompt `Please unlock disk <name>: ` with echo off, and repeats it until all disks are unlocked or the tries run out.
- When every disk is already unlocked, it exits 0 with no output.
- After a wrong try, the next prompt appears about 1 s later, as with the real `cryptsetup` retry loop.
- After the last try is used up, no disk prompts again. A later call waits 10 s and fails with `Error: Timeout reached while waiting for askpass.`, like the real script once `cryptroot` has given up.

## Fixtures

`fixtures/id_ed25519_bench` and `fixtures/id_ed25519_wrong` are throwaway test keys, not secrets. Only `id_ed25519_bench` is authorized on the targets.
