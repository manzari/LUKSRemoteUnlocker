import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/unlock_core.dart';

import '../../providers.dart';
import '../../services/config_transfer.dart';
import '../../vault/vault_controller.dart';
import '../../version.dart';
import '../common/messages.dart';
import '../common/password_fields.dart';
import '../help/setup_help_screen.dart';
import '../vault/unlock.dart';
import 'import_summary_dialog.dart';

/// `luks-unlocker-config-2026-11-16.json`
String exportFileName(DateTime d) =>
    'luks-unlocker-config-${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}.json';

/// "1 host", "2 hosts".
String countOf(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  VaultController get _controller => ref.read(vaultControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    unawaited(_controller.refreshCapabilities());
  }

  /// Unlocks if needed, runs [action], shows errors; [done] is shown on success.
  Future<void> _run(Future<void> Function() action, {String? done}) async {
    final vault = await requireVault(context, ref);
    if (vault == null || !mounted) return;
    await _busyRun(action, done: done);
  }

  Future<void> _busyRun(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (done != null && mounted) showMessage(context, done);
    } on Object catch (e) {
      if (mounted && !isCancellation(e)) showMessage(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The only other slot is biometric, so adding needs a fresh biometric check.
  Future<void> _addPassword() async {
    final vault = await requireVault(
      context,
      ref,
      fresh: true,
      reason: 'Confirm it is you before adding a recovery password.',
    );
    if (vault == null || !mounted) return;
    final Uint8List? password = await askNewPassword(
      context,
      title: 'Add recovery password',
      message: 'Opens the vault when biometric unlock stops working.',
    );
    if (password == null) return;
    try {
      if (!mounted) return;
      await _busyRun(
        () => _controller.addPassword(password),
        done: 'Password saved',
      );
    } finally {
      password.fillRange(0, password.length, 0);
    }
  }

  /// The current password is the authentication; no unlock needed first.
  Future<void> _changePassword(String title) async {
    final change = await askPasswordChange(context, title: title);
    if (change == null) return;
    try {
      if (!mounted) return;
      await _busyRun(
        () => _controller.changePassword(change.current, change.next),
        done: 'Password changed',
      );
    } finally {
      change.current.fillRange(0, change.current.length, 0);
      change.next.fillRange(0, change.next.length, 0);
    }
  }

  Future<void> _removePassword() async {
    final ok = await confirm(
      context,
      title: 'Remove the recovery password?',
      message:
          'Without a recovery password the vault is lost when the '
          'fingerprints or face on this device change. Biometric unlock '
          'is checked once before the password is removed.',
      action: 'Remove',
      destructive: true,
    );
    if (ok && mounted) {
      await _run(_controller.removePassword, done: 'Recovery password removed');
    }
  }

  Future<void> _export() async {
    final transfer = ref.read(configTransferProvider);
    final services = ref.read(platformServicesProvider);
    await _busyRun(() async {
      final export = await transfer.export();
      final saved = await services.saveConfigFile(
        exportFileName(DateTime.now()),
        export.bytes,
      );
      if (!saved || !mounted) return;
      final skipped = export.unreadable == 0
          ? ''
          : ' ${countOf(export.unreadable, 'unreadable host')} left out.';
      showMessage(
        context,
        'Exported ${countOf(export.hosts, 'host')} and '
        '${countOf(export.profiles, 'profile')}.$skipped',
      );
    });
  }

  Future<void> _import() async {
    final transfer = ref.read(configTransferProvider);
    final ImportPlan plan;
    try {
      final file = await ref.read(platformServicesProvider).pickConfigFile();
      if (file == null) return;
      plan = await transfer.preview(file.bytes);
    } on Object catch (e) {
      if (mounted) {
        await inform(
          context,
          title: 'Cannot import this file',
          message: describeError(e),
        );
      }
      return;
    }
    if (!mounted) return;
    final trustPins = await showImportSummary(context, plan);
    if (trustPins == null || !mounted) return;
    await _busyRun(() async {
      final added = await transfer.apply(plan, trustPins: trustPins);
      final profiles = plan.newProfiles.length;
      if (!mounted) return;
      showMessage(
        context,
        'Imported ${countOf(added, 'host')}'
        '${profiles == 0 ? '' : ' and ${countOf(profiles, 'profile')}'}.',
      );
    });
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ResetDialog(),
    );
    if (ok != true) return;
    await _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(vaultControllerProvider);
    final biometric = status.biometricAvailable || status.biometricEnrolled;
    final passwordName = status.biometricEnrolled
        ? 'Recovery password'
        : 'Master password';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: const [VaultLockButton()],
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          children: [
            if (_busy) const LinearProgressIndicator(),
            const _Header('Vault'),
            ListTile(
              leading: Icon(
                status.isUnlocked ? Icons.lock_open : Icons.lock_outline,
              ),
              title: Text(status.isUnlocked ? 'Unlocked' : 'Locked'),
              subtitle: Text(
                'Locks when the app goes to the background or after '
                '${describeDuration(ref.watch(autoLockAfterProvider))} '
                'without input',
              ),
              trailing: status.isUnlocked
                  ? TextButton(
                      onPressed: _controller.lock,
                      child: const Text('Lock now'),
                    )
                  : TextButton(
                      onPressed: () => requireVault(context, ref),
                      child: const Text('Unlock'),
                    ),
            ),
            if (biometric) ...[
              ListTile(
                leading: const Icon(Icons.fingerprint),
                title: const Text('Biometric unlock'),
                subtitle: Text(
                  !status.biometricEnrolled
                      ? 'Off'
                      : status.biometricInvalidated
                      ? 'Switched off by the system after a change of '
                            'fingerprints or face'
                      : 'On',
                ),
                trailing: status.biometricAvailable
                    ? TextButton(
                        onPressed: () => _run(
                          _controller.enrollBiometrics,
                          done: 'Biometric unlock set up',
                        ),
                        child: Text(
                          status.biometricEnrolled ? 'Re-enroll' : 'Set up',
                        ),
                      )
                    : null,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.pin_outlined),
                title: const Text('Allow device PIN as fallback'),
                subtitle: const Text(
                  'The device PIN, pattern or password can open the vault '
                  'instead of a fingerprint or face',
                ),
                value: status.allowDeviceCredential,
                onChanged: status.biometricEnrolled
                    ? (v) => _run(() => _controller.setAllowDeviceCredential(v))
                    : null,
              ),
            ],
            ListTile(
              leading: const Icon(Icons.password),
              title: Text(passwordName),
              subtitle: Text(
                status.hasPasswordSlot
                    ? 'Set'
                    : 'Not set. The vault is lost if biometric unlock stops '
                          'working.',
              ),
              trailing: Wrap(
                children: [
                  if (status.hasPasswordSlot)
                    TextButton(
                      onPressed: () => _changePassword(
                        'Change ${passwordName.toLowerCase()}',
                      ),
                      child: const Text('Change'),
                    )
                  else
                    TextButton(
                      onPressed: _addPassword,
                      child: const Text('Add'),
                    ),
                  if (status.hasPasswordSlot && status.biometricEnrolled)
                    TextButton(
                      onPressed: _removePassword,
                      child: const Text('Remove'),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Reset vault'),
              subtitle: const Text(
                'Deletes all SSH keys and passphrases. Use it when the vault '
                'cannot be opened any more.',
              ),
              onTap: _reset,
            ),
            const _Header('Configuration'),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Export configuration'),
              subtitle: const Text(
                'Hosts and custom profiles. Keys and passphrases are only '
                'named, never included.',
              ),
              onTap: _export,
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Import configuration'),
              subtitle: const Text(
                'Adds the hosts of an export. Hosts already here are never '
                'changed.',
              ),
              onTap: _import,
            ),
            const _Header('Help'),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Server setup'),
              subtitle: const Text('Dropbear options, host key fingerprint'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const SetupHelpScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              subtitle: const Text(
                'LUKS Remote Unlocker $appVersion (core $unlockCoreVersion)',
              ),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'LUKS Remote Unlocker',
                applicationVersion: appVersion,
                applicationLegalese:
                    'Works offline. No cloud, no telemetry, no analytics.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _ResetDialog extends StatefulWidget {
  const _ResetDialog();

  @override
  State<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends State<_ResetDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return AlertDialog(
      title: const Text('Reset the vault?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All SSH keys and passphrases are deleted and cannot be '
            'recovered. Hosts and profiles stay, without their key and '
            'passphrase. Then a new vault is set up.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('reset-confirm'),
            controller: _text,
            decoration: const InputDecoration(labelText: 'Type RESET'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: error),
          onPressed: _text.text.trim() == 'RESET'
              ? () => Navigator.pop(context, true)
              : null,
          child: const Text('Reset'),
        ),
      ],
    );
  }
}
