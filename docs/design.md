# LUKS Remote Unlocker — Summary & Implementation Plan

Nov 14, 2026 · @Mister · reviewed and finalized by Fable (rev 2)

## Summary

Build one app for Android, iOS and Linux desktop (plus a CLI) that unlocks LUKS-encrypted Linux servers waiting at the Dropbear pre-boot prompt, one tap per server or all at once.

For each server the app waits until the pre-boot SSH port answers, checks the server's pinned host key, logs in with the SSH key assigned to that server, hands over the disk passphrase, and reads the result from the unlock command's exit code. It counts the unlock as done only when the booted system answers at the post-boot address with a different SSH host key than the pre-boot one.

The user manages servers, SSH keys and passphrases in the app and decides which key goes with which server. Keys and passphrases are encrypted with a vault key that opens with a fingerprint or face, backed by the phone's secure hardware (Android Keystore, iPhone Secure Enclave), or with a master password on Linux.

This doc is the hand-off. All design questions are decided (see Decisions); Opus subagents build it phase by phase.

**v1 scope:** Android, iOS, Linux desktop, CLI. Debian/Ubuntu `dropbear-initramfs` servers. Everything else is in "After v1".

## What changed in this review

Each item was checked against the current package sources and the Debian `cryptroot-unlock` script.

| # | Change | Why |
| --- | --- | --- |
| 1 | Unlock without a terminal: passphrase on stdin, result from the exit code. Prompt-matching with a pseudo-terminal moves to after v1. | `cryptroot-unlock` has a non-interactive mode when stdin is not a TTY. It prints the disk name, reads the passphrase from stdin, exits 0 or 1. No regex guessing, no echo to scrub, and the exact error texts are known from the script. |
| 2 | Post-boot check is an SSH host-key check, not a ping. Ping becomes an optional check type after v1. | The initramfs answers ping too, usually on the same IP, so a ping right after the unlock can pass while the server is still in pre-boot. The booted system has a different host key than Dropbear, which proves the boot. |
| 3 | Pre-boot gate is a TCP connect to the SSH port only. `dart_ping` is dropped from v1. | Ping says nothing about Dropbear being ready, is often filtered, and the package parses localized `ping` output and needs a native Swift build on iOS. |
| 4 | Vault is one random vault key that encrypts all secrets; the biometric store holds only that key. A second, password-wrapped copy of the key serves as recovery and as the Linux vault. | Storing each secret as its own biometric entry means one prompt per secret. One key gives one prompt per run, survives a changed fingerprint enrollment through the recovery password, and makes the Linux vault and the later encrypted backup the same code. |
| 5 | Test bench runs real Dropbear with a script modeled on the real `cryptroot-unlock`, not OpenSSH. | Dropbear is what production runs; algorithm and channel behaviour differ from OpenSSH. |
| 6 | Added final states `Already up` and `Unlocked, boot not confirmed`; never retry a rejected passphrase. | Tapping "unlock all" on a running server should be harmless. Debian allows 3 tries by default, then stops asking. |
| 7 | Per-host "legacy algorithms" switch. | dartssh2 4.0 removed `ssh-rsa` (SHA-1) host-key signatures and CBC from its defaults; Dropbear before 2020.79 offers only those for RSA host keys. |
| 8 | Phases reordered: keys and vault crypto are pure Dart and move into the core before any UI; iOS is its own last phase. | They can be built and tested in Docker in parallel; iOS needs a Mac. |
| 9 | Added a phase 0 (toolchain in Docker, repo layout, pinned versions). | All builds and tests run in containers; agents need one entry point. |

## Prior art

No existing tool does the whole job: none confirms the boot after the unlock, none keeps keys in a fingerprint-protected vault, and none runs on a phone.

| Tool | What it does | What it lacks for us |
| --- | --- | --- |
| [cryptsetup-ssh-unlocker](https://github.com/viktorstiskala/cryptsetup-ssh-unlocker) (Python) | Polls many servers for an open SSH port, then unlocks; pins host keys via known\_hosts | Desktop/server only; runs cryptsetup itself instead of answering the prompt; last pushed 2018 |
| [dropbear-auto-unlock](https://github.com/hugojosefson/dropbear-auto-unlock) (Deno) | Many servers with fallback addresses, retries, waits for the next reboot after an unlock | ZFS prompt only; treats a shell prompt as success; no post-boot check |
| [SSHUnlockLUKS](https://github.com/Ixtalo/SSHUnlockLUKS) (Python) | One server per config, run from cron | One host, no UI, no vault |
| [android-luks](https://github.com/full-disclosure/android-luks) | Phone unlocks a PC with biometrics | USB accessory mode, not network |
| [tanga](https://github.com/gernotfeichter/tanga) | Tang server on the phone (network-bound encryption) | Different model: automatic unlock on the same Wi-Fi, no SSH |

Borrowed: host-key pinning from cryptsetup-ssh-unlocker, and the per-host state machine with fallback addresses from dropbear-auto-unlock.

## Requirements

**Hosts**

- Name, pre-boot addresses (IP or hostname, each with a port; Dropbear often listens on 2222), tried in order.
- Login user (default `root`).
- Assigned SSH key, picked from the key list.
- Assigned passphrase, picked from the secrets list; optional per-disk overrides (disk name → secret).
- Post-boot address and port (default: first pre-boot address, port 22), check type, and a boot timeout.
- Pinned pre-boot host key, stored after the user confirms it on first connect or pastes it in advance.
- Unlock profile, group for "unlock all in group", "legacy algorithms" switch, enabled flag.

**SSH keys**

- Generate Ed25519 in the app; import existing OpenSSH private keys (Ed25519, RSA, ECDSA), with or without a key passphrase. An imported key is decrypted once and stored in the vault.
- Show, copy, share and QR-encode the public key in `authorized_keys` format.
- One key can serve many hosts; each host has exactly one key.

**Passphrases**

- Named secrets; one secret can serve several hosts.
- Never shown in clear unless the user asks and re-authenticates. Never copied to the clipboard.
- Stored and sent as UTF-8 bytes exactly as typed, with no trailing newline.

**Unlock profiles**

- A profile = driver + command. v1 has one driver, `stdin`, and one built-in profile, Debian/Ubuntu `cryptroot-unlock`. The user can copy it and change the command.
- The second driver, `pty` (prompt-matching), and the Fedora, Arch and ZFS presets come after v1. The profile record already carries the fields for it.

**Runs**

- Unlock one host, a group, or all; hosts run in parallel, each with its own live log.
- Cancel at any point; poll with backoff while waiting for the server.
- Final state per host: Unlocked, Already up, Unlocked but boot not confirmed, Wrong passphrase, Host key mismatch, Auth failed, Pre-boot timeout, Cancelled, Error.
- Run history with timestamps; passphrases never appear in logs.

**Non-functional**

- Works offline; no cloud, no telemetry, no analytics, no sync.
- Secrets never written to disk in clear, never in logs, crash output or the clipboard. OS backups of the app data are switched off.
- Android keeps running with the screen off during a run (foreground service with a notification). iOS runs with the app open and the screen kept awake.
- Config export and import without secrets.

## Unlock flow

One state machine per host. The passphrase is sent only after the server's host key matches the pinned one.

| # | State | What happens | Exits |
| --- | --- | --- | --- |
| 1 | Checking if up | One post-boot check (see below), 3 s timeout. | Passes → **Already up** |
| 2 | Pinging, then waiting for pre-boot | Ping: one TCP connect to each pre-boot address in order, 3 s timeout each; the log says which address answers. No answer: waiting for pre-boot repeats the ping every 2 s, backing off to 5 s, until the wait timeout (default 10 min). | Timeout → **Pre-boot timeout** |
| 3 | Verifying host key | SSH key exchange. Compare the server key with the pinned one. Not pinned yet: pause this host and ask the user to confirm the SHA-256 fingerprint (other hosts keep running). | Differs → **Host key mismatch**. Equals the known post-boot key → **Already up**. Declined → **Cancelled** |
| 4 | Authenticating | Public-key login with the assigned key. | Rejected → **Auth failed** |
| 5 | Unlocking disk *n* | Open an exec channel without a pseudo-terminal, run the profile command, read `Please unlock disk <name>` from stdout, write the passphrase for that disk to stdin, close stdin, wait for the exit code (30 s timeout). | See result table |
| 6 | Waiting for boot | Post-boot check every 2 s until the boot timeout (default 5 min). | Passes → **Unlocked**. Timeout → **Unlocked, boot not confirmed** |

**Step 5 results** (texts are from the Debian script; all go to stderr)

| Output | Exit | Action |
| --- | --- | --- |
| `cryptsetup: <name> set up successfully` | 0 | Disk done. Run the command again for the next disk (at most 8 rounds). |
| No `Please unlock disk` line | 0 | All disks are already unlocked → step 6. |
| Connection refused or closed on a later round, after at least one success | — | Server is booting → step 6. |
| `Try again later` or `Timeout reached while waiting for askpass` | 1 | Not ready. Retry after 2 s, for at most 60 s, then **Error**. Nothing was consumed, so this is safe. |
| `cryptsetup failed, bad password or options?` | 1 | **Wrong passphrase**. Stop. Never retry on its own. |
| `maximum number of tries exceeded` | 1 | **Wrong passphrase** (tries used up; the server needs a reboot or console). |
| Connection lost after the passphrase was written, no result line | — | Go to step 6 with a short timeout (60 s); pass → **Unlocked**, else **Error**. |
| Anything else | any | **Error**, with the sanitized output in the log. |

When Dropbear forces the command (`-c cryptroot-unlock`), it ignores the command the client asks for, so the app always sends the profile command and needs no "empty command" case.

**Post-boot check types**

- `ssh-hostkey` (default): TCP connect to the post-boot address, run the SSH key exchange, read the server's host key, then disconnect without logging in. Pass when the key differs from the pinned pre-boot key. The first key seen is stored as the host's post-boot key (no confirmation needed, since nothing secret is ever sent there); from then on the check passes only on that key, and a different one is shown as a warning in the log. Seeing the pre-boot key means "still in initramfs, keep waiting".
- `tcp`: the port accepts a connection. Only valid when the post-boot port differs from every pre-boot port; the host form enforces this.
- `none`: skip step 1 and 6; final state is **Unlocked, boot not confirmed**.
- After v1: `icmp`, `http`.

## Architecture and tech stack

Flutter (Dart), one codebase, built around a pure-Dart core that also ships as a CLI.

| Concern | Choice | Notes (checked Nov 2026) |
| --- | --- | --- |
| App framework | Flutter ≥ 3.44, Dart ≥ 3.12 | Floor set by biometric\_vault. Pin the exact stable version in phase 0. |
| SSH client | [dartssh2](https://pub.dev/packages/dartssh2) ^4.1.0 | Pure Dart, actively maintained (security hardening Aug–Sep 2026). `onVerifyHostKey(type, fingerprint)` gets `SHA256:<base64>` as UTF-8 bytes and may be async, which lets the UI confirm a new key while the connection waits. `execute(cmd)` without `pty` gives stdin, stdout, stderr and `exitCode`. `SSHAlgorithms` re-enables legacy algorithms per connection. |
| Key generation | [pinenacl](https://pub.dev/packages/pinenacl) (already a dartssh2 dependency) + dartssh2 `OpenSSHEd25519KeyPair(...).toPem()` | dartssh2 parses and writes OpenSSH keys but does not generate them. |
| Vault crypto | [cryptography](https://pub.dev/packages/cryptography) ^2.9.0 | XChaCha20-Poly1305 for records, Argon2id for the password slot. Pure Dart, runs in the core and the CLI. |
| Biometric key store | [biometric\_vault](https://pub.dev/packages/biometric_vault) ^1.1.2 | Maintained rebuild of biometric\_storage (which has had no release since Feb 2024). Android Keystore (StrongBox, else TEE) behind BiometricPrompt Class 3; iOS Keychain with access control. Typed `StorageInvalidatedException` after an enrollment change. |
| Reachability | `Socket.connect` with timeout | No ICMP in v1. |
| Local database | drift (SQLite) + `sqlite3_flutter_libs` | Hosts, profiles, public keys, run history, and the encrypted vault records. |
| State | Riverpod | Per-host run state streams into the UI. |
| Android background | [flutter\_foreground\_task](https://pub.dev/packages/flutter_foreground_task) ^11 | Used only to keep the process, CPU and Wi-Fi awake. The engine keeps running in the main isolate, so secrets never cross an isolate boundary. Service type `dataSync`. |
| iOS background | None; [wakelock\_plus](https://pub.dev/packages/wakelock_plus) keeps the screen on | iOS stops long background work. |
| Public key sharing | `qr_flutter`, `share_plus` | Latest stable. |

**Repository layout** (Dart pub workspace)

```
packages/unlock_core/   pure Dart: models, engine, drivers, keys, vault crypto, interfaces
packages/unlock_cli/    CLI over the core
app/                    Flutter app (android/, ios/, linux/)
bench/                  Docker test target (Dropbear + fake unlock script)
vm/                     QEMU Debian VM with real LUKS (phase 7)
tool/                   Dockerfiles and scripts behind the Makefile
docs/                   server-setup.md, security-checklist.md, device-checklist.md
Makefile                make test | bench-up | bench-down | cli | apk | linux
```

**Core interfaces** (in `unlock_core`; adapters implement them)

```dart
abstract interface class Reachability {
  Future<bool> tcpOpen(String host, int port, Duration timeout);
}
abstract interface class SshConnector {
  Future<SshConnection> connect(Endpoint e, {required HostKeyPolicy policy,
      required bool legacyAlgorithms, required Duration timeout});
  Future<HostKey> probeHostKey(Endpoint e, {required Duration timeout}); // kex only, no login
}
abstract interface class SshConnection {
  Future<void> authenticate(String user, PrivateKeyBytes key);
  Future<ExecSession> exec(String command); // no pty
  Future<void> close();
}
abstract interface class ExecSession {
  Stream<Uint8List> get stdout; Stream<Uint8List> get stderr;
  void write(Uint8List data); Future<void> closeStdin(); Future<int?> get exitCode;
}
abstract interface class UnlockDriver { // v1: StdinDriver
  Future<DriverResult> run(SshConnection c, UnlockProfile p, SecretResolver secrets, RunLog log);
}
abstract interface class VaultKeyStore { // biometric slot: Android/iOS adapter
  Future<Uint8List?> read(); Future<void> write(Uint8List key); Future<void> delete();
}
abstract interface class HostKeyPrompt { Future<bool> confirm(HostRef h, HostKey k); }
```

The engine is `UnlockEngine.run(List<HostPlan>, RunSecrets) → Stream<HostEvent>` with a `cancel()`; it takes every dependency through these interfaces plus an injectable clock, so each transition is unit-testable with fakes.

**Rejected alternatives**

- Kotlin Multiplatform: no maintained pure-Kotlin SSH client that runs on iOS.
- Tauri 2 + Rust `russh`: the SSH side is strong, but biometric key storage and an Android foreground service would both be custom native plugins.
- Signing SSH logins inside the secure hardware: Android StrongBox has no Ed25519, and imported keys could not use it. The private key is vault-encrypted instead.

## Security model

The passphrase is only as safe as the server it is sent to, so host-key pinning matters as much as the vault.

**Vault**

- One random 32-byte vault key. Every private key and passphrase is a record encrypted with XChaCha20-Poly1305 under it (random 24-byte nonce, record kind and id as associated data) and stored in the database. Nothing secret is stored outside these records.
- The vault key itself is stored in "slots", like LUKS key slots:
  - **Biometric slot** (Android, iOS): the vault key in a `biometric_vault` store. Reading it shows one biometric prompt.
  - **Password slot** (all platforms): the vault key encrypted under an Argon2id key derived from a password. On Linux this is the master password and the only slot. On phones it is the recovery password: strongly recommended at setup, skippable with a clear warning.
- One prompt per run releases the vault key; the run decrypts only the records its hosts need. Secrets are `Uint8List`, never `String`, and are overwritten when the run ends (Dart cannot guarantee wiping; don't overclaim in the UI).
- A new fingerprint or face enrollment invalidates the biometric slot (platform default, kept on purpose). The app then asks for the recovery password and creates a new biometric slot. Without a recovery password the vault is lost and secrets must be re-entered; the setup screen says so.
- Setting "allow device PIN as fallback", default off. Changing it rewrites the biometric slot with the other option, after an unlock.
- Argon2id parameters: start at 19 MiB, 2 passes, 1 lane (OWASP minimum), run in a background isolate; raise memory if a mid-range phone stays under 1 s. Parameters are stored with the slot.

**Host-key pinning**

- First connect shows the pre-boot server's key type and SHA-256 fingerprint; the user confirms it, or pastes the expected one into the host form beforehand. The setup help shows how to print it on the server.
- Once pinned, the client offers only that key type, so a server with several host keys cannot trigger a false mismatch.
- A changed key stops that host before login. There is no "accept anyway" in the run screen; re-pinning is a separate, re-authenticated action in the host form.
- The app logs in only to the pre-boot server. The post-boot check reads a host key and disconnects.

**App hygiene**

- Android: `FLAG_SECURE` on the whole app, `allowBackup="false"` and data-extraction rules that exclude everything. iOS: blur on background, database excluded from iCloud backup.
- Only public keys can be copied or shared.
- Logs record states and server output. Stdin is never logged; any occurrence of a run secret's bytes in output is replaced before it reaches the log, the UI or the database.
- `SSHClient` debug and trace printers stay unset in release builds.

**Server-side advice shown in the setup help** (`docs/server-setup.md`)

- `/etc/dropbear/initramfs/dropbear.conf`: `DROPBEAR_OPTIONS="-p 2222 -s -j -k -I 180 -c cryptroot-unlock"`, then `update-initramfs -u`.
- Print the pre-boot fingerprint: `dropbearkey -y -f /etc/dropbear/initramfs/dropbear_ed25519_host_key`.
- A dedicated LUKS key slot for remote unlock, so a lost phone means removing one slot.
- A dedicated SSH key per device, so one device can be revoked from `authorized_keys`.

## Data model

| Record | Fields |
| --- | --- |
| Host | id, name, group, pre-boot endpoints (ordered list of host + port), user, key id, secret id, disk overrides (disk name → secret id), profile id, post-boot host, post-boot port, post-boot check (`ssh-hostkey` / `tcp` / `none`), wait timeout, boot timeout, pinned pre-boot key (type + SHA-256), seen post-boot key (type + SHA-256), legacy algorithms, enabled |
| SSH key | id, label, type, public key (OpenSSH line), fingerprint, vault record id, created |
| Secret | id, label, vault record id |
| Unlock profile | id, name, built-in (yes/no), driver (`stdin` / `pty`), command; for `pty` only: prompt, success and failure regex |
| Vault record | id, kind (`ssh-key` / `passphrase`), nonce, ciphertext |
| Vault slot | kind (`biometric` / `password`), for password: salt, Argon2id parameters, nonce, wrapped key |
| Run | id, started, per host: final state, events (time, state, sanitized message) |

**Built-in profile: Debian/Ubuntu `cryptroot-unlock`** (from the [Debian script](https://salsa.debian.org/cryptsetup-team/cryptsetup/-/blob/debian/latest/debian/initramfs/cryptroot-unlock))

- Driver `stdin`, command `cryptroot-unlock`. Behaviour and texts as in the step 5 table.

## Implementation phases

Each phase ends with a check the agent runs itself. Rules for every phase:

- Run all builds, tests and tools in Docker through the Makefile; install nothing on the host.
- Code comments only where needed, one short line.
- No secret in any test output, fixture name or log; tests use obviously fake passphrases.
- A phase is done when `make test` is green and its "Done when" holds. Report failures with output; do not weaken a check to pass it.

Phases 1, 3 and 4 do not depend on each other and can run as parallel subagents after phase 0. Phase 2 needs 1. Phase 5 needs 2–4.

**0. Scaffold.** Pub workspace and the layout above. `tool/Dockerfile.dart` (Dart SDK) and `tool/Dockerfile.flutter` (Flutter + Android SDK + Linux desktop build deps), versions pinned. Makefile targets. Strict analysis options. Empty packages that compile.
- Done when: `make test` runs `dart analyze` and an empty test suite for all three packages in Docker and exits 0.

**1. Test bench.** `bench/`: one container image with Dropbear (`dropbear -F -E -p 2222 -s -j -k -c /usr/local/bin/fake-cryptroot-unlock`), an `authorized_keys` from a fixture key, and OpenSSH `sshd` with its own host key as the "booted system". The fake script copies the real script's two modes, texts and exit codes, and is driven by environment variables: `PASSPHRASE`, `DISKS` (names, default one), `NOT_READY_SECONDS` (answers `Try again later` at first), `MAX_TRIES` (default 3), `BOOT_DELAY` (default 3 s). After the last disk unlocks it stops Dropbear and starts `sshd` on port 22 after the delay. Compose file with three such targets on fixed ports, plus a `reset` command.
- Done when: a shell test using the stock `ssh` client proves: right passphrase piped on stdin → exit 0 and the success line; wrong → exit 1 and the failure line; third wrong → the tries line; two disks need two rounds; after success port 2222 closes and port 22 presents a different host key.

**2. Core engine + CLI.** Models, `UnlockEngine`, `StdinDriver`, TCP reachability, the dartssh2 adapter (host-key policy, legacy switch, `probeHostKey`), log sanitizer, timeouts, cancel. CLI: `unlock --config hosts.yaml [--host name | --group g | --all] [--accept-new-host-key]`, keys from files, passphrase from stdin or a file descriptor; exit code 0 only if every host ended Unlocked or Already up.
- First, two spikes against the bench, because the design depends on them: (a) closing the exec session's stdin makes the remote `cat` see end-of-file under Dropbear; (b) `probeHostKey` can read the key and abort cleanly by returning false from `onVerifyHostKey`. If (a) fails, send channel EOF through the lower-level channel API; report before going further.
- Done when: unit tests cover every row of the flow and result tables with fakes; integration tests against the bench end in the right state for: success, two disks, per-disk secrets, not-ready-then-success, wrong passphrase (and no second attempt is made), changed host key, unpinned key refused without the flag, wrong SSH key, absent host, cancel while waiting, already up; a test greps all CLI output and logs for the passphrase and finds nothing.

**3. Keys** (in `unlock_core`). Generate Ed25519; import OpenSSH private keys (Ed25519, RSA, ECDSA; with key passphrase); public line, SHA-256 fingerprint; export of the private key is not offered.
- Done when: a generated key logs into the bench; its public line equals `ssh-keygen -y` output for the same key and its fingerprint equals `ssh-keygen -lf`; keys made by `ssh-keygen` for each type, with and without passphrase, import and log in.

**4. Vault** (crypto in `unlock_core`). Vault key, records, password slot, slot add/remove/change-password, `VaultKeyStore` interface with an in-memory fake. CLI gains `vault` commands so the Linux path is testable headless.
- Done when: unit tests cover round-trips, wrong password, tampered ciphertext, swapped records (associated data), re-wrapping after a password change, and recovery after the biometric slot is lost; the database file contains no plaintext secret (byte search in a test).

**5. App skeleton + data.** Flutter app for Android and Linux (iOS folder generated and kept compiling in principle). Drift schema as in the data model. Screens: hosts, host form, keys (generate, import, show, copy, share, QR), secrets, profiles, settings, first-run vault setup (biometric where available, recovery or master password). Android: `FlutterFragmentActivity`, AppCompat theme, minSdk 24, `FLAG_SECURE`, backups off. Biometric adapter for `VaultKeyStore`; Linux uses the password slot.
- Done when: widget tests cover the forms and their validation (including the `tcp` check port rule); data survives a restart in an integration test on Linux; `make apk` and `make linux` build.

**6. Runs.** Run screen with one biometric or password prompt, parallel per-host cards with live logs, the host-key confirmation dialog, cancel, run history. Android foreground service with notification, wake and Wi-Fi lock, notification permission; started when a run starts, stopped when it ends. Config export and import without secrets.
- Done when: the Linux app unlocks the three bench targets in parallel in an integration test and history shows each final state; the Android build passes the same flow on an emulator in Docker if KVM is available (`adb emu finger touch` for the biometric), otherwise this is handed to the device checklist.

**7. Real target and Android device.** `vm/`: unattended Debian stable install in QEMU (preseed with encrypted root, `dropbear-initramfs`, the options from the setup help), ports forwarded to the host. Run the CLI and the app against it; record the real transcripts as test fixtures and correct the fake script if it differs. Write `docs/security-checklist.md` and `docs/device-checklist.md`.
- Done when: the CLI unlocks the VM and ends in Unlocked; a wrong passphrase ends in Wrong passphrase with the real text; the VM also unlocks with a second LUKS disk. Then the user runs the device checklist on a real Android phone: secrets unreadable without biometric, one prompt per run, run survives screen-off, new fingerprint → recovery password flow, PIN fallback setting.

**8. iOS.** Needs the user's Mac with Xcode and an iPhone. `Info.plist`: `NSFaceIDUsageDescription`, `NSLocalNetworkUsageDescription`; blur on background; backup exclusion; wakelock during runs; a 30 s background-task grace so an unlock in progress finishes if the app is left.
- Done when: the user completes the device checklist on an iPhone against the bench or VM.

## After v1

In this order unless priorities change:

1. **Armed watch.** One fingerprint, pick hosts and a time limit (default 2 h), secrets held in memory only; the engine loops per host: wait for pre-boot → unlock → wait for boot → wait for the pre-boot key to appear again. Android (foreground service) and CLI/desktop only. Ends on timeout, on cancel, or on any Wrong passphrase or Host key mismatch.
2. **`pty` driver** with prompt, success and failure patterns, and presets for Fedora/RHEL dracut-sshd (`systemd-tty-ask-password-agent`), Arch mkinitcpio and ZFS, each finished against a real VM transcript.
3. **More post-boot checks:** ICMP (`dart_ping` 10.x, which now bundles its iOS engine) and HTTP.
4. **Encrypted full backup:** database export plus a password slot; restore creates a new biometric slot.
5. **macOS and Windows** builds (macOS can use Touch ID through biometric\_vault; Windows uses the password slot).

## Testing

| Level | What | Where it runs |
| --- | --- | --- |
| Unit | Every state-machine transition and every row of the result table with fake SSH, reachability and clock | Docker, `make test` |
| Unit | Sanitizer never emits a run secret; vault crypto cases from phase 4 | Docker |
| Unit | Key generation and import against `ssh-keygen` | Docker |
| Integration | CLI against the Dropbear bench: all cases listed in phase 2 | Docker Compose |
| Widget / integration | Forms; Linux app against the bench | Docker (headless with Xvfb) |
| Device | Biometric vault, recovery flow, PIN setting, one prompt per run, screen-off run | Real Android phone and iPhone, by the user, from `docs/device-checklist.md` |
| End to end | Debian QEMU VM with real LUKS, one and two disks | Local, Docker with `/dev/kvm`, before each release |

## Decisions

All former open questions, closed.

| Question | Decision |
| --- | --- |
| Framework | Flutter + dartssh2. See Rejected alternatives. |
| Vault library | biometric\_vault, holding only the vault key. Enrollment change invalidates the biometric slot; the recovery password restores access. |
| Desktop vault | Master password (Argon2id). No OS keyring: it has no gate on Linux. No phone-approves-desktop: it would need a new transport. |
| Watch mode | Not in v1. First item after v1, as "armed watch". |
| Pre-boot gate | TCP connect to the SSH port only. |
| Post-boot check | SSH host-key check by default; `tcp` or `none` per host; ICMP and HTTP after v1. |
| Several disks | One secret per host by default, optional per-disk overrides. The disk name is read before the passphrase is sent. A rejected passphrase stops the host. |
| iOS limits | Accepted: the app stays open and the screen awake during a run. |
| Multiple devices | No sync. Config export/import without secrets in v1; encrypted full backup after v1. |
| Platforms for v1 | Android, iOS, Linux desktop, CLI. |
| Server types for v1 | Debian/Ubuntu dropbear-initramfs. |
| CI | None for now; `make test` in Docker is the single entry point, so a CI wrapper can be added later unchanged. |

## What needs the user

- A Mac with Xcode, an Apple developer account and an iPhone for phase 8.
- An Android phone with a fingerprint enrolled for the phase 7 device checklist.
- `/dev/kvm` available to Docker on the build machine for the VM and emulator tests.

## Sources

- [dartssh2](https://pub.dev/packages/dartssh2) 4.1.0 source and changelog · [biometric\_vault](https://pub.dev/packages/biometric_vault) 1.1.2 README · [dart\_ping](https://pub.dev/packages/dart_ping) 10.0.1 README
- [Debian cryptroot-unlock source](https://salsa.debian.org/cryptsetup-team/cryptsetup/-/blob/debian/latest/debian/initramfs/cryptroot-unlock) · [Dropbear unlock session](https://www.dwarmstrong.org/remote-unlock-dropbear) · [Red Hat: unlock a LUKS root over SSH](https://developers.redhat.com/articles/2026/09/11/unlock-a-luks-root-over-ssh-on-fedora-and-red-hat-enterprise-linux)
- Prior art links are in the Prior art table.
