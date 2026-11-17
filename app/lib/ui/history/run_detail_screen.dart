import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/unlock_core.dart';

import '../../data/run_repository.dart';
import '../../run/run_providers.dart';
import '../run/run_widgets.dart';

class RunDetailScreen extends ConsumerWidget {
  const RunDetailScreen({super.key, required this.runId});

  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(runRecordProvider(runId));
    final events = ref.watch(runEventsProvider(runId)).value ?? const [];
    final active = ref.watch(
      runControllerProvider.select(
        (r) => r != null && r.running && r.id == runId,
      ),
    );
    return switch (run) {
      AsyncData(value: final r?) => Scaffold(
        appBar: AppBar(title: Text(r.title)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              [
                'Started ${dateTimeLabel(r.startedAt)}',
                if (r.finishedAt case final f?) 'finished ${clockTime(f)}',
              ].join(', '),
            ),
            Text(runOutcome(r, active: active)),
            for (final h in r.hosts)
              _HostSection(
                host: h,
                events: [
                  for (final e in events)
                    if (e.hostId == h.hostId) e,
                ],
              ),
          ],
        ),
      ),
      AsyncData() => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This run was deleted.')),
      ),
      AsyncError() => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Could not load the data.')),
      ),
      _ => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _HostSection extends StatelessWidget {
  const _HostSection({required this.host, required this.events});

  final RunHostRecord host;
  final List<HostEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = host.finalState;
    return Card(
      key: ValueKey('history-host-${host.hostId}'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(host.hostName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            switch ((result, host.skipReason)) {
              (final FinalState s, _) => FinalStateLabel(s),
              (_, final String reason) => Text(
                'Skipped: $reason',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              _ => const Text('No result'),
            },
            if (events.isNotEmpty) ...[
              const SizedBox(height: 8),
              EventLog(events, maxHeight: 320),
            ],
          ],
        ),
      ),
    );
  }
}
