import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import './app_navigation.dart';

class AppScaffold extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const AppScaffold({required this.navigationShell, super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  @override
  Widget build(BuildContext context) {
    final canReturnToHome = widget.navigationShell.currentIndex != 0;

    return PopScope(
      canPop: !canReturnToHome,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.navigationShell.currentIndex != 0) {
          widget.navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const [0, 3, 4].contains(widget.navigationShell.currentIndex)
            ? null
            : AppBar(
                title: const Text('VETO SANYA'),
                actions: [
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => widget.navigationShell.goBranch(0),
                    icon: const Icon(Icons.home_outlined),
                  ),
                ],
              ),
        body: widget.navigationShell,
        bottomNavigationBar:
            AppNavigation(navigationShell: widget.navigationShell),
      ),
    );
  }
}

