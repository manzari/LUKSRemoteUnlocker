import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../providers.dart';
import '../common/messages.dart';
import '../common/password_fields.dart';

/// First run: biometric slot plus recovery password, or a master password alone.
class VaultSetupScreen extends ConsumerStatefulWidget {
  const VaultSetupScreen({super.key});

  @override
  ConsumerState<VaultSetupScreen> createState() => _VaultSetupScreenState();
}

class _VaultSetupScreenState extends ConsumerState<VaultSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password
      ..clear()
      ..dispose();
    _confirmation
      ..clear()
      ..dispose();
    super.dispose();
  }

  Future<void> _create({required bool withPassword}) async {
    final biometric = ref.read(vaultControllerProvider).biometricAvailable;
    if (withPassword && !_form.currentState!.validate()) return;
    final password = withPassword ? textBytes(_password) : null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(vaultControllerProvider.notifier)
          .setUp(password: password, biometric: biometric);
      _password.clear();
      _confirmation.clear();
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => _error = isCancellation(e)
              ? 'Biometric setup was cancelled. Try again.'
              : describeError(e),
        );
      }
    } finally {
      password?.fillRange(0, password.length, 0);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skipPassword() async {
    final ok = await confirm(
      context,
      title: 'Continue without a recovery password?',
      message:
          'Without a recovery password the vault is lost when the '
          'fingerprints or face on this device change, for example when you '
          'add a fingerprint. All SSH keys and passphrases would then have to '
          'be entered again.',
      action: 'Continue without',
      destructive: true,
    );
    if (ok && mounted) await _create(withPassword: false);
  }

  @override
  Widget build(BuildContext context) {
    final biometric = ref.watch(
      vaultControllerProvider.select((s) => s.biometricAvailable),
    );
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Set up the vault')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Image.asset(
                    'assets/logo.png',
                    width: 88,
                    height: 88,
                    semanticLabel: 'LUKS Remote Unlocker',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'SSH keys and disk passphrases are encrypted with a vault '
                  'key that never leaves this device.',
                ),
                const SizedBox(height: 12),
                Text(
                  biometric
                      ? 'Your fingerprint or face unlocks the vault. The '
                            'recovery password opens it when biometric unlock '
                            'stops working, for example after you add a '
                            'fingerprint.'
                      : 'Choose a master password. It is the only way to open '
                            'the vault; it cannot be recovered.',
                ),
                SectionHeader(
                  biometric
                      ? 'Recovery password (recommended)'
                      : 'Master password',
                ),
                NewPasswordFields(
                  password: _password,
                  confirmation: _confirmation,
                  label: biometric ? 'Recovery password' : 'Master password',
                  enabled: !_busy,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : () => _create(withPassword: true),
                  child: Text(
                    biometric ? 'Set up biometric unlock' : 'Create vault',
                  ),
                ),
                if (biometric) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : _skipPassword,
                    child: const Text('Continue without recovery password'),
                  ),
                ],
                if (_busy) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                ],
                if (_error case final e?) ...[
                  const SizedBox(height: 16),
                  Text(e, style: TextStyle(color: theme.colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
