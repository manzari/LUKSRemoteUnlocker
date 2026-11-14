import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.builder,
    required this.empty,
  });

  final AsyncValue<List<T>> value;
  final Widget Function(List<T> items) builder;
  final String empty;

  @override
  Widget build(BuildContext context) => switch (value) {
    AsyncData(value: final items) when items.isEmpty => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(empty, textAlign: TextAlign.center),
      ),
    ),
    AsyncData(value: final items) => builder(items),
    AsyncError() => const Center(child: Text('Could not load the data.')),
    _ => const Center(child: CircularProgressIndicator()),
  };
}
