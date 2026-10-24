import '../../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:printing/printing.dart';
import '../../services/growth_service.dart';
import '../../services/supabase_service.dart';
import '../../services/growth_badge_pdf.dart';
import 'growth_zero_panel.dart';
import 'growth_incidents_screen.dart';
import 'growth_badge_placement.dart';
import '../../services/growth_install_referral.dart';
import '../../services/growth_referral_kind.dart';
import 'widgets/customer_referral_compact.dart';

const growthGold = Color(0xFFFFC534);
const growthBackground = Color(0xFF091827);

/// V62 customer welcome. This is a presentation layer, not a financial ledger.
/// Server RPCs decide whether invitation binding is eligible and which active
/// campaigns exist. One user gets one welcome decision across devices using
/// customers.onboarding_shown_at; exiting before a decision doesn't consume it.
class GrowthGiftSheet extends StatefulWidget {
  const GrowthGiftSheet({
    super.key,
    required this.service,
    this.customerId,
    this.initialName = '',
    this.canUseCode = true,
    this.requireName = false,
    this.onNameSaved,
  });

  final GrowthService service;
  final String? customerId;
  final String initialName;
  final bool canUseCode;
  final bool requireName;
  final ValueChanged<String>? onNameSaved;
  static bool _opening = false;
  // A successful, server-persisted decision is not reopened in this process,
  // even if a stale customer snapshot is displayed immediately afterwards.
  static final Set<String> _completedUsersThisProcess = <String>{};
  static final Set<String> _dismissedUsersThisProcess = <String>{};

  /// Runs only after the verified customer account has been loaded. The global
  /// VETO_GROWTH_PRODUCTION_APPROVED flag must NOT gate this read-only welcome
  /// UI: eligibility and benefit issuance remain guarded by database RPCs.
  static Future<void> maybeShow(
    BuildContext context, {
    Map<String, dynamic>? customer,
    ValueChanged<String>? onNameSaved,
  }) async {
    if (_opening || customer == null) return;
    if (customer['onboarding_shown_at'] != null) return;
    final trips = num.tryParse(customer['total_completed_trips']?.toString() ?? '') ?? 0;
    if (trips > 0) return; // No first-account promotion on existing riders.
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null || customer['user_id']?.toString() != userId ||
        _completedUsersThisProcess.contains(userId) ||
        _dismissedUsersThisProcess.contains(userId)) return;

    _opening = true;
    final service = GrowthService();
    try {
      bool canUseCode = false;
      try {
        canUseCode = await service.claimOnboarding();
      } catch (error) {
        debugPrint('Welcome eligibility unavailable: ${error.runtimeType}');
      }
      if (!context.mounted || SupabaseService.instance.currentUser?.id != userId) return;
      final emptyName = (customer['full_name']?.toString() ?? '').trim().isEmpty;
      final nameIncomplete = customer['name_onboarding_completed'] != true;
      // Existing names don't need a repeat welcome if code isn't eligible.
      if (!canUseCode && !emptyName && !nameIncomplete) return;
      final bool requireName = emptyName || nameIncomplete;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: !requireName,
        enableDrag: !requireName,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (_) => GrowthGiftSheet(
          service: service,
          customerId: customer['id']?.toString(),
          initialName: customer['full_name']?.toString() ?? '',
          canUseCode: canUseCode,
          requireName: requireName,
          onNameSaved: onNameSaved,
        ),
      );
      // Dismissing the presentation is not a financial eligibility decision.
      // Only a confirmed server decision marks onboarding as completed.
      _dismissedUsersThisProcess.add(userId);
    } finally {
      _opening = false;
    }
  }

  @override
  State<GrowthGiftSheet> createState() => _GrowthGiftSheetState();
}

class _GrowthGiftSheetState extends State<GrowthGiftSheet> {
  final code = TextEditingController();
  late final TextEditingController name;
  bool busy = false;
  late bool codeAvailable;
  bool checkingAvailability = false;
  bool success = false;
  String? error;
  Map<String, dynamic> terms = {};
  GrowthReferralKind kind = GrowthReferralKind.empty;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.initialName);
    codeAvailable = widget.canUseCode;
    widget.service.observe('onboarding_promo_shown');
    if (codeAvailable) {
      widget.service.call('growth_campaign_terms_v1').then((value) {
        if (mounted) setState(() => terms = value);
      }).catchError((Object error) {
        debugPrint('Campaign preview not available: ${error.runtimeType}');
      });
      GrowthInstallReferral.read().then((value) {
        if (mounted && value != null && code.text.isEmpty) {
          setState(() {
            code.text = value;
            kind = classifyGrowthReferral(value);
          });
        }
      }).catchError((Object error) {
        debugPrint('Optional install referral unavailable: ${error.runtimeType}');
      });
    }
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final clean = name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return;
    if (clean.length < 2 || clean.length > 80 || clean.contains(RegExp(r'[<>\u0000-\u001F]'))) {
      throw const FormatException('name_invalid');
    }
    if (widget.customerId == null) return; // Allows isolated widget tests.
    final uid = SupabaseService.instance.currentUser?.id;
    if (uid == null) throw StateError('authentication_required');
    // Both the account filter and Supabase RLS must accept the update.
    // Requiring a returned row prevents false 'saved' messaging.
    await SupabaseService.instance.client.from('customers')
      .update({'full_name': clean, 'name_onboarding_completed': true})
      .eq('id', widget.customerId!)
      .eq('user_id', uid)
      .select('id').single();
    widget.onNameSaved?.call(clean);
  }

  Future<void> _markSeen() async {
    if (widget.customerId == null) return;
    final uid = SupabaseService.instance.currentUser?.id;
    if (uid == null) throw StateError('authentication_required');
    await SupabaseService.instance.client.from('customers')
      .update({'onboarding_shown_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', widget.customerId!)
      .eq('user_id', uid)
      .select('id').single();
    GrowthGiftSheet._completedUsersThisProcess.add(uid);
  }

  /// Only the server determines whether referrals are enabled and the signed-in
  /// customer is entitled to choose an onboarding code. Never infer eligibility
  /// from the shape of the code, the device, or a client-side switch.
  Future<bool> _refreshCodeEligibility() async {
    if (checkingAvailability) return codeAvailable;
    setState(() => checkingAvailability = true);
    try {
      final active = await widget.service.claimOnboarding();
      if (!mounted) return false;
      setState(() { codeAvailable = active; checkingAvailability = false; });
      if (active) {
        try {
          final value = await widget.service.call('growth_campaign_terms_v1');
          if (mounted) setState(() => terms = value);
        } catch (error) {
          debugPrint('No active campaign to preview: ${error.runtimeType}');
        }
      }
      return active;
    } catch (error) {
      if (mounted) setState(() { checkingAvailability = false; });
      debugPrint('Referral eligibility refresh failed: ${error.runtimeType}');
      return false;
    }
  }

  Future<void> submit(bool skip) async {
    if (busy) return;
    final cleanName = name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (widget.requireName && cleanName.length < 2) {
      setState(() => error = context.strings.localeName.startsWith('en')
          ? 'Please enter your name to continue'
          : 'يرجى كتابة اسمك للمتابعة (حرفين على الأقل)');
      return;
    }
    final value = code.text.trim();
    if (!skip && (value.isEmpty || kind == GrowthReferralKind.invalid)) {
      setState(() => error = growthReferralHint(kind,
          english: context.strings.localeName.startsWith('en')));
      return;
    }
    if (!skip && !codeAvailable) {
      final available = await _refreshCodeEligibility();
      if (!mounted || !available) {
        if (mounted) setState(() => error =
          context.strings.welcomeCodeUnavailable);
        return;
      }
    }
    setState(() { busy = true; error = null; });
    try {
      await _saveName();
      if (codeAvailable) {
        // The server locks one enrollment per account across all devices.
        // An already-consumed invitation must never show a new success animation.
        final decision = await widget.service.bindDecision(skip ? null : value);
        if (decision['already_decided'] == true) {
          await _markSeen();
          if (mounted) Navigator.of(context).pop();
          return;
        }
      }
      await _markSeen();
      if (!mounted) return;
      if (skip) {
        Navigator.of(context).pop();
      } else {
        setState(() { success = true; busy = false; });
        HapticFeedback.lightImpact();
      }
    } on FormatException {
      if (mounted) setState(() { busy = false; error = context.strings.welcomeNameInvalid; });
    } catch (errorObject) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = skip
          ? 'تعذر حفظ اختيارك؛ حاول تاني عشان ما يظهرش الترحيب كل مرة.'
          : context.strings.welcomeConfirmFailed;
      });
      debugPrint('Welcome decision unavailable: ${errorObject.runtimeType}');
    }
  }

  List<num> get _activeDiscounts {
    final values = terms['discounts'];
    if (values is! List) return const <num>[];
    return values.map((v) => num.tryParse(v.toString()))
      .whereType<num>().where((v) => v > 0 && v <= 100 && v.isFinite)
      .toList(growable: false);
  }

  Widget _successView(bool english, ColorScheme colors, bool reduced) {
    final offers = _activeDiscounts;
    final isFriend = kind == GrowthReferralKind.friend ||
        kind == GrowthReferralKind.legacyCustomer;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: reduced ? Duration.zero : const Duration(milliseconds: 850),
          curve: Curves.elasticOut,
          builder: (context, t, child) => Transform.scale(scale: 0.55 + t * .45, child: child),
          child: Stack(alignment: Alignment.center, children: [
            Container(width: 128, height: 128,
              decoration: const BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0xFFFFEFAB), growthGold, Color(0xFFB97D0D)]))),
            SvgPicture.asset('assets/images/veto_sanya_logo_mark.svg', width: 79, height: 79),
          ]),
        ),
        const SizedBox(height: 18),
        Text(english ? 'Your invitation is confirmed!'
          : (name.text.trim().isNotEmpty
            ? 'مبروك يا ${name.text.trim()}! كودك اتسجل بنجاح 🎉'
            : 'مبروك! كودك اتسجل بنجاح 🎉'),
          textAlign: TextAlign.center, style: TextStyle(fontSize: 23,
            fontWeight: FontWeight.w900, color: colors.onSurface)),
        const SizedBox(height: 9),
        Text(english
          ? 'Benefits unlock only when each trip meets the current campaign terms.'
          : 'الهدايا بتتفعّل عند استيفاء شروط كل رحلة والعرض الساري، مش بمجرد كتابة الكود.',
          textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant, height: 1.55)),
        const SizedBox(height: 16),
        if (offers.isNotEmpty) ...[
          Text(english ? '${offers.length} potential ride offers' : '${offers.length} فرص للتوفير حسب الاستحقاق',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colors.primary)),
          const SizedBox(height: 8),
          ...offers.asMap().entries.map((entry) => Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: growthGold.withAlpha(40),
                child: Text('${entry.key + 1}', style: const TextStyle(color: growthBackground, fontWeight: FontWeight.w900))),
              title: Text(english ? '${entry.value}% possible discount' : 'خصم محتمل ${entry.value}%'),
              subtitle: Text(english ? 'Eligible rides only • subject to campaign limits'
                : 'على الرحلات المؤهلة فقط وضمن سقف الحملة'),
              trailing: const Icon(Icons.card_giftcard_rounded, color: growthGold),
            ),
          )),
        ] else
          Card(child: Padding(padding: const EdgeInsets.all(16),
            child: Text(english
              ? 'No active discount campaign is confirmed yet. Your code is saved, but no discount is promised.'
              : 'الكود اتسجل، لكن مفيش خصومات نشطة مؤكدة دلوقتي. مش هنحسب لك هدية قبل استحقاقها.',
              textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant)))),
        if (isFriend) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(english ? 'Your friend receives any applicable reward after a qualifying completed trip.'
            : 'صاحب كود الصديق يستحق مكافأته بعد رحلة مكتملة ومؤهلة فقط، حسب شروط الحملة.',
            textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(english ? 'Start my trip' : 'يلا نبدأ مشوارنا'),
        )),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final english = context.strings.localeName.startsWith('en');
    final colors = Theme.of(context).colorScheme;
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (success) return Directionality(
      textDirection: english ? TextDirection.ltr : TextDirection.rtl,
      child: SafeArea(child: _successView(english, colors, reduced)));
    final friend = kind == GrowthReferralKind.friend ||
        kind == GrowthReferralKind.legacyCustomer;
    final captain = kind == GrowthReferralKind.captain;
    final offer = friend
        ? (english ? 'A friend invited you 🎁' : 'صاحبك باعتلك مفاجأة 🎁')
        : captain
          ? (english ? 'Your captain has an invitation for you' : 'الكابتن مستنيك بمفاجأة 🎁')
          : (english ? 'Fast rides, smart prices' : 'مشوار أسرع... وتوفير أكبر');
    final explanation = friend
      ? (english ? 'Friend benefits apply after eligible rides, never just by sign-up.'
        : 'مزايا كود الصديق مرتبطة بشروط الرحلات المؤهلة، مش بالتسجيل بس.')
      : captain
        ? (english ? 'Captain code benefits follow the current offer and its limits.'
          : 'كود الكابتن بيشتغل حسب العرض المتاح وحدوده.')
        : (english ? 'Have a friend or captain code? Enter it to check your offer.'
          : 'معاك كود صديق أو كابتن؟ اكتبه وشوف العرض المتاح ليك.');
    return Directionality(
      textDirection: english ? TextDirection.ltr : TextDirection.rtl,
      child: SafeArea(child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child:
            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (!widget.requireName)
                Align(alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(context.strings.growtha3238c1d))),
              Center(child: Container(width: 46, height: 4,
                decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(30)))),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [growthBackground, Color(0xFF1A3846)]),
                  borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.all(22),
                child: Column(children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: reduced ? Duration.zero : const Duration(milliseconds: 650),
                    curve: Curves.easeOutBack,
                    builder: (_, t, child) => Transform.scale(scale: .7 + t * .3, child: child),
                    child: SvgPicture.asset('assets/images/veto_sanya_logo_mark.svg', width: 76, height: 76)),
                  const SizedBox(height: 8),
                  Text(english ? 'Welcome to VETO SANYA!' : 'أهلًا بيك في فيتو ثانية!',
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(offer, textAlign: TextAlign.center,
                    style: const TextStyle(color: growthGold, fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(english ? 'Your welcome, saved once per account'
                    : 'ترحيب خاص بيك، مرة واحدة لكل حساب',
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(english ? 'What should we call you?' : 'تحب نناديك بإيه؟',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: colors.onSurface)),
                  const SizedBox(width: 8),
                  if (widget.requireName)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        english ? 'Required' : 'شرط المتابعة',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: colors.primary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: name, enabled: !busy, maxLength: 80,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: english ? 'Name you prefer' : 'الاسم اللي تحب نناديك بيه',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
              ),
              const SizedBox(height: 5),
              Text(english ? 'Invitation code (optional)' : 'معاك كود دعوة من صديق أو كابتن؟',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: colors.onSurface)),
              const SizedBox(height: 5),
              Text(explanation, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12, height: 1.4)),
              const SizedBox(height: 10),
              TextField(
                controller: code, enabled: !busy,
                textCapitalization: TextCapitalization.characters, maxLength: 24,
                onChanged: (text) => setState(() {
                  kind = classifyGrowthReferral(text); error = null;
                }),
                decoration: InputDecoration(
                  hintText: english ? 'Enter a friend or captain code' : 'اكتب كود الدعوة هنا',
                  prefixIcon: const Icon(Icons.confirmation_number_outlined),
                  filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
              ),
              if (!codeAvailable) Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(english
                    ? 'Invitations are not active for this account yet. You can enter a code, but it cannot be applied until the server confirms eligibility.'
                    : 'تقدر تكتب الكود، لكن تفعيله يحتاج تأكيد من نظام العروض. مش هيتحسب أي خصم أو مكافأة قبل التأكيد.',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                  TextButton.icon(
                    onPressed: checkingAvailability || busy ? null : () async {
                      final active = await _refreshCodeEligibility();
                      if (mounted && active) setState(() => error = null);
                    },
                    icon: checkingAvailability
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(english ? 'Check activation' : 'تحديث حالة العرض'),
                  ),
                ]),
              ),
              if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10),
                child: Text(error!, style: TextStyle(color: colors.error))),
              const SizedBox(height: 4),
              SizedBox(height: 52, child: FilledButton.icon(
                onPressed: busy || checkingAvailability
                    ? null : () => submit(false),
                icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.redeem_rounded),
                label: Text(busy ? (english ? 'Checking...' : 'بنتأكد من كودك...')
                  : (english ? 'Verify invitation' : 'تأكيد كود الدعوة')),
              )),
              TextButton.icon(
                onPressed: busy ? null : () => submit(true),
                icon: const Icon(Icons.arrow_circle_right_outlined),
                label: Text(english ? 'Continue without code' : 'المتابعة بدون كود'),
              ),
            ]),
          ),
        ),
      )),
    );
  }
}

class GrowthReferralScreen extends StatefulWidget {
  const GrowthReferralScreen({super.key, this.captain = false, this.service});
  final bool captain;
  final GrowthService? service;
  @override
  State<GrowthReferralScreen> createState() => _GrowthReferralScreenState();
}

class _GrowthReferralScreenState extends State<GrowthReferralScreen> {
  late final GrowthService service = widget.service ?? GrowthService();
  late Future<Map<String, dynamic>> profile = service.profile(
    captain: widget.captain,
  );
  late Future<Map<String, dynamic>> breakdown = service.referralBreakdown(
    captain: widget.captain,
  );
  void refresh() => setState(() {
    profile = service.profile(captain: widget.captain);
    breakdown = service.referralBreakdown(captain: widget.captain);
  });
  Future<void> share(String code) async {
    final link = GrowthService.referralLink(code).toString();
    final message = widget.captain
        ? 'تعالى جرّب فيتو ثانية 🚗✨\nكود دعوة الكابتن: $code\nاكتب الكود عند التسجيل لمعرفة العروض المتاحة وقتها وشروطها.\n$link'
        : 'مشوارك الجاي أسهل مع فيتو ثانية 🚗✨\nكود دعوتي: $code\nاكتب الكود عند التسجيل لمعرفة المزايا المتاحة وشروط استحقاقها.\n$link';
    final url = Uri.https('wa.me', '/', {'text': message});
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب، تم نسخ رسالة الدعوة')),
      );
    }
  }

  Widget _referralMetric(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: Text(label)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ]),
  );

  @override
  Widget build(BuildContext context) => !widget.captain
    ? CustomerReferralCompactScreen(service: service)
    : Directionality(
    textDirection: Directionality.of(context),
    child: Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.captain ? context.strings.growthede87845 : context.strings.growthb7147d67),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: profile,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(context.strings.growth77ac862f),
                  TextButton(
                    onPressed: refresh,
                    child:  Text(context.strings.growth14d5786f),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final p = snapshot.data!;
          if (p['enabled'] != true) {
            final english = context.strings.localeName.startsWith('en');
            return Center(child: SingleChildScrollView(child: Padding(
              padding: const EdgeInsets.all(24), child: Column(
                mainAxisSize: MainAxisSize.min, children: [
                  SvgPicture.asset('assets/images/veto_sanya_logo_mark.svg',
                    width: 86, height: 86),
                  const SizedBox(height: 18),
                  Text(english ? 'Your invitations, all in one place'
                    : 'دعواتك ومكافآتك في مكان واحد',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(p['reason'] == 'captain_code_capacity_exhausted'
                    ? context.strings.captainCodeCapacityHelp
                    : (english ? 'Invitation rewards are currently paused by the service. No discounts or credits are awarded until activation.'
                      : 'نظام الدعوات متوقف مؤقتًا من إدارة العروض. هتقدر تشارك كودك وتتابع مكافآتك بمجرد تفعيله، ومش هتتحسب أي مكافأة قبل استيفاء شروطها.'),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(onPressed: refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(english ? 'Refresh status' : 'تحديث حالة الدعوات')),
                ],
              ),
            )));
          }
          final code = p['code'].toString();
          final link = GrowthService.referralLink(code).toString();
          return ListView(
            padding: EdgeInsets.all(24),
            children: [
              SvgPicture.asset(
                'assets/images/veto_sanya_logo_mark.svg',
                width: 76,
                height: 76,
              ),
              SizedBox(height: 16),
              Text(
                code,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: widget.captain ? 38 : 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Center(
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(12),
                  child: QrImageView(data: link, size: 232),
                ),
              ),
              SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => share(code),
                icon: Icon(Icons.share_outlined),
                label:  Text(context.strings.growthc24481f6),
              ),
              TextButton(
                onPressed: () => Clipboard.setData(ClipboardData(text: link)),
                child:  Text(context.strings.growthfef8e3c9),
              ),
              if (!widget.captain && p['friend_reward_v54'] == true)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(context.strings.localeName.startsWith('en')
                        ? 'Your friend may qualify for an introductory offer. Your referral reward is earned only after a qualifying completed ride under the campaign terms.'
                        : 'صديقك يقدر يستفيد من عرض أول رحلة لو كان متاحًا، ومكافأتك بتتحسب بعد رحلة مؤهلة فقط ووفق شروط الحملة.',
                      textAlign: TextAlign.center),
                  ),
                ),
              if (widget.captain) GrowthZeroPanel(service: service),
              if (widget.captain)
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GrowthIncidentsScreen(service: service),
                    ),
                  ),
                  child:  Text(context.strings.growthf1979292),
                ),
              if (widget.captain)
                OutlinedButton.icon(
                  onPressed: () =>
                      GrowthBadgeScreen.open(context, code, service),
                  icon: Icon(Icons.qr_code),
                  label:  Text(context.strings.growthc5cb135c),
                ),
              FutureBuilder<Map<String, dynamic>>(
                future: breakdown,
                builder: (context, result) {
                  if (result.hasError || !result.hasData) {
                    return const SizedBox.shrink(); // legacy statistics remain visible
                  }
                  final report = result.data!;
                  final english = context.strings.localeName.startsWith('en');
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(english ? 'Invitation earnings' : 'أرباح وإحالات الدعوة',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          _referralMetric(english ? 'Registered' : 'سجّلوا بالكود',
                              '${report['registrations'] ?? 0}'),
                          _referralMetric(english ? 'Qualified' : 'أكملوا رحلة مؤهلة',
                              '${report['qualified'] ?? 0}'),
                          _referralMetric(english ? 'Pending' : 'في انتظار الاستحقاق',
                              '${report['pending'] ?? 0}'),
                          _referralMetric(english ? 'Due (EGP)' : 'مستحق (جنيه)',
                              '${report['due'] ?? 0}'),
                          _referralMetric(english ? 'Credited (EGP)' : 'تم صرفه (جنيه)',
                              '${report['paid'] ?? 0}'),
                          if (widget.captain)
                            _referralMetric(english ? 'Badge status' : 'حالة البادج',
                              report['badge_activated'] == true
                                  ? (english ? 'Active' : 'مفعّل')
                                  : (english ? 'Not activated' : 'لم يُفعّل بعد')),
                          const SizedBox(height: 6),
                          Text(
                            english
                                ? 'Amounts are read from the server ledger, not estimated by the app.'
                                : 'الأرقام من دفتر الخادم، وليست حسابات تقديرية من التطبيق.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text(context.strings.growthInvitations((p['referral_count'] ?? 0).toString())),
                      Text(
                        context.strings.growthQualifiedFriends((p['qualified_count'] ?? 0).toString()),
                      ),
                      Text(
                        context.strings.growthQualifiedTrips((p['completed_referral_trips'] ?? 0).toString()),
                      ),
                      Text(context.strings.growthDue((p['due'] ?? 0).toString())),
                      Text(context.strings.growthPaid((p['paid'] ?? 0).toString())),
                      if (!widget.captain)
                        Text(
                          context.strings.growthCredit((p['promotional_available'] ?? 0).toString()),
                        ),
                      if (!widget.captain)
                         Text(
                          context.strings.growth965d621f,
                        ),
                       Text(
                        context.strings.growth1b588c8a,
                      ),
                    ],
                  ),
                ),
              ),
              for (final item in (p['history'] as List? ?? []))
                ListTile(
                  title: Text(context.strings.moneyValue(item['amount'].toString())),
                  subtitle: Text('${item['kind']} · ${item['status']}'),
                ),
              FutureBuilder<bool>(
                future: service.consent(),
                builder: (c, s) => SwitchListTile(
                  title:  Text(context.strings.growtha3856838),
                  subtitle: Text(
                    s.hasError
                        ? context.strings.growthe98a92b2
                        : context.strings.growthb31335b2,
                  ),
                  value: s.data ?? false,
                  onChanged: s.hasError
                      ? null
                      : (v) async {
                          try {
                            await service.setConsent(v);
                            if (mounted) setState(() {});
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(
                                  content: Text(context.strings.growth23af0f62),
                                ),
                              );
                            }
                          }
                        },
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: GrowthService.eventDeliveryFailures,
                builder: (_, count, _) => count == 0
                    ? SizedBox.shrink()
                    : Text(
                        context.strings.growthEventsFailed(count.toString()),
                      ),
              ),
              FutureBuilder<bool>(
                future: service.startupSound(),
                builder: (_, s) => SwitchListTile(
                  title:  Text(context.strings.growth3899eb0a),
                  subtitle: Text(
                    s.hasError
                        ? context.strings.growth9c2791a1
                        : context.strings.growthb85f466b,
                  ),
                  value: s.data ?? false,
                  onChanged: s.hasError
                      ? null
                      : (v) async {
                          try {
                            await service.setStartupSound(v);
                            if (mounted) setState(() {});
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(
                                  content: Text(context.strings.growthf15e1487),
                                ),
                              );
                            }
                          }
                        },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class GrowthBadgeScreen extends StatelessWidget {
  const GrowthBadgeScreen({
    super.key,
    required this.code,
    this.template = const {},
  });
  final String code;
  final Map<String, dynamic> template;
  static Future<void> open(
    BuildContext context,
    String code,
    GrowthService service,
  ) async {
    try {
      // Badge printing/activation is distinct from launching or pausing a
      // marketing campaign. Never hide a captain's badge because the generic
      // badge campaign flag is currently off on Staging.
      final status = await service.call('v52_my_badge_status');
      // The referral campaign flag may be paused even though this captain
      // already owns a unique badge. Read the owner's code from the signed-in
      // server account instead of requiring an active promotional campaign.
      String? ownedCode;
      try {
        final authenticated = await service.profile(captain: true);
        ownedCode = authenticated['code']?.toString();
      } catch (_) { /* the signed-in breakdown still enforces owner identity */ }
      if (ownedCode == null || ownedCode.isEmpty) {
        final breakdown = await service.referralBreakdown(captain: true);
        ownedCode = breakdown['code']?.toString();
      }
      if (ownedCode != code || !GrowthBadgePdf.validCode(code)) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('كود البادج غير مطابق لحساب الكابتن الحالي. حدّث الصفحة.')),
        );
        return;
      }
      if (status['approved'] != true) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لازم يتم اعتماد حساب الكابتن أولًا قبل طباعة البادج')),
        );
        return;
      }
      Map<String, dynamic> template = <String, dynamic>{'title': 'VETO SANYA'};
      try {
        final serverTemplate = await service.call('growth_badge_template_v1');
        template.addAll(serverTemplate);
      } catch (_) {
        // Optional campaign template; V52 owns actual activation.
      }
      if (!context.mounted) return;
      await Navigator.push(context,
        MaterialPageRoute(builder: (_) => GrowthBadgeScreen(code: code, template: template)));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر قراءة حالة البادج. جرّب مرة أخرى بعد التأكد من الاتصال')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: Directionality.of(context),
    child: Scaffold(
      appBar: AppBar(title:  Text(context.strings.growth75bc722a)),
      body: ListView(
        padding: EdgeInsets.all(24),
        children: [
           Text(
            context.strings.growthc12b43ff,
          ),
          const SizedBox(height: 14),
          FutureBuilder<Map<String, dynamic>>(
            future: GrowthService().call('v52_my_badge_status'),
            builder: (ctx, snapshot) {
              if (!snapshot.hasData) return Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(snapshot.hasError
                  ? 'تعذر تحميل حالة التفعيل. تأكد من إعداد نظام البادج.'
                  : 'جارِ قراءة حالة تفعيل البادج...'),
              ));
              final info = snapshot.data!;
              final activated = info['activated'] == true;
              return Card(child: Padding(padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(activated ? Icons.verified : Icons.pending_actions,
                      color: activated ? Colors.green : Theme.of(ctx).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(activated ? 'بادجك مفعّل وجاهز للإحالات'
                        : 'فعّل بادجك في 3 خطوات',
                      style: Theme.of(ctx).textTheme.titleMedium)),
                  ]),
                  const SizedBox(height: 12),
                  Text('1. اطبع ${info['print_copies'] ?? 2} نسخة ألوان بمقاس A4 أفقي في أي مكتبة طباعة.'),
                  const SizedBox(height: 7),
                  Text('2. توجّه إلى ${info['location'] ?? 'نقطة التفعيل'}.'),
                  Text('${info['days'] ?? 'يوميًا'} · من ${info['opens'] ?? '4 عصرًا'} إلى ${info['closes'] ?? '12 بالليل'}.'),
                  const SizedBox(height: 7),
                  const Text('3. هنركّب لك البادج، وبعدها الأدمن يفعّله على حسابك. مش محتاج تضغط تأكيد بنفسك.'),
                  if (info['required'] == true && !activated)
                    const Padding(padding: EdgeInsets.only(top: 12),
                      child: Text('استقبال الطلبات يتطلب تفعيل البادج من الإدارة أولًا.')),
                  if (activated)
                    const Padding(padding: EdgeInsets.only(top: 8),
                      child: Text('إحالاتك ومكافآتك تظهر في صفحة الدعوات والأرباح، والمكافآت الجديدة تُضاف لرصيدك وفق شروط العرض.')),
                ])));
            },
          ),
          const SizedBox(height: 16),
          GrowthBadgePlacement(),
          if (template['placement'] != null) Text('${template['placement']}'),
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                SvgPicture.asset(
                  'assets/images/veto_sanya_logo_mark.svg',
                  width: 80,
                  height: 80,
                ),
                Text(
                  template['title']?.toString() ?? 'VETO SANYA',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                  ),
                ),
                QrImageView(
                  data: GrowthService.referralLink(code).toString(),
                  size: (MediaQuery.sizeOf(context).width - 120).clamp(200.0, 300.0).toDouble(),
                ),
                Text(
                  context.strings.growthCode(code),
                  style: TextStyle(color: Colors.black, fontSize: 24),
                ),
                 Text(
                  context.strings.growthd0195c3b,
                  style: TextStyle(color: Colors.black),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          FilledButton.icon(
            icon: Icon(Icons.print),
            label:  Text(context.strings.growtha660bd6f),
            onPressed: () => Printing.layoutPdf(
              onLayout: (_) => GrowthBadgePdf.buildA4(
                code,
                title: template['title']?.toString() ?? 'VETO SANYA',
              ),
            ),
          ),
          OutlinedButton.icon(
            icon: Icon(Icons.print),
            label:  Text(context.strings.growth50f5b043),
            onPressed: () => Printing.layoutPdf(
              onLayout: (_) => GrowthBadgePdf.buildA4(
                code,
                motorcycle: true,
                title: template['title']?.toString() ?? 'VETO SANYA',
              ),
            ),
          ),
           Text(
            context.strings.growthf12097cd,
          ),
        ],
      ),
    ),
  );
}
