import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/unlock_core.dart';

import '../../data/run_repository.dart';
import '../../run/run_providers.dart';
import '../common/async_body.dart';
import '../common/messages.dart';
import '../run/run_widgets.dart';
import 'run_detail_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: 'Clear history?',
      message: 'All past runs and their logs are deleted.',
      action: 'Clear',
      destructive: true,
    );
    if (!ok) return;
    final run = ref.read(runControllerProvider);
    try {
      await ref
          .read(runRepositoryProvider)
          .clear(except: run != null && run.running ? run.id : null);
    } on Object catch (e) {
      if (context.mounted) showMessage(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(runHistoryProvider);
    final active = ref.watch(
      runControllerProvider.select((r) => r != null && r.running ? r.id : null),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Run history'),
        actions: [
          IconButton(
            tooltip: 'Clear history',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: (runs.value?.isEmpty ?? true)
                ? null
                : () => _clear(context, ref),
          ),
        ],
      ),
      body: AsyncBody(
        value: runs,
        empty: 'No runs yet. Unlock servers from the Hosts tab.',
        builder: (runs) => ListView(
          children: [
            for (final r in runs) _RunTile(run: r, active: r.id == active),
          ],
        ),
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  const _RunTile({required this.run, required this.active});

  final RunRecord run;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ok =
        run.hosts.isNotEmpty &&
        run.hosts.every((h) => h.finalState?.isSuccess ?? false);
    final Widget leading;
    if (active) {
      leading = const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (ok) {
      leading = Icon(
        Icons.check_circle,
        color: stateColor(scheme, FinalState.unlocked),
      );
    } else {
      leading = Icon(Icons.error_outline, color: scheme.error);
    }
    return ListTile(
      key: ValueKey('run-${run.id}'),
      leading: leading,
      title: Text(run.title),
      subtitle: Text(
        '${dateTimeLabel(run.startedAt)} · ${runOutcome(run, active: active)}',
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => RunDetailScreen(runId: run.id)),
      ),
    );
  }
}
