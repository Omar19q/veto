import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/strings.dart';
import '../services/supabase_service.dart';
import '../services/veto_mode_v21.dart';
import '../presentation/settings/product_settings_screen.dart';
import '../presentation/growth/growth_screens.dart';
import '../presentation/customer/customer_loyalty_panel_v29.dart';
import '../presentation/addresses/customer_saved_addresses.dart';

/// Navigation only: every operational route keeps its existing server guards.
class CustomerDrawer extends StatefulWidget {
  const CustomerDrawer({super.key});
  @override
  State<CustomerDrawer> createState() => _CustomerDrawerState();
}

class _CustomerDrawerState extends State<CustomerDrawer> {
  bool _captain = false;
  @override
  void initState() {
    super.initState();
    _readRole();
  }

  Future<void> _readRole() async {
    final owner = SupabaseService.instance.currentUser?.id;
    if (owner == null) return;
    try {
      final approved = await VetoModeV21.canUseCaptain(owner);
      if (mounted && owner == SupabaseService.instance.currentUser?.id)
        setState(() => _captain = approved);
    } catch (_) {
      /* Do not infer captain approval on failure. */
    }
  }

  void _route(String path) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.go(path);
  }

  void _page(Widget child) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute<void>(builder: (_) => child));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.strings, c = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget item(IconData icon, String label, VoidCallback action, {Color? color}) => ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: color ?? c.primary),
      title: Text(label, style: color != null ? TextStyle(color: color, fontWeight: FontWeight.w700) : null),
      onTap: action,
    );

    return Drawer(
      backgroundColor: c.surface,
      width: (MediaQuery.sizeOf(context).width - 32).clamp(0, 360).toDouble(),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          children: [
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.directions_car_filled_rounded,
                  color: isDark ? const Color(0xFF0B0F1A) : Colors.white,
                  size: 20,
                ),
              ),
              title: const Text(
                'VETO SANYA',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
              subtitle: Text(l.menuWelcome),
              trailing: IconButton(
                tooltip: l.close,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Divider(color: c.outlineVariant, height: 1),
            item(Icons.home_outlined, l.home, () => _route('/home-screen')),
            item(
              Icons.person_outline,
              l.menuProfile,
              () => _page(const CustomerLoyaltyPanelV29()),
            ),
            item(Icons.route_outlined, l.menuTrips, () => _route('/my-trips')),
            item(
              Icons.account_balance_wallet_outlined,
              l.menuWallet,
              () => _route('/wallet'),
            ),
            item(
              Icons.local_offer_outlined,
              l.menuOffers,
              () => _page(const GrowthReferralScreen()),
            ),
            item(
              Icons.people_outline,
              l.menuInvite,
              () => _page(const GrowthReferralScreen()),
            ),
            item(
              Icons.newspaper_outlined,
              l.menuNews,
              () => _route('/karizma'),
            ),
            item(
              Icons.bookmark_outline,
              l.savedPlaces,
              () => _page(const CustomerSavedAddresses()),
            ),
            item(
              Icons.notifications_none,
              l.notifications,
              () => _route('/notifications'),
            ),
            item(Icons.support_agent, l.menuHelp, () => _route('/feedback')),
            item(
              Icons.shield_outlined,
              l.menuSafety,
              () => _route('/safety-support'),
            ),
            item(
              Icons.settings_outlined,
              l.menuSettings,
              () => _page(const ProductSettingsScreen()),
            ),
            item(Icons.policy_outlined, l.menuLegal, () => _route('/legal')),
            Divider(color: c.outlineVariant, height: 1),
            item(
              Icons.badge_outlined,
              l.menuCaptainApply,
              () => _route('/captain-registration'),
              color: isDark ? const Color(0xFFFFC107) : const Color(0xFF5D5FEF),
            ),
            if (_captain)
              item(Icons.drive_eta_outlined, l.menuCaptainMode, () async {
                final id = SupabaseService.instance.currentUser?.id;
                final router = GoRouter.of(context);
                Navigator.pop(context);
                if (id != null) await VetoModeV21.openCaptain(router, id);
              }),
            // Preserve partner, verifier and legacy account tools behind their guards.
            item(
              Icons.manage_accounts_outlined,
              l.menuAccountTools,
              () => _route('/more'),
            ),
            item(
              Icons.logout_rounded,
              l.menuLogout,
              () async {
                final router = GoRouter.of(context);
                final navigator = Navigator.of(context);
                await SupabaseService.instance.signOut();
                if (mounted) {
                  navigator.pop();
                  router.go('/sign-up-login-screen');
                }
              },
              color: const Color(0xFFEF5350),
            ),
          ],
        ),
      ),
    );
  }
}
