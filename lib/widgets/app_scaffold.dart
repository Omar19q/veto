import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import './customer_drawer.dart';
import './app_navigation.dart';

class AppScaffold extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const AppScaffold({required this.navigationShell, super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final scaffold = _scaffoldKey.currentState;
    final isDrawerOpen = scaffold?.isDrawerOpen ?? false;
    final canReturnToHome =
        !isDrawerOpen && widget.navigationShell.currentIndex != 0;

    return PopScope(
      canPop: !isDrawerOpen && !canReturnToHome,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
        } else if (widget.navigationShell.currentIndex != 0) {
          widget.navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        onDrawerChanged: (_) => setState(() {}),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawer: const CustomerDrawer(),
        appBar: const [0, 3].contains(widget.navigationShell.currentIndex)
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
