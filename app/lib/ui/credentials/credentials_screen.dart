import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../providers.dart';
import '../keys/key_detail_screen.dart';
import '../keys/key_generate_screen.dart';
import '../keys/key_import_screen.dart';
import '../secrets/secret_detail_screen.dart';
import '../secrets/secret_form_screen.dart';
import '../vault/unlock.dart';

class CredentialsScreen extends ConsumerWidget {
  const CredentialsScreen({super.key});

  Future<void> _addKey(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Generate Ed25519 key'),
              onTap: () => Navigator.pop(context, 'generate'),
            ),
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: const Text('Import existing key'),
              subtitle: const Text('OpenSSH, PEM RSA or EC private key'),
              onTap: () => Navigator.pop(context, 'import'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    await _open(
      context,
      choice == 'generate' ? const KeyGenerateScreen() : const KeyImportScreen(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(keysProvider);
    final secrets = ref.watch(secretsProvider);
    final hosts = ref.watch(hostsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credentials'),
        actions: const [VaultLockButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _SectionHeader(
            title: 'SSH keys',
            addLabel: 'Add key',
            onAdd: () => _addKey(context),
          ),
          ..._section(
            keys,
            empty:
                'No SSH keys yet. Generate one here, or import the key your '
                'servers already accept.',
            tile: (k) => ListTile(
              leading: const Icon(Icons.key),
              title: Text(k.label),
              subtitle: Text(
                '${k.typeLabel} · ${k.fingerprint}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _open(context, KeyDetailScreen(keyId: k.id)),
            ),
          ),
          const Divider(height: 32),
          _SectionHeader(
            title: 'Disk passphrases',
            addLabel: 'Add passphrase',
            onAdd: () => _open(context, const SecretFormScreen()),
          ),
          ..._section(
            secrets,
            empty:
                'No passphrases yet. Add the LUKS passphrase your servers ask '
                'for at boot.',
            tile: (s) => ListTile(
              leading: const Icon(Icons.password),
              title: Text(s.label),
              subtitle: Text(switch (hosts
                  .where(
                    (h) =>
                        h.secretId == s.id ||
                        h.diskOverrides.containsValue(s.id),
                  )
                  .length) {
                0 => 'Not used',
                1 => 'Used by 1 host',
                final n => 'Used by $n hosts',
              }),
              onTap: () => _open(context, SecretDetailScreen(secretId: s.id)),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _open(BuildContext context, Widget screen) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => screen),
);

List<Widget> _section<T>(
  AsyncValue<List<T>> value, {
  required String empty,
  required Widget Function(T item) tile,
}) => switch (value) {
  AsyncData(value: final items) when items.isEmpty => [_Note(empty)],
  AsyncData(value: final items) => [for (final item in items) tile(item)],
  AsyncError() => const [_Note('Could not load the data.')],
  _ => const [
    Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    ),
  ],
};

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.addLabel,
    required this.onAdd,
  });

  final String title;
  final String addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text(addLabel),
        ),
      ],
    ),
  );
}
