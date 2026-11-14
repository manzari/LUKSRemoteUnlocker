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

Future<Uint8List?> askNewPassword(
  BuildContext context, {
  required String title,
  String? message,
}) => showDialog<Uint8List>(
  context: context,
  builder: (_) => _NewPasswordDialog(title: title, message: message),
);

class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog({required this.title, this.message});

  final String title;
  final String? message;

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _password
      ..clear()
      ..dispose();
    _confirmation
      ..clear()
      ..dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final bytes = textBytes(_password);
    _password.clear();
    _confirmation.clear();
    Navigator.pop(context, bytes);
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
            NewPasswordFields(password: _password, confirmation: _confirmation),
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
