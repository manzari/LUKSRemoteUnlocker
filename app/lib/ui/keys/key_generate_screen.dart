import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/keys.dart';

import '../../providers.dart';
import '../common/messages.dart';
import '../vault/unlock.dart';
import 'key_detail_screen.dart';

class KeyGenerateScreen extends ConsumerStatefulWidget {
  const KeyGenerateScreen({super.key});

  @override
  ConsumerState<KeyGenerateScreen> createState() => _KeyGenerateScreenState();
}

class _KeyGenerateScreenState extends ConsumerState<KeyGenerateScreen> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _comment = TextEditingController(text: 'luks-remote-unlocker');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!_form.currentState!.validate()) return;
    final vault = await requireVault(
      context,
      ref,
      reason: 'The new key is stored encrypted in the vault.',
    );
    if (vault == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final key = const SshKeyService().generateEd25519(comment: _comment.text);
    try {
      final stored = await ref
          .read(keyRepositoryProvider)
          .add(vault, key, label: _label.text);
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => KeyDetailScreen(keyId: stored.id),
        ),
      );
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      key.privateKeyPem.fillRange(0, key.privateKeyPem.length, 0);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Generate key')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Creates a new Ed25519 key. Only the public key can be shown, '
            'copied or shared; add it to the server\'s authorized_keys.',
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('key-label'),
            controller: _label,
            decoration: const InputDecoration(labelText: 'Label'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a label' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('key-comment'),
            controller: _comment,
            decoration: const InputDecoration(
              labelText: 'Comment',
              helperText: 'Appended to the public key line',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _generate,
            child: const Text('Generate'),
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
