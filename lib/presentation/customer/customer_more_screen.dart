import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/strings.dart';
import '../../routes/app_routes.dart';
import '../../services/staff_access_v16.dart';
import '../../services/supabase_service.dart';
import '../../services/veto_mode_v21.dart';
import '../../widgets/customer_identity_v29.dart';
import '../addresses/address_suggestion_history.dart';
import '../growth/growth_screens.dart';
import '../settings/product_settings_screen.dart';
import 'customer_loyalty_panel_v29.dart';
import 'partner_portal_v39.dart';

class CustomerMoreScreen extends StatefulWidget {
  const CustomerMoreScreen({super.key});

  @override
  State<CustomerMoreScreen> createState() => _CustomerMoreScreenState();
}

class _CustomerMoreScreenState extends State<CustomerMoreScreen> {
  bool _approvedCaptainV21 = false;
  bool _staffVerifierV21 = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkCaptainV21();
    _checkVerifierV21();
  }

  Future<void> _checkVerifierV21() async {
    try {
      final access = await StaffAccessV16.load();
      final allowed =
          access.active &&
          access.can('verification.view') &&
          access.can('verification.manage');
      if (mounted && allowed != _staffVerifierV21) {
        setState(() => _staffVerifierV21 = allowed);
      }
    } catch (_) {}
  }

  Future<void> _checkCaptainV21() async {
    final id = SupabaseService.instance.currentUser?.id;
    if (id == null) return;
    try {
      final approved = await VetoModeV21.canUseCaptain(id);
      if (mounted && approved != _approvedCaptainV21) {
        setState(() => _approvedCaptainV21 = approved);
      }
    } catch (_) {}
  }

  Map<String, dynamic>? _loyaltyV31;
  Future<void> _loadLoyaltyV31() async {
    try {
      final result = await SupabaseService.instance.client
          .rpc('customer_loyalty_profile_v29')
          .timeout(const Duration(seconds: 9));
      if (mounted && result is Map) {
        setState(() => _loyaltyV31 = Map<String, dynamic>.from(result));
      }
    } catch (_) {
      /* A profile failure must not block the More page. */
    }
  }

  String _customerName = '';
  String _supportPhone = '';
  String _supportWhatsapp = '';
  String? _profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadLoyaltyV31();
  }

  Future<void> _loadProfile() async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) return;
      final customer = await SupabaseService.instance.getCustomerByUserId(
        user.id,
      );
      if (customer != null && mounted) {
        setState(() {
          _customerName = (customer['full_name'] as String?) ?? '';
          _profilePhotoUrl = customer['profile_photo_url'] as String?;
        });
      }
      final phone = await SupabaseService.instance.getSetting(
        'customer_service_phone',
      );
      final wa = await SupabaseService.instance.getSetting(
        'customer_service_whatsapp',
      );
      if (mounted) {
        setState(() {
          if (phone != null && phone.isNotEmpty) _supportPhone = phone;
          if (wa != null && wa.isNotEmpty) _supportWhatsapp = wa;
        });
      }
    } catch (_) {}
  }

  Future<void> _showCustomerSupport() async {
    final wa = _supportWhatsapp.replaceAll(RegExp(r'\D'), '');
    final intl = wa.startsWith('20')
        ? wa
        : '20${wa.replaceFirst(RegExp(r'^0+'), '')}';
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      builder: (ctx) => Directionality(
        textDirection: Directionality.of(context),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.strings.profilec3bb52b7,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF0F2F8),
                  ),
                ),
                const SizedBox(height: 14),
                if (_supportPhone.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          launchUrl(Uri.parse('tel:$_supportPhone')),
                      icon: const Icon(Icons.call_rounded),
                      label: Text(
                        context.strings.profile606af07c,
                        style: TextStyle(),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                if (intl.length >= 12) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'https://wa.me/$intl?text=${Uri.encodeComponent(context.strings.profile8e10b7d8)}',
                        ),
                      ),
                      icon: const Icon(
                        Icons.chat_rounded,
                        color: Color(0xFF25D366),
                      ),
                      label: Text(
                        'WhatsApp',
                        style: TextStyle(color: Color(0xFF25D366)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFullProfileV31() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CustomerLoyaltyPanelV29()),
    );
    if (!mounted) return;
    await _loadProfile();
    await _loadLoyaltyV31();
  }

  // The selected account remains bound to the same authenticated UID.
  // Registration never grants captain permissions without server approval.
  void _chooseAccountV31() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF111927),
      builder: (sheet) => Directionality(
        textDirection: Directionality.of(context),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.strings.profile9193bd6a,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  tileColor: const Color(0xFF252D3A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFFFFC534),
                  ),
                  title: Text(
                    context.strings.profile41e29a2a,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.radio_button_checked_rounded,
                    color: Color(0xFFFFC534),
                  ),
                  onTap: () => Navigator.pop(sheet),
                ),
                const SizedBox(height: 9),
                ListTile(
                  tileColor: const Color(0xFF252D3A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: const Icon(
                    Icons.drive_eta_rounded,
                    color: Color(0xFFFFC534),
                  ),
                  title: Text(
                    _approvedCaptainV21
                        ? context.strings.profile7272be04
                        : context.strings.profilee979acbd,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    _approvedCaptainV21
                        ? context.strings.profileb9eaeabe
                        : context.strings.profilebad7739d,
                    style: const TextStyle(
                      color: Color(0xFFAAB5C9),
                      fontSize: 11,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.radio_button_unchecked_rounded,
                    color: Color(0xFFAAB5C9),
                  ),
                  onTap: () async {
                    Navigator.pop(sheet);
                    if (_approvedCaptainV21) {
                      final id = SupabaseService.instance.currentUser?.id;
                      if (id != null && mounted) {
                        await VetoModeV21.openCaptain(GoRouter.of(context), id);
                      }
                    } else if (mounted) {
                      context.push(AppRoutes.captainRegistration);
                    }
                  },
                ),
                const SizedBox(height: 13),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheet),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC534),
                      foregroundColor: const Color(0xFF101724),
                    ),
                    child: Text(
                      context.strings.profile3ef541b9,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickV31(IconData icon, String label, VoidCallback action) =>
      Expanded(
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: action,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: const Color(0xFFFFC743), size: 27),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final data = _loyaltyV31;
    final frames = (data?['frames'] as List?) ?? const [];
    Map<String, dynamic>? selected;
    for (final raw in frames) {
      if (raw is Map && raw['key'] == data?['selected_frame']) {
        selected = Map<String, dynamic>.from(raw);
        break;
      }
    }
    final rating = (data?['rating'] as num?)?.toDouble();
    final ratingCount = (data?['rating_count'] as num?)?.toInt() ?? 0;
    final name = _customerName.trim().isEmpty
        ? context.strings.profileafe5d60a
        : _customerName;
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A101A),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadProfile();
              await _loadLoyaltyV31();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/veto_sanya_app_icon.png',
                      width: 38,
                      height: 38,
                      semanticLabel: 'VETO SANYA',
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.strings.profile3f3089b7,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.strings.profile6b1fd308,
                      onPressed: () async {
                        await _loadProfile();
                        await _loadLoyaltyV31();
                      },
                      icon: Icon(Icons.refresh_rounded, color: gold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Material(
                  color: const Color(0xFF131D2D),
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: _openFullProfileV31,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(17),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CustomerFrameAvatarV29(
                                size: 80,
                                photo: _profilePhotoUrl,
                                accentHex: selected?['accent_hex']?.toString(),
                                glyph: selected?['glyph']?.toString(),
                              ),
                              const SizedBox(width: 17),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontSize: 21,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          color: gold,
                                          size: 17,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          ratingCount == 0 || rating == null
                                              ? context.strings.profile4f95f432
                                              : rating.toStringAsFixed(1),
                                          style: TextStyle(
                                            color: muted,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data?['tier']?.toString() ??
                                          context.strings.profile05f99bc8,
                                      style: TextStyle(
                                        color: gold,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: muted,
                                size: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_rounded,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  size: 19,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.strings.profile2df1f491,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.edit_outlined,
                                  color: gold,
                                  size: 17,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                InkWell(
                  onTap: _chooseAccountV31,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_rounded, color: gold, size: 20),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            context.strings.profile41e29a2a,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          context.strings.profile89e7f927,
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                        SizedBox(width: 5),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () async {
                      if (_approvedCaptainV21) {
                        final id = SupabaseService.instance.currentUser?.id;
                        if (id != null && mounted) {
                          await VetoModeV21.openCaptain(
                            GoRouter.of(context),
                            id,
                          );
                        }
                      } else {
                        context.push(AppRoutes.captainRegistration);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.drive_eta_rounded, color: gold),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _approvedCaptainV21
                                  ? context.strings.profile9092f905
                                  : context.strings.profilee979acbd,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_left_rounded, color: gold),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _quickV31(
                      Icons.support_agent_rounded,
                      context.strings.profile30db229c,
                      _showCustomerSupport,
                    ),
                    const SizedBox(width: 10),
                    _quickV31(
                      Icons.account_balance_wallet_rounded,
                      context.strings.profile69cb4d81,
                      () => context.go('/wallet'),
                    ),
                    const SizedBox(width: 10),
                    _quickV31(
                      Icons.receipt_long_rounded,
                      context.strings.profile92d05589,
                      () => context.go('/my-trips'),
                    ),
                  ],
                ),
                const SizedBox(height: 23),
                Text(
                  context.strings.profile09f41ce6,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                _MoreTile(
                  icon: Icons.workspace_premium_rounded,
                  label: context.strings.profilec8c5d575,
                  subtitle: context.strings.profilebfa6d7fd,
                  color: gold,
                  onTap: _openFullProfileV31,
                ),
                const PartnerAccessTileV39(),
                _MoreTile(
                  icon: Icons.add_location_alt_outlined,
                  label: AppLocalizations.of(context).mySuggestions,
                  subtitle: AppLocalizations.of(context).pending,
                  color: gold,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddressSuggestionHistory(),
                    ),
                  ),
                ),
                _MoreTile(
                  icon: Icons.settings_outlined,
                  label: AppLocalizations.of(context).settings,
                  subtitle:
                      '${AppLocalizations.of(context).language} • ${AppLocalizations.of(context).appearance}',
                  color: gold,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProductSettingsScreen(),
                    ),
                  ),
                ),
                _MoreTile(
                  icon: Icons.card_giftcard_rounded,
                  label: 'ادعُ صديقًا واكتشف مكافآتك',
                  subtitle: 'كودك الشخصي • مشاركة الدعوة • سجل الاستحقاقات',
                  color: gold,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GrowthReferralScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _MoreTile(
                  icon: Icons.notifications_active_outlined,
                  label: context.strings.profile8ce3e0cc,
                  subtitle: context.strings.profile45d7fc3c,
                  color: gold,
                  onTap: () => context.push(AppRoutes.notifications),
                ),
                const SizedBox(height: 8),
                if (_approvedCaptainV21) ...[
                  _MoreTile(
                    icon: Icons.swap_horiz_rounded,
                    label: context.strings.profile9092f905,
                    subtitle: context.strings.profileed230578,
                    color: gold,
                    onTap: () async {
                      final id = SupabaseService.instance.currentUser?.id;
                      if (id != null) {
                        await VetoModeV21.openCaptain(GoRouter.of(context), id);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  _MoreTile(
                    icon: Icons.drive_eta_rounded,
                    label: context.strings.captainJoinTitle,
                    subtitle: context.strings.captainApplyAction,
                    color: gold,
                    onTap: () => context.push(AppRoutes.captainRegistration),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_staffVerifierV21) ...[
                  _MoreTile(
                    icon: Icons.verified_user_rounded,
                    label: context.strings.profiled2016401,
                    subtitle: context.strings.profile72081e80,
                    color: gold,
                    onTap: () {
                      VetoModeV21.customerView = false;
                      VetoModeV21.staffView = true;
                      context.go(AppRoutes.adminDashboard);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 13),
                Text(
                  context.strings.profile52233a23,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                _MoreTile(
                  icon: Icons.lightbulb_outline_rounded,
                  label: context.strings.profile5fe46ac6,
                  subtitle: context.strings.profile615e6b1d,
                  color: gold,
                  onTap: () => context.push(
                    '${AppRoutes.customerFeedback}?type=suggestion',
                  ),
                ),
                const SizedBox(height: 8),
                _MoreTile(
                  icon: Icons.report_problem_outlined,
                  label: context.strings.profile12506e99,
                  subtitle: context.strings.profileb0500561,
                  color: const Color(0xFFFF7773),
                  onTap: () => context.push(
                    '${AppRoutes.customerFeedback}?type=complaint',
                  ),
                ),
                const SizedBox(height: 8),
                _MoreTile(
                  icon: Icons.shield_outlined,
                  label: context.strings.profileaa6de5d4,
                  subtitle: context.strings.profile86c46fe1,
                  color: gold,
                  onTap: () => context.push(AppRoutes.legalCenter),
                ),
                const SizedBox(height: 8),
                _MoreTile(
                  icon: Icons.person_remove_outlined,
                  label: context.strings.profile24c192cb,
                  subtitle: context.strings.profile70224a06,
                  color: const Color(0xFFFF7773),
                  onTap: () => context.push(AppRoutes.deleteAccount),
                ),
                const SizedBox(height: 8),
                _MoreTile(
                  icon: Icons.logout_rounded,
                  label: context.strings.profile21f47442,
                  subtitle: context.strings.profileda1d0e35,
                  color: const Color(0xFFFF7773),
                  onTap: () async {
                    await SupabaseService.instance.signOut();
                    if (context.mounted) {
                      context.go(AppRoutes.signUpLoginScreen);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    context.strings.profile14009384,
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(31),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: color.withAlpha(153),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
