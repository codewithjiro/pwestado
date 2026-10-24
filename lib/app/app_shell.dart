import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/saved/state/saved_analyses_controller.dart';
import 'router.dart';
import 'theme.dart';

/// The four main tabs, in branch order.
enum AppTab {
  map('MAPA', Icons.map_outlined, Icons.map, AppRoutes.explore),
  analyze(
    'ANALYZE',
    Icons.insights_outlined,
    Icons.insights,
    AppRoutes.analyze,
  ),
  compare(
    'COMPARE',
    Icons.compare_arrows_outlined,
    Icons.compare_arrows,
    AppRoutes.compare,
  ),
  saved('SAVED', Icons.bookmarks_outlined, Icons.bookmarks, AppRoutes.saved);

  const AppTab(this.label, this.icon, this.selectedIcon, this.location);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String location;
}

/// Scaffold with the persistent bottom navigation. The body is the
/// [StatefulNavigationShell]'s IndexedStack, so hidden tabs keep their
/// state (and the map keeps its native view).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedCount = ref.watch(
      savedAnalysesControllerProvider.select((s) => s.items.length),
    );
    // Colors, height and label styles come from the theme's
    // NavigationBarThemeData, so light and dark mode stay consistent.
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.palette.border)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) => shell.goBranch(
            index,
            // Tapping the current tab again returns to its first page.
            initialLocation: index == shell.currentIndex,
          ),
          destinations: [
            for (final tab in AppTab.values)
              NavigationDestination(
                tooltip: tab.label,
                label: tab.label,
                icon: _badged(tab, savedCount, Icon(tab.icon)),
                selectedIcon: _badged(tab, savedCount, Icon(tab.selectedIcon)),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _badged(AppTab tab, int savedCount, Widget icon) {
    if (tab != AppTab.saved || savedCount == 0) return icon;
    return Badge(label: Text('$savedCount'), child: icon);
  }
}
