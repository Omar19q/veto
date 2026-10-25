import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import './app_navigation.dart';

class AppScaffold extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const AppScaffold({required this.navigationShell, super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final isHome = widget.navigationShell.currentIndex == 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If not on Home tab, return to Home smoothly
        if (!isHome) {
          widget.navigationShell.goBranch(0);
          return;
        }

        // On Home tab: double-tap back to exit
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          final isEn = Localizations.localeOf(context).languageCode == 'en';
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEn ? 'Press back again to exit' : 'اضغط مرة أخرى للخروج من التطبيق',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 24),
            ),
          );
        } else {
          _lastBackPressTime = null;
          SystemNavigator.pop();
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


