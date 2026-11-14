import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/keys.dart';

import '../../data/errors.dart';
import '../../providers.dart';
import '../../services/key_import.dart';
import '../common/messages.dart';
import '../common/password_fields.dart';
import '../vault/unlock.dart';
import 'key_detail_screen.dart';

class KeyImportScreen extends ConsumerStatefulWidget {
  const KeyImportScreen({super.key});

  @override
  ConsumerState<KeyImportScreen> createState() => _KeyImportScreenState();
}

class _KeyImportScreenState extends ConsumerState<KeyImportScreen> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _pasted = TextEditingController();
  final _passphrase = TextEditingController();
  Uint8List? _file;
  String? _fileName;
  bool _busy = false;
  String? _keyError;
  String? _passphraseError;

  @override
  void dispose() {
    _wipeFile();
    _label.dispose();
    _pasted
      ..clear()
      ..dispose();
    _passphrase
      ..clear()
      ..dispose();
    super.dispose();
  }

  void _wipeFile() {
    final f = _file;
    f?.fillRange(0, f.length, 0);
    _file = null;
    _fileName = null;
  }

  Future<void> _pick() async {
    try {
      final picked = await ref.read(platformServicesProvider).pickKeyFile();
      if (picked == null || !mounted) return;
      setState(() {
        _wipeFile();
        _file = picked.bytes;
        _fileName = picked.name;
        _keyError = null;
        if (_label.text.trim().isEmpty) _label.text = picked.name;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _keyError = describeError(e));
    }
  }

  Future<void> _import() async {
    setState(() {
      _keyError = null;
      _passphraseError = null;
    });
    if (!_form.currentState!.validate()) return;
    final source = _file ?? utf8.encode(_pasted.text);
    if (source.isEmpty) {
      setState(() => _keyError = 'Choose a key file or paste a key.');
      return;
    }
    final passphrase = _passphrase.text.isEmpty ? null : textBytes(_passphrase);
    setState(() => _busy = true);
    SshKey? key;
    try {
      key = await ref.read(keyImporterProvider)(source, passphrase);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          final text = describeKeyError(e);
          if (e is KeyPassphraseRequiredException ||
              e is WrongKeyPassphraseException) {
            _passphraseError = text;
          } else {
            _keyError = text;
          }
        });
      }
    } finally {
      passphrase?.fillRange(0, passphrase.length, 0);
      if (!identical(source, _file)) source.fillRange(0, source.length, 0);
      if (mounted) setState(() => _busy = false);
    }
    if (key == null || !mounted) return;
    try {
      await _store(key);
    } finally {
      key.privateKeyPem.fillRange(0, key.privateKeyPem.length, 0);
    }
  }

  Future<void> _store(SshKey key) async {
    final vault = await requireVault(
      context,
      ref,
      reason: 'The imported key is stored encrypted in the vault.',
    );
    if (vault == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final stored = await ref
          .read(keyRepositoryProvider)
          .add(vault, key, label: _label.text);
      _wipeFile();
      _pasted.clear();
      _passphrase.clear();
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => KeyDetailScreen(keyId: stored.id),
        ),
      );
    } on DataException catch (e) {
      if (mounted) setState(() => _keyError = e.message);
    } on Object catch (e) {
      if (mounted) setState(() => _keyError = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import key')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Import an OpenSSH private key (Ed25519, RSA or ECDSA). It is '
              'decrypted once and stored in the vault; it is never shown or '
              'exported again.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('key-label'),
              controller: _label,
              decoration: const InputDecoration(labelText: 'Label'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a label' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Choose file'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _fileName == null ? 'or paste below' : 'File: $_fileName',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_fileName != null)
                  IconButton(
                    tooltip: 'Forget file',
                    onPressed: () => setState(_wipeFile),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('key-paste'),
              controller: _pasted,
              enabled: _fileName == null && !_busy,
              minLines: 4,
              maxLines: 8,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                labelText: 'Private key',
                hintText: '-----BEGIN OPENSSH PRIVATE KEY-----',
                alignLabelWithHint: true,
                errorText: _keyError,
                errorMaxLines: 4,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('key-passphrase'),
              controller: _passphrase,
              enabled: !_busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Key passphrase (if the key has one)',
                errorText: _passphraseError,
                errorMaxLines: 2,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _import,
              child: const Text('Import'),
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
