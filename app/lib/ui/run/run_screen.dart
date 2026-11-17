import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/unlock_core.dart';

import '../../run/run_controller.dart';
import '../../run/run_providers.dart';
import '../common/messages.dart';
import '../vault/unlock.dart';
import 'run_widgets.dart';

/// Starts a run with one vault prompt and opens the run screen.
Future<void> startRun(
  BuildContext context,
  WidgetRef ref,
  RunSelection selection,
) async {
  final RunStart result;
  try {
    result = await ref
        .read(runControllerProvider.notifier)
        .start(
          selection,
          unlockVault: () async {
            if (!context.mounted) return null;
            return requireVault(
              context,
              ref,
              fresh: true,
              reason:
                  'Unlocking servers needs the vault. One unlock covers the '
                  'whole run.',
            );
          },
        );
  } on Object catch (e) {
    if (context.mounted) showMessage(context, describeError(e));
    return;
  }
  if (!context.mounted) return;
  switch (result) {
    case RunStart.started || RunStart.busy:
      await openRunScreen(context);
    case RunStart.noHosts:
      showMessage(context, 'No enabled host to unlock.');
    case RunStart.vaultLocked:
      break;
  }
}

Future<void> openRunScreen(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => const RunScreen()),
);

class RunScreen extends ConsumerWidget {
  const RunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(runControllerProvider);
    if (run == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Unlock')),
        body: const Center(child: Text('No run yet.')),
      );
    }
    final controller = ref.read(runControllerProvider.notifier);
    final request = run.hostKeyRequests.firstOrNull;
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(run.title),
            actions: [
              if (run.running)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    key: const ValueKey('cancel-run'),
                    onPressed: run.cancelling ? null : controller.cancel,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(run.cancelling ? 'Cancelling' : 'Cancel run'),
                  ),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _Summary(run),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = (constraints.maxWidth / 440).floor().clamp(
                    1,
                    3,
                  );
                  final width =
                      (constraints.maxWidth - 12 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final h in run.hosts)
                        SizedBox(
                          width: width,
                          child: _HostCard(
                            host: h,
                            running: run.running,
                            awaitingKey: run.hostKeyRequests.any(
                              (r) => r.hostId == h.hostId,
                            ),
                            onCancel: () => controller.cancelHost(h.hostId),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        if (request != null) ...[
          const ModalBarrier(dismissible: false, color: Colors.black54),
          Positioned.fill(
            child: HostKeyDialog(
              key: ValueKey('host-key-request-${request.id}'),
              request: request,
              waiting: run.hostKeyRequests.length - 1,
              onAnswer: (accept) =>
                  controller.answerHostKey(request.id, accept: accept),
            ),
          ),
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.run);

  final RunState run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = run.hosts.where((h) => !h.skipped).length;
    final done = run.hosts.where((h) => !h.skipped && h.result != null).length;
    final ok = run.hosts.where((h) => h.result?.isSuccess ?? false).length;
    final finished = run.finishedAt;
    final text = finished == null
        ? 'Started ${clockTime(run.startedAt)} · $done of $active finished'
        : 'Finished ${clockTime(finished)} · $ok of ${run.hosts.length} '
              'unlocked or already up';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, key: const ValueKey('run-summary')),
        if (run.notice case final n? when run.running)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              n,
              key: const ValueKey('run-notice'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (run.warning case final w?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(w, style: TextStyle(color: theme.colorScheme.error)),
          ),
      ],
    );
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard({
    required this.host,
    required this.running,
    required this.awaitingKey,
    required this.onCancel,
  });

  final HostRunView host;
  final bool running;
  final bool awaitingKey;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = host.result;
    final busy = running && !host.done;
    return Card(
      key: ValueKey('run-host-${host.hostId}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(host.name, style: theme.textTheme.titleMedium),
                ),
                if (busy)
                  IconButton(
                    tooltip: 'Cancel ${host.name}',
                    onPressed: onCancel,
                    icon: const Icon(Icons.close),
                  )
                else
                  const SizedBox(height: 48),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: switch ((result, host.skipReason)) {
                (final FinalState r, _) => FinalStateLabel(r),
                (_, final String reason) => Text(
                  'Skipped: $reason',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                _ => Row(
                  children: [
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        awaitingKey
                            ? 'Waiting for your confirmation'
                            : phaseLabel(host.phase),
                      ),
                    ),
                  ],
                ),
              },
            ),
            if (result == FinalState.hostKeyMismatch)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Text(
                  'The passphrase was not sent. If the server key changed on '
                  'purpose, pin the new key in the host form.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (host.log.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: EventLog(host.log),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Confirms an unpinned pre-boot key; there is no way to accept a mismatch.
class HostKeyDialog extends StatelessWidget {
  const HostKeyDialog({
    super.key,
    required this.request,
    required this.onAnswer,
    this.waiting = 0,
  });

  final HostKeyRequest request;
  final ValueChanged<bool> onAnswer;

  /// Other hosts waiting for a confirmation after this one.
  final int waiting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodyLarge?.copyWith(fontFamily: 'monospace');
    return AlertDialog(
      title: Text('New host key for ${request.hostName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This pre-boot server presents a host key that is not pinned '
              'yet. Compare it with the fingerprint printed on the server '
              '(see the server setup help). The passphrase is sent only '
              'after you accept, and the key is pinned for later runs.',
            ),
            const SizedBox(height: 16),
            Text('Key type', style: theme.textTheme.labelMedium),
            Text(
              request.key.type ?? 'unknown',
              key: const ValueKey('host-key-type'),
              style: mono,
            ),
            const SizedBox(height: 8),
            Text('SHA-256 fingerprint', style: theme.textTheme.labelMedium),
            Text(
              request.key.fingerprint,
              key: const ValueKey('host-key-fingerprint'),
              style: mono,
            ),
            if (waiting > 0) ...[
              const SizedBox(height: 16),
              Text(
                waiting == 1
                    ? '1 more host is waiting for a confirmation.'
                    : '$waiting more hosts are waiting for a confirmation.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => onAnswer(false),
          child: const Text('Decline'),
        ),
        FilledButton(
          onPressed: () => onAnswer(true),
          child: const Text('Accept and pin'),
        ),
      ],
    );
  }
}
