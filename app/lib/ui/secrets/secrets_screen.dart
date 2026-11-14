import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../providers.dart';
import '../common/async_body.dart';
import '../vault/unlock.dart';
import 'secret_detail_screen.dart';
import 'secret_form_screen.dart';

class SecretsScreen extends ConsumerWidget {
  const SecretsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secrets = ref.watch(secretsProvider);
    final hosts = ref.watch(hostsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disk passphrases'),
        actions: const [VaultLockButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const SecretFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add passphrase'),
      ),
      body: AsyncBody(
        value: secrets,
        empty:
            'No passphrases yet. Add the LUKS passphrase your servers ask '
            'for at boot.',
        builder: (secrets) => ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final s in secrets)
              ListTile(
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SecretDetailScreen(secretId: s.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
