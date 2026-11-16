import 'package:material_ui/material_ui.dart';

import '../../data/errors.dart';

/// Non-empty and not in [taken]; the repositories enforce the same rule.
String? validateLabel(String? value, Iterable<String> taken) {
  final label = (value ?? '').trim();
  if (label.isEmpty) return 'Enter a label';
  if (taken.any((t) => sameLabel(t, label))) {
    return 'This label is already used';
  }
  return null;
}

/// [taken] are the labels of the other items of the same kind.
Future<String?> askLabel(
  BuildContext context, {
  required String title,
  String initial = '',
  Iterable<String> taken = const [],
}) => showDialog<String>(
  context: context,
  builder: (_) => _LabelDialog(title: title, initial: initial, taken: taken),
);

class _LabelDialog extends StatefulWidget {
  const _LabelDialog({
    required this.title,
    required this.initial,
    required this.taken,
  });

  final String title;
  final String initial;
  final Iterable<String> taken;

  @override
  State<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<_LabelDialog> {
  final _form = GlobalKey<FormState>();
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _text.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _form,
      child: TextFormField(
        key: const ValueKey('label-dialog-field'),
        controller: _text,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Label'),
        validator: (v) => validateLabel(v, widget.taken),
        onFieldSubmitted: (_) => _submit(),
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
