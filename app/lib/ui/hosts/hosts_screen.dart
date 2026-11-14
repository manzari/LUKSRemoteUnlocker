import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/unlock_core.dart';

import '../../providers.dart';
import '../common/async_body.dart';
import '../common/messages.dart';
import '../help/setup_help_screen.dart';
import '../vault/unlock.dart';
import 'host_form_screen.dart';

class HostsScreen extends ConsumerWidget {
  const HostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hosts = ref.watch(hostsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hosts'),
        actions: [
          IconButton(
            tooltip: 'Server setup help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const SetupHelpScreen()),
            ),
          ),
          const VaultLockButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const HostFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add host'),
      ),
      body: AsyncBody(
        value: hosts,
        empty: 'No hosts yet. Add the servers you want to unlock.',
        builder: _HostList.new,
      ),
    );
  }
}

class _HostList extends ConsumerWidget {
  const _HostList(this.hosts);

  final List<Host> hosts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = <String?, List<Host>>{};
    for (final h in hosts) {
      (groups[h.group] ??= []).add(h);
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final MapEntry(key: group, value: members) in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              group ?? 'No group',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          for (final host in members) _HostTile(host),
        ],
      ],
    );
  }
}

class _HostTile extends ConsumerWidget {
  const _HostTile(this.host);

  final Host host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = [
      host.preboot.first.toString(),
      if (host.keyId == null) 'no SSH key',
      if (host.secretId == null) 'no passphrase',
      if (host.prebootKey == null) 'host key not pinned',
    ];
    return ListTile(
      key: ValueKey('host-${host.id}'),
      title: Text(host.name),
      subtitle: Text(notes.join(' · ')),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => HostFormScreen(host: host)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const IconButton(
            tooltip: 'Unlock (available in a later version)',
            onPressed: null,
            icon: Icon(Icons.lock_open),
          ),
          Switch(
            value: host.enabled,
            onChanged: (v) async {
              try {
                await ref.read(hostRepositoryProvider).setEnabled(host.id, v);
              } on Object catch (e) {
                if (context.mounted) showMessage(context, describeError(e));
              }
            },
          ),
        ],
      ),
    );
  }
}
