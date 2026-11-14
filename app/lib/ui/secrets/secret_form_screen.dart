import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/secret_repository.dart';
import '../../providers.dart';
import '../common/messages.dart';
import '../common/password_fields.dart';
import '../vault/unlock.dart';

/// Adds a passphrase, or with [replacing] replaces the bytes of an existing one.
class SecretFormScreen extends ConsumerStatefulWidget {
  const SecretFormScreen({super.key, this.replacing});

  final StoredSecret? replacing;

  @override
  ConsumerState<SecretFormScreen> createState() => _SecretFormScreenState();
}

class _SecretFormScreenState extends ConsumerState<SecretFormScreen> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _passphrase = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _replace => widget.replacing != null;

  @override
  void dispose() {
    _label.dispose();
    _passphrase
      ..clear()
      ..dispose();
    _confirmation
      ..clear()
      ..dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final vault = await requireVault(
      context,
      ref,
      reason: 'The passphrase is stored encrypted in the vault.',
    );
    if (vault == null || !mounted) return;
    final bytes = textBytes(_passphrase);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(secretRepositoryProvider);
      if (widget.replacing case final s?) {
        await repo.replace(vault, s.id, bytes);
      } else {
        await repo.add(vault, label: _label.text, passphrase: bytes);
      }
      _passphrase.clear();
      _confirmation.clear();
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      bytes.fillRange(0, bytes.length, 0);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _replace ? 'Replace "${widget.replacing!.label}"' : 'Add passphrase',
      ),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Stored and sent exactly as typed, including spaces, without a '
            'trailing newline. It is never copied to the clipboard.',
          ),
          const SizedBox(height: 16),
          if (!_replace) ...[
            TextFormField(
              key: const ValueKey('secret-label'),
              controller: _label,
              decoration: const InputDecoration(labelText: 'Label'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a label' : null,
            ),
            const SizedBox(height: 12),
          ],
          NewPasswordFields(
            password: _passphrase,
            confirmation: _confirmation,
            label: _replace ? 'New passphrase' : 'Passphrase',
            minLength: 1,
            enabled: !_busy,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_replace ? 'Replace' : 'Save'),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_error case final e?) ...[
            const SizedBox(height: 16),
            Text(
              e,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
  );
}
