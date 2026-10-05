import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/offline_banner.dart';
import '../theme/care_tokens.dart';

class ShellDestination {
  const ShellDestination({required this.path, required this.icon, required this.label});
  final String path;
  final IconData icon;
  final String label;
}

/// The bottom navigation frame for a role's main tabs. Deliberately just tab roots —
/// drill-down screens (add medicine, medicine details, settings, ...) are pushed on top
/// without it, so the elder always has a full-screen back button there instead of an
/// ambiguous "does the tab bar still apply?" state.
class AppShell extends StatelessWidget {
  const AppShell({required this.child, required this.currentPath, required this.destinations, super.key});

  final Widget child;
  final String currentPath;
  final List<ShellDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final index = destinations.indexWhere((d) => currentPath == d.path);
    // Colours, indicator and label styles come from the Sathi theme (CareTheme); the shell
    // only adds the soft top shadow that separates the bar from the warm page.
    final bar = DecoratedBox(
      decoration: const BoxDecoration(
        color: CareColors.surface,
        boxShadow: [BoxShadow(color: Color(0x140B1F2A), blurRadius: 18, offset: Offset(0, -4))],
      ),
      child: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(destinations[i].path),
        destinations: [for (final d in destinations) NavigationDestination(icon: Icon(d.icon), label: d.label)],
      ),
    );
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: bar,
    );
  }
}
