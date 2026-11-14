import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../providers.dart';
import '../common/async_body.dart';
import 'profile_screen.dart';

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Unlock profiles')),
      body: AsyncBody(
        value: profiles,
        empty: 'No profiles.',
        builder: (profiles) => ListView(
          children: [
            for (final p in profiles)
              ListTile(
                leading: Icon(p.builtIn ? Icons.lock_outline : Icons.terminal),
                title: Text(p.name),
                subtitle: Text(
                  '${p.builtIn ? 'Built-in · ' : ''}${p.driver.id} · ${p.command}',
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ProfileScreen(profile: p),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
