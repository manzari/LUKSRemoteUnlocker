# Security policy

LUKS Remote Unlocker stores SSH private keys and disk passphrases, so security reports are taken seriously.

## Reporting a vulnerability

Please do not open a public issue for a security problem. Report it privately instead:

- through GitHub's "Report a vulnerability" button on the repository's Security tab, or
- by email to mail@manzari.dev.

Include the affected version, the platform (Android, Linux desktop, CLI), and steps to reproduce. You should get a reply within a week.

## Supported versions

Only the latest release receives security fixes.

## Scope

In scope: the vault and its key slots, host-key pinning, the handling of passphrases and private keys in memory, logs and exports, and the CLI's file handling.

Out of scope: the keys in `bench/fixtures/` and `app/test/fixtures/`. They are throwaway test keys that protect nothing.

The security model is described in [docs/design.md](docs/design.md#security-model).
