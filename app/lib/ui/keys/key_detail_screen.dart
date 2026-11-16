import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/key_repository.dart';
import '../../providers.dart';
import '../common/label_dialog.dart';
import '../common/messages.dart';
import '../vault/unlock.dart';

/// Public parts only; the private key is never shown or exported.
class KeyDetailScreen extends ConsumerStatefulWidget {
  const KeyDetailScreen({super.key, required this.keyId});

  final String keyId;

  @override
  ConsumerState<KeyDetailScreen> createState() => _KeyDetailScreenState();
}

class _KeyDetailScreenState extends ConsumerState<KeyDetailScreen> {
  bool _showQr = false;

  Future<void> _rename(StoredKey key) async {
    final others = [
      for (final k in ref.read(keysProvider).value ?? const <StoredKey>[])
        if (k.id != key.id) k.label,
    ];
    final label = await askLabel(
      context,
      title: 'Rename key',
      initial: key.label,
      taken: others,
    );
    if (label == null) return;
    try {
      await ref.read(keyRepositoryProvider).rename(key.id, label);
    } on Object catch (e) {
      if (mounted) showMessage(context, describeError(e));
    }
  }

  Future<void> _copy(StoredKey key) async {
    await Clipboard.setData(ClipboardData(text: key.publicLine));
    if (mounted) showMessage(context, 'Public key copied');
  }

  Future<void> _share(StoredKey key) async {
    try {
      await ref
          .read(platformServicesProvider)
          .sharePublicKey(
            key.publicLine,
            subject: 'SSH public key ${key.label}',
          );
    } on Object catch (e) {
      if (mounted) showMessage(context, describeError(e));
    }
  }

  Future<void> _delete(StoredKey key) async {
    final users = await ref.read(hostRepositoryProvider).namesUsingKey(key.id);
    if (!mounted) return;
    if (users.isNotEmpty) {
      await inform(
        context,
        title: 'Key in use',
        message:
            '"${key.label}" is used by ${users.join(', ')}. Assign another '
            'key to ${users.length == 1 ? 'that host' : 'those hosts'} first.',
      );
      return;
    }
    final ok = await confirm(
      context,
      title: 'Delete key?',
      message:
          'The private key of "${key.label}" is deleted from the vault. '
          'Remove the public key from the servers\' authorized_keys too.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final vault = await requireVault(context, ref);
    if (vault == null || !mounted) return;
    try {
      await ref.read(keyRepositoryProvider).delete(vault, key.id);
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) showMessage(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = ref.watch(keyProvider(widget.keyId)).value;
    final hosts = ref.watch(hostsProvider).value ?? const [];
    if (key == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final users = [
      for (final h in hosts)
        if (h.keyId == key.id) h.name,
    ];
    final mono = Theme.of(context).textTheme.bodySmall
        ?.copyWith(fontFamily: 'monospace');
    return Scaffold(
      appBar: AppBar(
        title: Text(key.label),
        actions: [
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _rename(key),
          ),
          IconButton(
            tooltip: 'Delete key',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(key),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Type'),
            subtitle: Text(key.typeLabel),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fingerprint'),
            subtitle: SelectableText(key.fingerprint, style: mono),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Public key (authorized_keys line)'),
            subtitle: SelectableText(key.publicLine, style: mono),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _copy(key),
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _share(key),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => setState(() => _showQr = !_showQr),
                icon: const Icon(Icons.qr_code),
                label: Text(_showQr ? 'Hide QR code' : 'QR code'),
              ),
            ],
          ),
          if (_showQr)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: QrImageView(
                  key: const ValueKey('public-key-qr'),
                  data: key.publicLine,
                  size: 280,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Used by'),
            subtitle: Text(users.isEmpty ? 'No hosts' : users.join(', ')),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Added'),
            subtitle: Text(_date(key.createdAt)),
          ),
        ],
      ),
    );
  }
}

String _date(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}
