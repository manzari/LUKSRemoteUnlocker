import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/unlock_core.dart';

import '../../providers.dart';
import '../common/messages.dart';

/// Read-only view of a built-in profile (with copy), editor for a custom one.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.profile});

  final UnlockProfile profile;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.name);
  late final _command = TextEditingController(text: widget.profile.command);
  String? _error;

  bool get _readOnly => widget.profile.builtIn;

  @override
  void dispose() {
    _name.dispose();
    _command.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    try {
      final copy = await ref
          .read(profileRepositoryProvider)
          .copy(widget.profile.id);
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => ProfileScreen(profile: copy)),
      );
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .save(
            widget.profile.copyWith(
              name: _name.text.trim(),
              command: _command.text.trim(),
            ),
          );
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete profile?',
      message: 'Delete "${widget.profile.name}"?',
      action: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(profileRepositoryProvider).delete(widget.profile.id);
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_readOnly ? widget.profile.name : 'Edit profile'),
        actions: [
          if (!_readOnly) ...[
            IconButton(
              tooltip: 'Delete profile',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
            TextButton(onPressed: _save, child: const Text('Save')),
          ],
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_readOnly) ...[
              const Text(
                'Built-in profiles are read-only. Copy this one to change the '
                'command.',
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              key: const ValueKey('profile-name'),
              controller: _name,
              readOnly: _readOnly,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Driver',
                helperText:
                    'stdin: passphrase on standard input, result from the '
                    'exit code',
                helperMaxLines: 2,
              ),
              child: Text(widget.profile.driver.id),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('profile-command'),
              controller: _command,
              readOnly: _readOnly,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: const InputDecoration(
                labelText: 'Command',
                helperText: 'Run on the pre-boot server without a terminal',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a command' : null,
            ),
            if (_readOnly) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy_all),
                label: const Text('Copy and edit'),
              ),
            ],
            if (_error case final e?) ...[
              const SizedBox(height: 16),
              Text(e, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
