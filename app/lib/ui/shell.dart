import 'package:material_ui/material_ui.dart';

import 'hosts/hosts_screen.dart';
import 'keys/keys_screen.dart';
import 'profiles/profiles_screen.dart';
import 'secrets/secrets_screen.dart';
import 'settings/settings_screen.dart';

/// Wider than this, the navigation moves into a side rail.
const double wideLayoutBreakpoint = 640;

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon, this.page);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}

const _destinations = [
  _Destination('Hosts', Icons.dns_outlined, Icons.dns, HostsScreen()),
  _Destination('Keys', Icons.key_outlined, Icons.key, KeysScreen()),
  _Destination(
    'Passphrases',
    Icons.password_outlined,
    Icons.password,
    SecretsScreen(),
  ),
  _Destination(
    'Profiles',
    Icons.terminal_outlined,
    Icons.terminal,
    ProfilesScreen(),
  ),
  _Destination(
    'Settings',
    Icons.settings_outlined,
    Icons.settings,
    SettingsScreen(),
  ),
];

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final page = _destinations[_index].page;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= wideLayoutBreakpoint) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final d in _destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: page),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          body: page,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: [
              for (final d in _destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ),
            ],
          ),
        );
      },
    );
  }
}
