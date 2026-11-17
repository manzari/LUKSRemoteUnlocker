import 'package:material_ui/material_ui.dart';

import '../../services/config_transfer.dart';

/// Whether to trust the file's pinned host keys, or null when cancelled.
Future<bool?> showImportSummary(BuildContext context, ImportPlan plan) =>
    showDialog<bool>(
      context: context,
      builder: (_) => ImportSummaryDialog(plan: plan),
    );

String _two(int n) => n.toString().padLeft(2, '0');

String _date(DateTime d) {
  final l = d.toLocal();
  return '${l.year}-${_two(l.month)}-${_two(l.day)} ${_two(l.hour)}:${_two(l.minute)}';
}

String _users(List<String> names) => 'used by ${names.join(', ')}';

String _keyLine(Relink k) =>
    '"${k.fileLabel}" to your key "${k.localLabel}" (${k.fingerprint}), '
    '${_users(k.usedBy)}';

String _passphraseLine(Relink p) =>
    '"${p.fileLabel}" to your passphrase "${p.localLabel}", '
    '${_users(p.usedBy)}';

class ImportSummaryDialog extends StatefulWidget {
  const ImportSummaryDialog({super.key, required this.plan});

  final ImportPlan plan;

  @override
  State<ImportSummaryDialog> createState() => _ImportSummaryDialogState();
}

class _ImportSummaryDialogState extends State<ImportSummaryDialog> {
  bool _trustPins = false;

  ImportPlan get _plan => widget.plan;

  List<String> get _hostLines => [
    for (final h in _plan.hosts)
      [
        h.name,
        h.preboot.first.toString(),
        if (h.group case final g?) 'group $g',
        if (h.prebootKey != null) 'pinned key',
      ].join(' · '),
  ];

  List<String> get _profileLines => [
    for (final p in _plan.newProfiles)
      if (_plan.renamedProfiles.where((r) => r.to == p.name).firstOrNull
          case final r?)
        'Add "${p.name}" (renamed from "${r.from}", the name is taken)'
      else
        'Add "${p.name}"',
    for (final name in _plan.existingProfiles) '"$name" is already here',
  ];

  List<String> get _unlinkedLines => [
    for (final u in _plan.unlinked)
      switch (u.kind) {
        ReferenceKind.sshKey =>
          'SSH key "${u.label}" (${u.fingerprint}), ${_users(u.usedBy)}',
        ReferenceKind.passphrase =>
          'Passphrase "${u.label}", ${_users(u.usedBy)}',
        ReferenceKind.profile =>
          'Unlock profile "${u.label}" is unknown here, so the built-in '
              'Debian/Ubuntu profile is used; ${_users(u.usedBy)}',
      },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pinned = _plan.pinned;
    return AlertDialog(
      title: Text(
        _plan.isEmpty ? 'Nothing to import' : 'Import configuration?',
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Exported ${_date(_plan.exportedAt)}. Nothing is written '
                'until you tap Import. The file holds no keys or passphrases.',
              ),
              _Section(
                'Hosts to add (${_plan.hosts.length})',
                _hostLines,
                empty: 'None',
              ),
              if (_plan.clashes.isNotEmpty)
                _Section(
                  'Skipped, name already in use (${_plan.clashes.length})',
                  _plan.clashes,
                  note:
                      'A host with this name exists here. It stays unchanged '
                      'and the host from the file is not imported. Rename or '
                      'delete the existing host and import again to add it.',
                ),
              if (_profileLines.isNotEmpty)
                _Section('Unlock profiles', _profileLines),
              if (_plan.keys.isNotEmpty)
                _Section('SSH keys relinked by fingerprint', [
                  for (final k in _plan.keys) _keyLine(k),
                ]),
              if (_plan.passphrases.isNotEmpty)
                _Section('Passphrases relinked by label', [
                  for (final p in _plan.passphrases) _passphraseLine(p),
                ]),
              if (_plan.unlinked.isNotEmpty)
                _Section(
                  'Not relinked, left unassigned (${_plan.unlinked.length})',
                  _unlinkedLines,
                  note:
                      'No matching key or passphrase is stored here. Add it, '
                      'then assign it in the host form.',
                ),
              if (pinned > 0) ...[
                _Section(
                  'Pinned host keys',
                  const [],
                  note:
                      '$pinned of the hosts to add '
                      '${pinned == 1 ? 'carries' : 'carry'} a pinned pre-boot '
                      'host key. Disk passphrases are sent only to a server '
                      'that shows its pinned key, so trusting a pin decides '
                      'who receives them. Trust the keys only if you made '
                      'this file yourself or checked the fingerprints. '
                      'Otherwise the hosts are imported without a pin and ask '
                      'you to confirm the key on the first connect.',
                ),
                CheckboxListTile(
                  key: const ValueKey('import-trust-pins'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    pinned == 1
                        ? 'Trust the pinned host key from this file'
                        : 'Trust the $pinned pinned host keys from this file',
                  ),
                  value: _trustPins,
                  onChanged: (v) => setState(() => _trustPins = v ?? false),
                ),
              ],
              if (_plan.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Nothing in this file can be added.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_plan.isEmpty ? 'Close' : 'Cancel'),
        ),
        if (!_plan.isEmpty)
          FilledButton(
            onPressed: () => Navigator.pop(context, _trustPins),
            child: const Text('Import'),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.lines, {this.note, this.empty});

  final String title;
  final List<String> lines;
  final String? note;
  final String? empty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          if (note case final n?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(n, style: theme.textTheme.bodySmall),
            ),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $line'),
            ),
          if (empty case final e? when lines.isEmpty)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(e)),
        ],
      ),
    );
  }
}
