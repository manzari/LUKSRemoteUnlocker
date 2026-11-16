import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

const int minPasswordLength = 10;

/// UTF-8 bytes of the field text, exactly as typed.
Uint8List textBytes(TextEditingController controller) =>
    utf8.encode(controller.text);

class NewPasswordFields extends StatelessWidget {
  const NewPasswordFields({
    super.key,
    required this.password,
    required this.confirmation,
    this.label = 'Password',
    this.minLength = minPasswordLength,
    this.enabled = true,
  });

  final TextEditingController password;
  final TextEditingController confirmation;
  final String label;
  final int minLength;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextFormField(
        key: const ValueKey('new-password'),
        controller: password,
        enabled: enabled,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          helperText: minLength > 1 ? 'At least $minLength characters' : null,
        ),
        validator: (v) {
          final length = (v ?? '').runes.length;
          if (length == 0) return 'Enter a ${label.toLowerCase()}';
          if (length < minLength) return 'Use at least $minLength characters';
          return null;
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: const ValueKey('confirm-password'),
        controller: confirmation,
        enabled: enabled,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(labelText: 'Repeat ${label.toLowerCase()}'),
        validator: (v) =>
            v == password.text ? null : 'The entries do not match',
      ),
    ],
  );
}

typedef _Entered = ({Uint8List? current, Uint8List next});

/// The caller zeroes both buffers when done.
typedef PasswordChange = ({Uint8List current, Uint8List next});

Future<Uint8List?> askNewPassword(
  BuildContext context, {
  required String title,
  String? message,
}) async => (await showDialog<_Entered>(
  context: context,
  builder: (_) => _NewPasswordDialog(title: title, message: message),
))?.next;

/// Asks for the current password together with the new one.
Future<PasswordChange?> askPasswordChange(
  BuildContext context, {
  required String title,
}) async {
  final entered = await showDialog<_Entered>(
    context: context,
    builder: (_) => _NewPasswordDialog(title: title, askCurrent: true),
  );
  if (entered == null) return null;
  return (current: entered.current!, next: entered.next);
}

class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog({
    required this.title,
    this.message,
    this.askCurrent = false,
  });

  final String title;
  final String? message;
  final bool askCurrent;

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    for (final c in [_current, _password, _confirmation]) {
      c
        ..clear()
        ..dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final entered = (
      current: widget.askCurrent ? textBytes(_current) : null,
      next: textBytes(_password),
    );
    _current.clear();
    _password.clear();
    _confirmation.clear();
    Navigator.pop(context, entered);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message case final m?) ...[
              Text(m),
              const SizedBox(height: 12),
            ],
            if (widget.askCurrent) ...[
              TextFormField(
                key: const ValueKey('current-password'),
                controller: _current,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Enter the current password' : null,
              ),
              const SizedBox(height: 12),
            ],
            NewPasswordFields(
              password: _password,
              confirmation: _confirmation,
              label: widget.askCurrent ? 'New password' : 'Password',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Save')),
    ],
  );
}
