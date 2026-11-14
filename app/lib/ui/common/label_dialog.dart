import 'package:material_ui/material_ui.dart';

Future<String?> askLabel(
  BuildContext context, {
  required String title,
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (_) => _LabelDialog(title: title, initial: initial),
);

class _LabelDialog extends StatefulWidget {
  const _LabelDialog({required this.title, required this.initial});

  final String title;
  final String initial;

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
        validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a label' : null,
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
