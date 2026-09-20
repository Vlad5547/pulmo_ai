import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

import 'history/history_screen.dart';
import 'home/home_screen.dart';

/// Holds the two persistent destinations. Uses a bottom navigation bar on
/// phones and a navigation rail from tablet width upwards.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  List<NavigationDestination> _destinations(AppL10n l10n) => [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home_rounded),
          label: l10n.navHome,
        ),
        NavigationDestination(
          icon: const Icon(Icons.history_outlined),
          selectedIcon: const Icon(Icons.history_rounded),
          label: l10n.navHistory,
        ),
      ];

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations(AppL10n.of(context));
    final pages = [
      HomeScreen(onOpenHistory: () => _select(1)),
      const HistoryScreen(),
    ];
    final body = IndexedStack(index: _index, children: pages);
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: d.icon,
                    selectedIcon: d.selectedIcon,
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: destinations,
      ),
    );
  }
}
