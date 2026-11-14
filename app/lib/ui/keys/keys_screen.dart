import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../providers.dart';
import '../common/async_body.dart';
import '../vault/unlock.dart';
import 'key_detail_screen.dart';
import 'key_generate_screen.dart';
import 'key_import_screen.dart';

class KeysScreen extends ConsumerWidget {
  const KeysScreen({super.key});

  Future<void> _add(BuildContext context) async {
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
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => choice == 'generate'
            ? const KeyGenerateScreen()
            : const KeyImportScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(keysProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH keys'),
        actions: const [VaultLockButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('Add key'),
      ),
      body: AsyncBody(
        value: keys,
        empty:
            'No SSH keys yet. Generate one here, or import the key your '
            'servers already accept.',
        builder: (keys) => ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final k in keys)
              ListTile(
                leading: const Icon(Icons.key),
                title: Text(k.label),
                subtitle: Text(
                  '${k.typeLabel} · ${k.fingerprint}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => KeyDetailScreen(keyId: k.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
