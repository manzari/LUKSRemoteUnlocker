# LUKS Remote Unlocker — Summary & Implementation Plan

Nov 14, 2026 · @Mister

## Summary

Build one app for Android, iOS and desktop that unlocks LUKS-encrypted Linux servers waiting at the Dropbear pre-boot prompt, one tap per server or all at once.

For each server the app waits until the pre-boot address answers, logs in over SSH with the key assigned to that server, types the disk passphrase, and reads the reply. It counts the unlock as done only when the server's post-boot address answers too.

The user manages servers, SSH keys and passphrases in the app and decides which key goes with which server. Keys and passphrases sit in a vault that opens with a fingerprint or face, backed by the phone's secure hardware (Android Keystore, iPhone Secure Enclave).

This doc is the hand-off: Claude Code builds the app phase by phase from it, and the open questions at the end are for refining the design with Fable.

## Prior art

No existing tool does the whole job: none checks a second address after the unlock, none keeps keys in a fingerprint-protected vault, and none runs on a phone.

| Tool | What it does | What it lacks for us |
| --- | --- | --- |
| [cryptsetup-ssh-unlocker](https://github.com/viktorstiskala/cryptsetup-ssh-unlocker) (Python) | Polls many servers for an open SSH port, then unlocks; pins host keys via known\_hosts | Desktop/server only; runs cryptsetup itself instead of answering the prompt; last pushed 2018 |
| [dropbear-auto-unlock](https://github.com/hugojosefson/dropbear-auto-unlock) (Deno) | Many servers with fallback addresses, retries, waits for the next reboot after an unlock | ZFS prompt only; treats a shell prompt as success; no post-boot check |
| [SSHUnlockLUKS](https://github.com/Ixtalo/SSHUnlockLUKS) (Python) | One server per config, run from cron | One host, no UI, no vault |
| [android-luks](https://github.com/full-disclosure/android-luks) | Phone unlocks a PC with biometrics | USB accessory mode, not network |
| [tanga](https://github.com/gernotfeichter/tanga) | Tang server on the phone (network-bound encryption) | Different model: automatic unlock on the same Wi-Fi, no SSH |

Worth borrowing: host-key pinning from cryptsetup-ssh-unlocker, and the per-host state machine with fallback addresses from dropbear-auto-unlock.

## Requirements

The must-haves are host and key management, a biometric vault, and an unlock run that ends with a post-boot ping.

**Hosts**

- Name, pre-boot address (IP or hostname) and port; Dropbear often listens on 2222, not 22.
- One or more fallback pre-boot addresses (LAN IP, VPN IP), tried in turn.
- Login user (default `root`).
- Assigned SSH key, picked from the key list.
- Assigned passphrase, picked from the vault.
- Post-boot check address (may differ from the pre-boot one) and a timeout.
- Pinned host-key fingerprint of the pre-boot SSH server, stored on first connect after the user confirms it.
- Unlock profile (see below), groups or tags for "unlock all in group".

**SSH keys**

- Generate Ed25519 in the app; import existing OpenSSH private keys (Ed25519, RSA, ECDSA), with or without a key passphrase.
- Show, copy, share and QR-encode the public key in `authorized_keys` format.
- One key can serve many hosts; each host has exactly one key.

**Passphrases**

- Stored per host, or as a named secret reused by several hosts.
- Never shown in clear unless the user asks and re-authenticates.

**Unlock profiles** (prompt handling differs by initramfs)

- Each profile = command to run after login (empty when Dropbear forces one), a prompt pattern, a success pattern, a wrong-passphrase pattern.
- Ship presets: Debian/Ubuntu `cryptroot-unlock`, dracut `systemd-tty-ask-password-agent`, dracut-crypt-ssh `unlock`, Arch mkinitcpio. User can copy and edit a preset.

**Runs**

- Unlock one host, a group, or all; hosts run in parallel, each with its own live log.
- Cancel at any point; retry with backoff while waiting for the server.
- Final state per host: Unlocked (post-boot ping answered), Wrong passphrase, Host key mismatch, Auth failed, Timed out, Cancelled.
- Run history with timestamps; passphrases never appear in logs.
- Optional later: a TCP or HTTP service check after the ping.

**Non-functional**

- Works offline; no cloud, no telemetry, no analytics.
- Secrets never written to disk in clear, never in logs, crash reports or clipboard history.
- Android keeps running with the screen off during a run (foreground service with a notification).
- Config export without secrets; encrypted full backup as a later phase.

## Unlock flow

Each host runs this sequence on its own, and the passphrase is sent only after the server's host key matches the pinned one.

&#91;embedded content: per-host unlock flow · 6 steps, 4 failure exits, 2 retry loops\]

Red boxes end the run for that host. The two loops on the left retry on their own: "Try again later" means the server isn't ready for the passphrase yet, and a second prompt means a second encrypted disk.

## Architecture and tech stack

Recommended: Flutter (Dart), one codebase for Android, iOS, Linux, macOS and Windows, built around a pure-Dart core that also ships as a CLI.

| Concern | Choice | Why / notes |
| --- | --- | --- |
| App framework | Flutter | One UI for phone and desktop; the libraries below all exist for it |
| SSH client | [dartssh2](https://pub.dev/packages/dartssh2) | Pure Dart; shells with a pseudo-terminal; public-key auth with Ed25519, RSA, ECDSA; host-key check callback |
| Vault | [biometric\_vault](https://pub.dev/packages/biometric_vault) (alt: biometric\_storage) | Android Keystore (StrongBox, else TEE) behind BiometricPrompt Class 3; iOS/macOS Keychain. Linux and Windows fall back to storage without a biometric gate |
| Ping | [dart\_ping](https://pub.dev/packages/dart_ping) 10.x | ICMP on all five platforms; iOS via a bundled Swift engine, the others via the system `ping` |
| SSH port probe | `Socket.connect` with timeout | Gate before SSH: ping can answer before Dropbear listens |
| Key generation | Ed25519 library + OpenSSH encoder | dartssh2 parses keys; check whether it can also generate, else add one and test the encoder against `ssh-keygen` |
| Local database | drift (SQLite) | Non-secret data only: hosts, profiles, public keys, run history |
| State | Riverpod | Per-host run state streams into the UI |
| Android background | Foreground service with notification | A run survives screen-off and app switch |
| iOS background | None | iOS stops long background work; the run happens with the app open and the screen kept awake |

**Layers**

1. `unlock_core` (pure Dart, no Flutter): models, unlock state machine, prompt matcher, interfaces for SSH, reachability and secrets. Fully unit-testable.
2. `unlock_cli`: thin command-line wrapper over the core, reading a YAML config, keys from files, passphrase from stdin. Used for integration tests and headless desktop use.
3. Platform adapters: vault, ping, background service, each behind a core interface.
4. Flutter UI: hosts, keys, secrets, profiles, runs, settings.

Alternatives for Fable to weigh are in Open questions: Kotlin Multiplatform, or Tauri 2 with the Rust `russh` client.

## Security model

The passphrase is only as safe as the server it is typed into, so host-key pinning matters as much as the vault.

**Vault**

- Private keys and passphrases are vault entries; everything else lives in the plain database.
- Android: Keystore key (StrongBox when present) usable only after a strong (Class 3) biometric. iPhone: Keychain item with biometric access control, protected by the Secure Enclave. This is the phone's equivalent of a TPM.
- One biometric prompt per run releases the entries that run needs. Secrets stay in memory only for the run, as byte arrays overwritten afterwards (Dart cannot guarantee wiping; note it, don't overclaim).
- Setting: allow the device PIN as fallback, or biometric only.
- Desktop (Linux, Windows): no biometric gate is available, so use a master password (Argon2id-derived key) or the OS keyring. macOS can use Touch ID through the Keychain.

**Host-key pinning**

- First connect shows the pre-boot server's SHA-256 fingerprint; the user confirms it or pastes the expected one.
- A changed key stops the run before any passphrase is sent. No "accept anyway" in the run screen; re-pinning is a separate, re-authenticated action.
- The pre-boot (Dropbear) host key differs from the running system's key; the app only ever SSHes to the pre-boot one.

**App hygiene**

- Block screenshots and recent-apps previews on secret screens (Android `FLAG_SECURE`, iOS blur on background).
- Copied public keys only; never copy a passphrase. Clear any clipboard use after 30 seconds.
- Logs record states and server output with the passphrase and any echo of it removed.

**Server-side advice the app shows in its setup help**

- Dropbear options `-s -j -k -c cryptroot-unlock`: no password login, no port forwarding, only the unlock command.
- A dedicated LUKS key slot for remote unlock, so a lost phone means removing one slot, not changing the main passphrase.
- A dedicated SSH key per phone, so one device can be revoked from `authorized_keys`.

## Data model

Five records; only two fields across them hold secrets, and those are vault references, never values.

| Record | Fields | Stored in |
| --- | --- | --- |
| Host | id, name, group, pre-boot addresses (list of host + port, in try order), user, key id, secret id, profile id, post-boot address, wait timeout, verify timeout, pinned host-key SHA-256, enabled | Database |
| SSH key | id, label, type, public key (OpenSSH line), fingerprint, vault ref to private key, created | Database + vault |
| Secret | id, label, vault ref to passphrase, hosts using it (derived) | Database + vault |
| Unlock profile | id, name, command to run (empty if Dropbear forces one), prompt regex, success regex, failure regex, repeat for several disks (yes/no) | Database |
| Run | id, started, per host: final state, events (time, state, sanitized message) | Database |

**Built-in profile: Debian/Ubuntu `cryptroot-unlock`** (from the [Debian script](https://sources.debian.org/src/cryptsetup/2:2.8.4-1/debian/initramfs/cryptroot-unlock) and a [real session](https://www.dwarmstrong.org/remote-unlock-dropbear))

- Command: `cryptroot-unlock`, or empty when Dropbear runs with `-c cryptroot-unlock`.
- Prompt: ` Please unlock disk (\S+):  ` — repeats once per encrypted disk.
- Success: `cryptsetup: (\S+) set up successfully`, then the server closes the connection.
- Not ready yet: `Try again later` — treat as "retry in a few seconds", not failure.
- Wrong passphrase: capture the exact text on the test bench before writing the regex.

**Built-in profile: Fedora/RHEL dracut-sshd** ([Red Hat guide](https://developers.redhat.com/articles/2026/09/11/unlock-a-luks-root-over-ssh-on-fedora-and-red-hat-enterprise-linux))

- Command: `systemd-tty-ask-password-agent`.
- Prompt: `Please enter passphrase for disk (.+):`.
- Success: the connection closes after the answer; confirm on the bench.

Other presets (dracut-crypt-ssh `unlock`, Arch mkinitcpio) are added the same way once their transcripts are recorded.

## Implementation phases

Seven phases; each ends with a check Claude Code can run itself before moving on. Build the engine and test bench before any UI.

1. **Test bench.** Docker Compose with a fake pre-boot target: OpenSSH on port 2222, key-only login, `ForceCommand` running a script that mimics `cryptroot-unlock` (prompt, read passphrase, print success or error, exit). On success it brings up a second container or IP alias that answers ping, standing in for the booted system.
   - Done when: `ssh -p 2222` with the right key and passphrase prints the success line, and the post-boot address starts answering ping within 10 s.
2. **Core engine + CLI.** State machine, prompt matcher, reachability (ping, then TCP probe), dartssh2 session with PTY, host-key pinning, timeouts, cancel. CLI reads YAML hosts, key files and the passphrase from stdin.
   - Done when: the CLI unlocks the bench target; a wrong passphrase, a changed host key, an absent host and a cancel each end in their named state; no passphrase appears in any output.
3. **App skeleton + data.** Flutter app, drift database, screens to add, edit and delete hosts, keys, secrets and profiles; assign a key and a secret to each host.
   - Done when: widget tests cover the forms; data survives an app restart.
4. **Keys.** Generate Ed25519, import OpenSSH private keys (with key passphrase), show, copy, share and QR-encode the public key.
   - Done when: a generated key logs into the bench, and its public line matches what `ssh-keygen -y` derives from the same private key.
5. **Vault.** Biometric vault on Android and iOS, master-password vault on Linux and Windows, Keychain on macOS. One prompt per run.
   - Done when: on a real Android phone and iPhone, secrets cannot be read without the biometric, and a run asks once.
6. **Runs.** Unlock one, a group or all; parallel per-host runs with live logs; Android foreground service and notification; iOS keeps the screen awake; run history.
   - Done when: three bench targets unlock in parallel from the phone with the screen off (Android), and history shows each final state.
7. **Real targets and hardening.** QEMU VMs with real LUKS and dropbear-initramfs (Debian) and dracut-sshd (Fedora); record transcripts and finish both profiles. Add screenshot blocking, clipboard clearing, config export.
   - Done when: both VMs unlock from the phone and reach the post-boot ping; a security review checklist passes.

## Testing

Most behavior is tested without a phone: the core runs against fakes and the Docker bench in CI; only the vault and background behavior need real devices.

| Level | What | Where it runs |
| --- | --- | --- |
| Unit | Prompt matcher against recorded transcripts (one disk, two disks, wrong passphrase, "Try again later"); every state-machine transition with fake SSH and reachability | CI |
| Unit | Log sanitizer never emits the passphrase, even if the server echoes it | CI |
| Integration | CLI against the Docker bench: success, wrong passphrase, host-key change, unreachable, timeout, cancel mid-wait | CI |
| Widget | Host, key, secret and profile forms; key-to-host assignment | CI |
| Device | Biometric vault, PIN fallback setting, one prompt per run, foreground service with screen off | Real Android phone and iPhone (biometrics are unreliable in the iOS simulator) |
| End to end | Debian and Fedora QEMU VMs with real LUKS, unlocked from the phone, post-boot ping confirmed | Local, before each release |

## Open questions for Fable

Each needs a decision before or during the phase named; the plan above assumes the first option.

- [ ] **Framework** (before phase 1): Flutter + dartssh2, Kotlin Multiplatform, or Tauri 2 + Rust `russh`? Weigh SSH library maturity, the biometric plugin on each, and iOS ICMP.
- [ ] **Vault library** (phase 5): biometric\_vault, biometric\_storage or biometric\_security? Should a new fingerprint enrollment invalidate the vault (safer, but forces re-import)?
- [ ] **Desktop vault** (phase 5): master password, OS keyring, or require the phone to approve desktop runs?
- [ ] **Watch mode** (phase 6): keep waiting across reboots and unlock without a tap? It conflicts with a per-run biometric, because the secret must be readable unattended.
- [ ] **Pre-boot gate** (phase 2): ping then TCP probe, or TCP probe only for networks that drop ICMP?
- [ ] **Post-boot check** (phase 6): ping only, or optional TCP port / HTTP check per host?
- [ ] **Several disks** (phase 2): same passphrase for every prompt, or one secret per disk name?
- [ ] **iOS limits** (phase 6): is "keep the app open during a run" acceptable on iPhone?
- [ ] **Multiple devices** (later): any sync of hosts between phone and desktop, or strictly per-device with export/import?

## Sources

- [dartssh2](https://pub.dev/packages/dartssh2) · [biometric\_vault](https://pub.dev/packages/biometric_vault) · [dart\_ping](https://pub.dev/packages/dart_ping)
- [Debian cryptroot-unlock source](https://sources.debian.org/src/cryptsetup/2:2.8.4-1/debian/initramfs/cryptroot-unlock) · [Dropbear unlock session](https://www.dwarmstrong.org/remote-unlock-dropbear) · [Red Hat: unlock a LUKS root over SSH](https://developers.redhat.com/articles/2026/09/11/unlock-a-luks-root-over-ssh-on-fedora-and-red-hat-enterprise-linux)
- Prior art links are in the Prior art table.
