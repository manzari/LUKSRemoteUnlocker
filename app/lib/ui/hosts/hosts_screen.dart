import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/unlock_core.dart';

import '../../providers.dart';
import '../../run/run_controller.dart';
import '../../run/run_providers.dart';
import '../common/async_body.dart';
import '../common/messages.dart';
import '../help/setup_help_screen.dart';
import '../run/run_screen.dart';
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
    final running = ref.watch(
      runControllerProvider.select((r) => r?.running ?? false),
    );
    final groups = <String?, List<Host>>{};
    for (final h in hosts) {
      (groups[h.group] ??= []).add(h);
    }
    final theme = Theme.of(context);
    final enabled = hosts.where((h) => h.enabled).length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        if (running) const _ActiveRunBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${hosts.length} ${hosts.length == 1 ? 'host' : 'hosts'}, '
                  '$enabled enabled',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              FilledButton.tonalIcon(
                key: const ValueKey('unlock-all'),
                onPressed: running || enabled == 0
                    ? null
                    : () => startRun(context, ref, const AllHosts()),
                icon: const Icon(Icons.lock_open),
                label: const Text('Unlock all'),
              ),
            ],
          ),
        ),
        for (final MapEntry(key: group, value: members) in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group ?? 'No group',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                if (group != null)
                  TextButton.icon(
                    key: ValueKey('unlock-group-$group'),
                    onPressed: running || !members.any((h) => h.enabled)
                        ? null
                        : () => startRun(context, ref, HostGroup(group)),
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: const Text('Unlock group'),
                  ),
              ],
            ),
          ),
          for (final host in members)
            _HostTile(
              host,
              onUnlock: running
                  ? null
                  : () => startRun(context, ref, OneHost(host.id)),
            ),
        ],
      ],
    );
  }
}

class _ActiveRunBanner extends ConsumerWidget {
  const _ActiveRunBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(runControllerProvider);
    if (run == null) return const SizedBox.shrink();
    final waiting = run.hostKeyRequests.length;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.sync),
        title: Text('Unlocking: ${run.title}'),
        subtitle: waiting == 0
            ? null
            : Text(
                waiting == 1
                    ? 'A host key needs your confirmation'
                    : '$waiting host keys need your confirmation',
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openRunScreen(context),
      ),
    );
  }
}

class _HostTile extends ConsumerWidget {
  const _HostTile(this.host, {required this.onUnlock});

  final Host host;

  /// Null while a run is going on.
  final VoidCallback? onUnlock;

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
          IconButton(
            tooltip: 'Unlock ${host.name}',
            onPressed: onUnlock,
            icon: const Icon(Icons.lock_open),
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
