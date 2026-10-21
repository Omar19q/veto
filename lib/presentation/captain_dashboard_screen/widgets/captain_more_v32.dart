import 'package:flutter/material.dart';
import '../../categories/captain_categories_screen.dart';
import '../../../services/ride_categories.dart';
import '../../settings/product_settings_screen.dart';
import '../../../l10n/app_localizations.dart';

import '../../../l10n/strings.dart';
import '../../growth/growth_screens.dart';
import '../../growth/captain_growth_code_tile.dart';
import '../../customer/partner_portal_v39.dart';
import '../../../widgets/captain_photo_v16.dart';

/// Presentation-only captain account menu. All actions are supplied by the
/// existing dashboard so its permissions and navigation remain authoritative.
class CaptainMoreV32 extends StatelessWidget {
  const CaptainMoreV32({
    super.key,
    required this.captain,
    required this.linkedCustomer,
    required this.staffVerifier,
    required this.onOpenProfile,
    required this.onSwitchCustomer,
    required this.onQuickVerification,
    required this.onTrips,
    required this.onEarnings,
    required this.onDemand,
    required this.onNotifications,
    required this.onSupport,
    required this.onPrivacy,
    required this.onDelete,
    required this.onRefresh,
    required this.onSignOut,
  });

  final Map<String, dynamic>? captain;
  final bool linkedCustomer;
  final bool staffVerifier;
  final VoidCallback onOpenProfile;
  final VoidCallback onSwitchCustomer;
  final VoidCallback onQuickVerification;
  final VoidCallback onTrips;
  final VoidCallback onEarnings;
  final VoidCallback onDemand;
  final VoidCallback onNotifications;
  final VoidCallback onSupport;
  final VoidCallback onPrivacy;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;


  void _chooseProfile(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (sheet) => Directionality(
        textDirection: Directionality.of(context),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 8, 18, 22),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
               Text(context.strings.account9193bd6a, style: TextStyle(
                 color: Theme.of(context).colorScheme.onSurface, fontSize: 19,
                fontWeight: FontWeight.w900,
              )),
              SizedBox(height: 16),
              _item(context, Icons.drive_eta_rounded, context.strings.account7272be04, () => Navigator.pop(sheet),
                trailing: Icons.radio_button_checked_rounded),
              if (linkedCustomer) ...[
                SizedBox(height: 8),
                _item(context, Icons.person_outline_rounded, context.strings.accountdebf96d9, () {
                  Navigator.pop(sheet);
                  onSwitchCustomer();
                }, trailing: Icons.radio_button_unchecked_rounded),
              ],
              if (!linkedCustomer)
                 Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(context.strings.accounta180a470,
                    textAlign: TextAlign.center,
                    style: TextStyle( color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                ),
              SizedBox(height: 12),
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: () => Navigator.pop(sheet),
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Color(0xFF111725)),
                child:  Text(context.strings.account3ef541b9, style: TextStyle(
                  fontWeight: FontWeight.w800)),
              )),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String title, VoidCallback onTap,
      {IconData trailing = Icons.chevron_left_rounded}) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          SizedBox(width: 13),
          Expanded(child: Text(title, style: TextStyle(
             color: Theme.of(context).colorScheme.onSurface, fontSize: 13.5,
            fontWeight: FontWeight.w700))),
          Icon(trailing, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 21),
        ]),
      ),
    ),
  );

  Widget _shortcut(BuildContext context, IconData icon, String label, VoidCallback onTap) => Expanded(
    child: Material(color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(borderRadius: BorderRadius.circular(17), onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 17, horizontal: 5),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 24),
            SizedBox(height: 7),
            Text(label, style: TextStyle(
              fontSize: 12, color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final name = captain?['full_name']?.toString().trim() ?? '';
    final photo = (captain?['profile_photo']?.toString().isNotEmpty == true)
        ? captain!['profile_photo'].toString()
        : (captain?['profile_photo_url']?.toString().isNotEmpty == true)
            ? captain!['profile_photo_url'].toString()
            : null;
    final rating = (captain?['rating'] as num?)?.toDouble();
    return Directionality(
      textDirection: Directionality.of(context),
      child: ListView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 19, 16, 35),
        children: [
          ListTile(leading:const Icon(Icons.directions_car_rounded),title:Text(categoryCopy(context,'الفئات المتاحة لي','My ride categories')),onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const CaptainCategoriesScreen()))),
          Row(children: [
             Expanded(child: Text(context.strings.account478c486f, style: TextStyle(
               color: Theme.of(context).colorScheme.onSurface, fontSize: 23,
              fontWeight: FontWeight.w900))),
            Image.asset('assets/images/veto_sanya_app_icon.png',
              width: 37, height: 37, fit: BoxFit.contain,
              semanticLabel: 'VETO SANYA'),
          ]),
          SizedBox(height: 20),
          InkWell(
            onTap: onOpenProfile,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  backgroundImage: photo == null ? null : captainPhotoV16(photo),
                  child: photo == null ? Icon(Icons.person,
                    color: Theme.of(context).colorScheme.onSurfaceVariant, size: 35) : null,
                ),
                SizedBox(width: 15),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? context.strings.account7272be04 : name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22, color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.star_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                      SizedBox(width: 4),
                      Flexible(child: Text(rating == null ? context.strings.account6553a836
                          : rating.toStringAsFixed(1),
                        style: TextStyle( color: Theme.of(context).colorScheme.onSurfaceVariant))),
                    ]),
                  ],
                )),
                Icon(Icons.chevron_left_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ]),
            ),
          ),
          SizedBox(height: 16),
          Material(color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => _chooseProfile(context),
              borderRadius: BorderRadius.circular(16),
              child:  Padding(
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                child: Row(children: [
                  Icon(Icons.badge_rounded, color: Theme.of(context).colorScheme.onSurface),
                  SizedBox(width: 12),
                  Expanded(child: Text(context.strings.account7272be04, style: TextStyle(
                     color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14, fontWeight: FontWeight.w800))),
                  Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ]),
              ),
            ),
          ),
          SizedBox(height: 17),
          Row(children: [
            _shortcut(context, Icons.support_agent_rounded, context.strings.account30db229c, onSupport),
            SizedBox(width: 9),
            _shortcut(context, Icons.account_balance_wallet_outlined, context.strings.account166aea7d, onEarnings),
            SizedBox(width: 9),
            _shortcut(context, Icons.route_rounded, context.strings.accountf3683943, onTrips),
          ]),
          SizedBox(height: 22),
          if (linkedCustomer) ...[
            SizedBox(height: 8),
            _item(context, Icons.swap_horiz_rounded, context.strings.accountb439a50f, onSwitchCustomer),
          ],
          PartnerAccessTileV39(),
          _item(context, Icons.settings_outlined, AppLocalizations.of(context).settings, () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ProductSettingsScreen()))),
          CaptainGrowthCodeTile(accountId: captain?['id']?.toString() ?? ''),
          _item(context, Icons.card_giftcard_rounded, context.strings.badgeMenuAction, () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => GrowthReferralScreen(captain: true)))),
          _item(context, Icons.local_fire_department_rounded, context.strings.accounta496e785, onDemand),
          SizedBox(height: 8),
          _item(context, Icons.person_outline_rounded, context.strings.account654a0663, onOpenProfile),
          if (staffVerifier) ...[
            SizedBox(height: 8),
            _item(context, Icons.verified_user_outlined, context.strings.account8f2788c0, onQuickVerification),
          ],
          SizedBox(height: 8),
          _item(context, Icons.notifications_none_rounded, context.strings.account8ce3e0cc, onNotifications),
          SizedBox(height: 8),
          _item(context, Icons.support_agent_rounded, context.strings.accountc3bb52b7, onSupport),
          SizedBox(height: 8),
          _item(context, Icons.shield_outlined, context.strings.accountaa6de5d4, onPrivacy),
          SizedBox(height: 8),
          _item(context, Icons.person_remove_outlined, context.strings.account24c192cb, onDelete),
          SizedBox(height: 8),
          _item(context, Icons.refresh_rounded, context.strings.account5bc457c0, onRefresh),
          SizedBox(height: 8),
          _item(context, Icons.logout_rounded, context.strings.account21f47442, onSignOut),
          SizedBox(height: 15),
          Center(child: Text('VETO SANYA', style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
