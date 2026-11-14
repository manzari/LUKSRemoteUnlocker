import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/unlock_core.dart';

void main() {
  runApp(const LuksRemoteUnlockerApp());
}

class LuksRemoteUnlockerApp extends StatelessWidget {
  const LuksRemoteUnlockerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LUKS Remote Unlocker',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LUKS Remote Unlocker')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No servers yet.'),
            const SizedBox(height: 8),
            Text(
              'Core $unlockCoreVersion',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
