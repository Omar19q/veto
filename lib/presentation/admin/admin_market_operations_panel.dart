import 'package:flutter/material.dart';

import 'admin_supermarket_panel.dart';

/// Compatibility entry point for older dashboard builds.
/// All market operations now live in the unified, tested supermarket panel.
class AdminMarketOperationsPanel extends StatelessWidget {
  const AdminMarketOperationsPanel({super.key});

  @override
  Widget build(BuildContext context) => const AdminSupermarketPanel();
}
