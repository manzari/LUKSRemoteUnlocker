import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/vault.dart';

import '../../providers.dart';
import '../../vault/vault_controller.dart';
import '../common/messages.dart';
import '../common/password_fields.dart';

/// The unlocked vault, asking to unlock first; [fresh] forces re-authentication.
Future<Vault?> requireVault(
  BuildContext context,
  WidgetRef ref, {
  bool fresh = false,
  String? reason,
}) async {
  final controller = ref.read(vaultControllerProvider.notifier);
  if (fresh) controller.lock();
  final vault = controller.unlockedVault;
  if (vault != null) {
    controller.touch();
    return vault;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => UnlockDialog(reason: reason),
  );
  return ok == true ? controller.unlockedVault : null;
}

class VaultLockButton extends ConsumerWidget {
  const VaultLockButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(
      vaultControllerProvider.select((s) => s.isUnlocked),
    );
    return IconButton(
      tooltip: unlocked ? 'Lock vault' : 'Unlock vault',
      icon: Icon(unlocked ? Icons.lock_open : Icons.lock_outline),
      onPressed: unlocked
          ? ref.read(vaultControllerProvider.notifier).lock
          : () => requireVault(context, ref),
    );
  }
}

class UnlockDialog extends ConsumerStatefulWidget {
  const UnlockDialog({super.key, this.reason});

  final String? reason;

  @override
  ConsumerState<UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends ConsumerState<UnlockDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  VaultController get _controller => ref.read(vaultControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    if (ref.read(vaultControllerProvider).canUseBiometrics) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_biometric());
      });
    }
  }

  @override
  void dispose() {
    _password
      ..clear()
      ..dispose();
    super.dispose();
  }

  Future<void> _biometric() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _controller.unlockWithBiometrics();
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = isCancellation(e) ? null : describeError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withPassword() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter the password');
      return;
    }
    final status = ref.read(vaultControllerProvider);
    final recover = status.biometricInvalidated && status.biometricAvailable;
    final bytes = textBytes(_password);
    _password.clear();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (recover) {
        await _controller.recover(bytes);
      } else {
        await _controller.unlockWithPassword(bytes);
      }
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (!mounted) return;
      if (_controller.unlockedVault != null) {
        showMessage(
          context,
          'Unlocked, but biometric unlock was not set up again. '
          'Retry in Settings.',
        );
        Navigator.pop(context, true);
      } else {
        setState(() => _error = describeError(e));
      }
    } finally {
      bytes.fillRange(0, bytes.length, 0);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(vaultControllerProvider);
    final theme = Theme.of(context);
    final invalidated = status.biometricInvalidated;
    final passwordName = status.biometricEnrolled
        ? 'recovery password'
        : 'master password';
    return AlertDialog(
      title: const Text('Unlock the vault'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.reason case final r?) ...[
              Text(r),
              const SizedBox(height: 16),
            ],
            if (invalidated) ...[
              Text(
                status.hasPasswordSlot
                    ? 'The fingerprints or face on this device changed, so the '
                          'system switched off biometric unlock. Enter the '
                          'recovery password; biometric unlock is set up '
                          'again afterwards.'
                    : 'The fingerprints or face on this device changed, so the '
                          'system switched off biometric unlock. There is no '
                          'recovery password, so the vault cannot be opened. '
                          'Reset the vault in Settings and enter the keys and '
                          'passphrases again.',
              ),
              const SizedBox(height: 16),
            ],
            if (status.canUseBiometrics) ...[
              FilledButton.icon(
                onPressed: _busy ? null : _biometric,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Use biometrics'),
              ),
              const SizedBox(height: 16),
            ],
            if (status.hasPasswordSlot)
              TextField(
                key: const ValueKey('unlock-password'),
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                autofocus: !status.canUseBiometrics,
                decoration: InputDecoration(
                  labelText: invalidated
                      ? 'Recovery password'
                      : status.canUseBiometrics
                      ? 'Or the $passwordName'
                      : 'Password',
                ),
                onSubmitted: (_) => _withPassword(),
              ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            if (_error case final e?) ...[
              const SizedBox(height: 12),
              Text(e, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        if (status.hasPasswordSlot)
          FilledButton(
            onPressed: _busy ? null : _withPassword,
            child: Text(invalidated ? 'Recover' : 'Unlock'),
          ),
      ],
    );
  }
}
