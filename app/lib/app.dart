import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'providers.dart';
import 'ui/common/messages.dart';
import 'ui/shell.dart';
import 'ui/vault/setup_screen.dart';
import 'vault/vault_controller.dart';

class LuksRemoteUnlockerApp extends ConsumerStatefulWidget {
  const LuksRemoteUnlockerApp({super.key});

  @override
  ConsumerState<LuksRemoteUnlockerApp> createState() => _AppState();
}

class _AppState extends ConsumerState<LuksRemoteUnlockerApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onLifecycle(AppLifecycleState state) {
    final controller = ref.read(vaultControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        controller.appBackgrounded();
      case AppLifecycleState.resumed:
        if (ref.read(vaultControllerProvider).phase != VaultPhase.loading) {
          controller.refreshCapabilities().ignore();
        }
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LUKS Remote Unlocker',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    darkTheme: ThemeData(
      colorSchemeSeed: Colors.indigo,
      brightness: Brightness.dark,
    ),
    builder: (context, child) => Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => ref.read(vaultControllerProvider.notifier).touch(),
      child: child,
    ),
    home: const VaultGate(),
  );
}

/// Setup on first run, else the main shell (which works while the vault is locked).
class VaultGate extends ConsumerWidget {
  const VaultGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(vaultControllerProvider);
    return switch (status.phase) {
      VaultPhase.loading => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      VaultPhase.needsSetup => const VaultSetupScreen(),
      VaultPhase.failed => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'The vault could not be opened. '
              '${describeError(status.error ?? 'unknown')}',
            ),
          ),
        ),
      ),
      VaultPhase.locked || VaultPhase.unlocked => const HomeShell(),
    };
  }
}
