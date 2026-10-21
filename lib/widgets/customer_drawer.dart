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
    Widget item(IconData icon, String label, VoidCallback action) => ListTile(
      minVerticalPadding: 12,
      leading: Icon(icon, color: c.primary),
      title: Text(label),
      onTap: action,
    );
    return Drawer(
      width: (MediaQuery.sizeOf(context).width - 32).clamp(0, 360).toDouble(),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ListTile(
              title: const Text('VETO SANYA'),
              subtitle: Text(l.menuWelcome),
              trailing: IconButton(
                tooltip: l.close,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Divider(),
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
            const Divider(),
            item(
              Icons.badge_outlined,
              l.menuCaptainApply,
              () => _route('/captain-registration'),
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
            item(Icons.logout, l.menuLogout, () async {
              final router = GoRouter.of(context);
              await SupabaseService.instance.signOut();
              if (mounted) {
                Navigator.pop(context);
                router.go('/sign-up-login-screen');
              }
            }),
          ],
        ),
      ),
    );
  }
}
