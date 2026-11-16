import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/secret_repository.dart';
import '../../providers.dart';
import '../common/label_dialog.dart';
import '../common/messages.dart';
import '../vault/unlock.dart';
import 'secret_form_screen.dart';

const revealDuration = Duration(seconds: 30);

class SecretDetailScreen extends ConsumerStatefulWidget {
  const SecretDetailScreen({super.key, required this.secretId});

  final String secretId;

  @override
  ConsumerState<SecretDetailScreen> createState() => _SecretDetailScreenState();
}

class _SecretDetailScreenState extends ConsumerState<SecretDetailScreen> {
  Uint8List? _revealed;
  Timer? _ticker;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _hide(rebuild: false);
    super.dispose();
  }

  void _hide({bool rebuild = true}) {
    _ticker?.cancel();
    _ticker = null;
    final r = _revealed;
    r?.fillRange(0, r.length, 0);
    _revealed = null;
    if (rebuild && mounted) setState(() {});
  }

  Future<void> _reveal(StoredSecret secret) async {
    final vault = await requireVault(
      context,
      ref,
      fresh: true,
      reason: 'Showing a passphrase needs a fresh unlock.',
    );
    if (vault == null || !mounted) return;
    try {
      final bytes = await ref
          .read(secretRepositoryProvider)
          .reveal(vault, secret.id);
      if (!mounted) {
        bytes.fillRange(0, bytes.length, 0);
        return;
      }
      _hide(rebuild: false);
      setState(() {
        _revealed = bytes;
        _secondsLeft = revealDuration.inSeconds;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (--_secondsLeft <= 0) {
          _hide();
        } else {
          setState(() {});
        }
      });
    } on Object catch (e) {
      if (mounted) showMessage(context, describeError(e));
    }
  }

  Future<void> _rename(StoredSecret secret) async {
    final others = [
      for (final s in ref.read(secretsProvider).value ?? const <StoredSecret>[])
        if (s.id != secret.id) s.label,
    ];
    final label = await askLabel(
      context,
      title: 'Rename passphrase',
      initial: secret.label,
      taken: others,
    );
    if (label == null) return;
    try {
      await ref.read(secretRepositoryProvider).rename(secret.id, label);
    } on Object catch (e) {
      if (mounted) showMessage(context, describeError(e));
    }
  }

  Future<void> _delete(StoredSecret secret) async {
    final users = await ref
        .read(hostRepositoryProvider)
        .namesUsingSecret(secret.id);
    if (!mounted) return;
    if (users.isNotEmpty) {
      await inform(
        context,
        title: 'Passphrase in use',
        message:
            '"${secret.label}" is used by ${users.join(', ')}. Assign another '
            'passphrase to ${users.length == 1 ? 'that host' : 'those hosts'} '
            'first.',
      );
      return;
    }
    final ok = await confirm(
      context,
      title: 'Delete passphrase?',
      message: '"${secret.label}" is deleted from the vault.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final vault = await requireVault(context, ref);
    if (vault == null || !mounted) return;
    try {
      _hide();
      await ref.read(secretRepositoryProvider).delete(vault, secret.id);
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) showMessage(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(vaultControllerProvider.select((s) => s.isUnlocked), (
      _,
      unlocked,
    ) {
      if (!unlocked) _hide();
    });
    final secret = ref.watch(secretProvider(widget.secretId)).value;
    final hosts = ref.watch(hostsProvider).value ?? const [];
    if (secret == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final users = [
      for (final h in hosts)
        if (h.secretId == secret.id)
          h.name
        else if (h.diskOverrides.containsValue(secret.id))
          '${h.name} (disk)',
    ];
    final theme = Theme.of(context);
    final revealed = _revealed;
    return Scaffold(
      appBar: AppBar(
        title: Text(secret.label),
        actions: [
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _rename(secret),
          ),
          IconButton(
            tooltip: 'Delete passphrase',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(secret),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: revealed == null
                  ? const Text('••••••••••••')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          utf8.decode(revealed, allowMalformed: true),
                          key: const ValueKey('revealed-passphrase'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hidden in $_secondsLeft s',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (revealed == null)
                FilledButton.tonalIcon(
                  onPressed: () => _reveal(secret),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Reveal'),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: _hide,
                  icon: const Icon(Icons.visibility_off_outlined),
                  label: const Text('Hide'),
                ),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SecretFormScreen(replacing: secret),
                  ),
                ),
                icon: const Icon(Icons.edit),
                label: const Text('Replace'),
              ),
            ],
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Used by'),
            subtitle: Text(users.isEmpty ? 'No hosts' : users.join(', ')),
          ),
        ],
      ),
    );
  }
}
