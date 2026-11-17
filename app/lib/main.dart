import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/open_database.dart';
import 'providers.dart';
import 'run/run_providers.dart';
import 'services/plugin_foreground_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase();
  final lifecycle = platformRunLifecycle();
  if (lifecycle != null) unawaited(lifecycle.stopLeftover());
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        if (lifecycle != null)
          runLifecycleProvider.overrideWithValue(lifecycle),
      ],
      child: const LuksRemoteUnlockerApp(),
    ),
  );
}
