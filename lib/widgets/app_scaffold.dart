import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import './customer_drawer.dart';

class AppScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppScaffold({required this.navigationShell, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const CustomerDrawer(),
      appBar: const [0, 3].contains(navigationShell.currentIndex)
          ? null
          : AppBar(
              title: const Text('VETO SANYA'),
              actions: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => navigationShell.goBranch(0),
                  icon: const Icon(Icons.home_outlined),
                ),
              ],
            ),
      body: navigationShell,
    );
  }
}
