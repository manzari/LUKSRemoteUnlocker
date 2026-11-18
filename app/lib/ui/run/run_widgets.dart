import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/unlock_core.dart';

import '../../data/run_repository.dart';

String phaseLabel(HostPhase? phase) => switch (phase) {
  null => 'Starting',
  HostPhase.checkingIfUp => 'Checking if up',
  HostPhase.pinging => 'Pinging',
  HostPhase.waitingForPreboot => 'Waiting for pre-boot',
  HostPhase.verifyingHostKey => 'Verifying host key',
  HostPhase.authenticating => 'Logging in',
  HostPhase.unlocking => 'Unlocking',
  HostPhase.waitingForBoot => 'Waiting for boot',
  HostPhase.finished => 'Finished',
};

String _two(int n) => n.toString().padLeft(2, '0');

String clockTime(DateTime t) {
  final l = t.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}:${_two(l.second)}';
}

String dateTimeLabel(DateTime t) {
  final l = t.toLocal();
  return '${l.year}-${_two(l.month)}-${_two(l.day)} '
      '${_two(l.hour)}:${_two(l.minute)}';
}

Color stateColor(ColorScheme scheme, FinalState? state) => switch (state) {
  null => scheme.onSurfaceVariant,
  FinalState.unlocked || FinalState.alreadyUp => Colors.green.shade700,
  FinalState.unlockedBootNotConfirmed => Colors.orange.shade800,
  FinalState.cancelled => scheme.onSurfaceVariant,
  _ => scheme.error,
};

IconData stateIcon(FinalState state) => switch (state) {
  FinalState.unlocked || FinalState.alreadyUp => Icons.check_circle,
  FinalState.unlockedBootNotConfirmed => Icons.help,
  FinalState.cancelled => Icons.cancel_outlined,
  FinalState.hostKeyMismatch => Icons.gpp_bad,
  _ => Icons.error,
};

/// A final state as an icon and its label.
class FinalStateLabel extends StatelessWidget {
  const FinalStateLabel(this.state, {super.key});

  final FinalState state;

  @override
  Widget build(BuildContext context) {
    final color = stateColor(Theme.of(context).colorScheme, state);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(stateIcon(state), size: 18, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            state.label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Sanitized events, newest at the bottom and kept in view.
class EventLog extends StatelessWidget {
  const EventLog(this.events, {super.key, this.maxHeight = 200});

  final List<HostEvent> events;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        reverse: true,
        shrinkWrap: true,
        padding: const EdgeInsets.all(8),
        itemCount: events.length,
        itemBuilder: (context, i) {
          final e = events[events.length - 1 - i];
          return Text('${clockTime(e.time)}  ${e.message}', style: style);
        },
      ),
    );
  }
}

/// "Unlocked 2, Wrong passphrase 1", counted per final state.
String runOutcome(RunRecord run, {required bool active}) {
  final counts = <String, int>{};
  for (final h in run.hosts) {
    final label = switch ((h.finalState, h.skipReason)) {
      (final FinalState s, _) => s.label,
      (_, final String _) => 'Skipped',
      _ => active ? 'Running' : 'No result',
    };
    counts[label] = (counts[label] ?? 0) + 1;
  }
  final parts = [for (final e in counts.entries) '${e.key} ${e.value}'];
  if (!active && run.finishedAt == null) parts.add('interrupted');
  return parts.isEmpty ? 'No hosts' : parts.join(', ');
}
