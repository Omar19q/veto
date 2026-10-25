import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/growth_service.dart';

/// Customer referral experience. Pure presentation; wallet awards always belong
/// to verified Supabase functions, never a client-side balance update.
class CustomerReferralCompactScreen extends StatefulWidget {
  const CustomerReferralCompactScreen({super.key, required this.service});

  final GrowthService service;

  @override
  State<CustomerReferralCompactScreen> createState() =>
      _CustomerReferralCompactScreenState();
}

class _CustomerReferralCompactScreenState
    extends State<CustomerReferralCompactScreen> {
  late Future<_ReferralSummary> _summary;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _summary = _load();
  }

  Future<_ReferralSummary> _load() async {
    final profile = await widget.service.profile();
    Map<String, dynamic> breakdown = {};
    try {
      breakdown = await widget.service.referralBreakdown();
    } catch (_) {
      // Treat figures as unavailable, not as a proven zero.
    }
    return _ReferralSummary(profile, breakdown);
  }

  void _refresh() => setState(() => _summary = _load());

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    _notice(_english ? 'Copied to clipboard' : 'اتنسخ بنجاح');
  }

  bool get _english => Localizations.localeOf(context).languageCode == 'en';

  Future<void> _share(String code) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final message = GrowthService.shareMessage(code);
    final url = Uri.https('wa.me', '/', {'text': message});
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        await _copy(message);
      }
    } catch (_) {
      try {
        await _copy(message);
      } catch (_) {
        _notice(_english ? 'Sharing is unavailable' : 'مقدرناش نشارك الكود دلوقتي');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _showQr(String code) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _english ? 'Scan to join VETO SANYA' : 'امسح الكود وسجّل في فيتو ثانية',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(
                data: GrowthService.referralLink(code).toString(),
                size: MediaQuery.sizeOf(context).width.clamp(160, 220).toDouble(),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(code, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _copy(GrowthService.referralLink(code).toString()),
                icon: const Icon(Icons.copy_rounded),
                label: Text(_english ? 'Copy invite link' : 'انسخ رابط الدعوة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDetails(_ReferralSummary info) async {
    final p = info.profile;
    final b = info.breakdown;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _english ? 'Your invitation activity' : 'تفاصيل دعواتك',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (b.isEmpty)
                Text(_english
                    ? 'Statistics are temporarily unavailable. Your rewards are safely managed by the server.'
                    : 'مش قادرين نعرض الإحصائيات دلوقتي. المكافآت بيحسبها النظام مش الموبايل.')
              else ...[
                _detailRow(_english ? 'Registered friends' : 'أصحابك اللي سجّلوا', b['registrations']),
                _detailRow(_english ? 'Qualified rides' : 'رحلات مؤهلة', b['qualified']),
                _detailRow(_english ? 'Awaiting eligibility' : 'لسه مستنيين أول رحلة', b['pending']),
                _detailRow(_english ? 'Due (EGP)' : 'مستحق (جنيه)', b['due']),
                _detailRow(_english ? 'Credited (EGP)' : 'اتضاف للمحفظة (جنيه)', b['paid']),
              ],
              if(p.containsKey('promotional_available')) _detailRow(_english?'Promotional credit (EGP)':'الرصيد الترويجي المتاح (جنيه)',p['promotional_available']),
              if(p.containsKey('due')) _detailRow(_english?'Rewards due (EGP)':'المكافآت المستحقة (جنيه)',p['due']),
              const SizedBox(height: 8),
              Text(
                p['enabled'] == true
                    ? (_english
                        ? 'Rewards are based on server campaign rules and verified completed rides.'
                        : 'المكافأة بتتضاف بعد رحلة مؤهلة ومؤكدة حسب شروط العرض.')
                    : (_english
                        ? 'Invitations are currently paused.'
                        : 'المكافآت متوقفة مؤقتًا من النظام.'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _refresh();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_english ? 'Refresh' : 'تحديث المكافآت'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, Object? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text('${value ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        centerTitle: true,
        title: Text(_english ? 'Invite a friend' : 'ادعُ صاحبك'),
        actions: [
          IconButton(
            tooltip: _english ? 'Refresh' : 'تحديث',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_ReferralSummary>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 36),
                    const SizedBox(height: 12),
                    Text(_english ? 'Could not load your invite' : 'مش قادرين نجيب كود الدعوة دلوقتي'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _refresh, child: Text(_english ? 'Try again' : 'حاول تاني')),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final info = snapshot.data!;
          final profile = info.profile;
          final enabled = profile['enabled'] == true;
          final code = profile['code']?.toString() ?? '';
          final displayCode = code.isNotEmpty ? code : '—';
          final reward = num.tryParse(
            profile['reward_for_first_completed_trip']?.toString() ?? '',
          );
          final registrations = info.breakdown['registrations'];
          final qualified = info.breakdown['qualified'];
          final earned = info.breakdown['paid'];
          final discount = num.tryParse(
            profile['invitee_first_discount_percent']?.toString() ?? '',
          );
          return LayoutBuilder(
            builder: (context, size) {
              final compact = size.maxHeight < 610;
              final edge = compact ? 14.0 : 20.0;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(edge, compact ? 6 : 12, edge, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: size.maxHeight - 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0B0F1A), Color(0xFF1E2640)],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFFFFC107).withValues(alpha: .35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .12),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(compact ? 16 : 22),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC107).withValues(alpha: .18),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.card_giftcard_rounded,
                                color: Color(0xFFFFC107),
                                size: 31,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reward != null && enabled
                                        ? (_english ? 'Earn ${reward.toStringAsFixed(0)} EGP' : 'اكسب ${reward.toStringAsFixed(0)} جنيه')
                                        : (_english ? 'Friends bring rewards' : 'الصحاب معاهم مكافآت'),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    enabled
                                        ? (_english ? 'When your friend completes an eligible ride' : 'لما صاحبك يكمّل أول رحلة مؤهلة')
                                        : (_english ? 'Rewards are currently paused' : 'العروض متوقفة مؤقتًا'),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? 12 : 18),
                      Text(
                        _english ? 'Your invitation code' : 'كود دعوتك',
                        style: theme.textTheme.titleSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 7),
                      Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                displayCode,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                              tooltip: _english ? 'Show QR code' : 'اعرض رمز QR',
                              onPressed: enabled && code.isNotEmpty ? () => _showQr(code) : null,
                              icon: const Icon(Icons.qr_code_rounded),
                            ),
                            IconButton.filledTonal(
                              tooltip: _english ? 'Copy code' : 'انسخ الكود',
                              onPressed: enabled && code.isNotEmpty ? () => _copy(code) : null,
                              icon: const Icon(Icons.copy_rounded),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? 10 : 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: enabled && code.isNotEmpty && !_sharing
                              ? () => _share(code)
                              : null,
                          icon: _sharing
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.share_rounded),
                          label: Text(_english ? 'Invite via WhatsApp' : 'ابعت الدعوة لصاحبك'),
                        ),
                      ),
                      SizedBox(height: compact ? 6 : 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.outlineVariant),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                        child: Row(
                          children: [
                            Expanded(child: _stat(
                              _english ? 'Joined' : 'سجّلوا',
                              registrations == null ? '—' : '$registrations', colors,
                            )),
                            Container(width: 1, height: 31, color: colors.outlineVariant),
                            Expanded(child: _stat(
                              _english ? 'Qualified' : 'أكملوا',
                              qualified == null ? '—' : '$qualified', colors,
                            )),
                            Container(width: 1, height: 31, color: colors.outlineVariant),
                            Expanded(child: _stat(
                              _english ? 'Credited' : 'اتضافلك',
                              earned == null ? '—' : _english ? '$earned EGP' : '$earned ج', colors,
                            )),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? 12 : 18),
                      Text(
                        _english ? 'How it works' : 'الموضوع سهل جدًا',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        discount != null && enabled
                            ? (_english
                                ? 'Share your code • Your friend joins • After an eligible completed ride, you earn your reward. Intro offer: ${discount.toStringAsFixed(0)}% when eligible.'
                                : 'ابعت الكود ← صاحبك يسجّل ← يكمّل رحلة مؤهلة ← مكافأتك تتضاف. وممكن يستفيد من خصم ${discount.toStringAsFixed(0)}% لو مؤهل.')
                            : (_english
                                ? 'Share your code → Your friend registers → They complete an eligible ride → Your reward is verified.'
                                : 'ابعت الكود ← صاحبك يسجّل ← يكمّل رحلة مؤهلة ← تابع استحقاق المكافأة.'),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: () => _showDetails(info),
                          icon: const Icon(Icons.receipt_long_outlined, size: 20),
                          label: Text(_english ? 'Rewards and status' : 'تفاصيل المكافآت والحالة'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _stat(String label, String value, ColorScheme colors) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w900, color: colors.primary,
      )),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

class _ReferralSummary {
  const _ReferralSummary(this.profile, this.breakdown);
  final Map<String, dynamic> profile;
  final Map<String, dynamic> breakdown;
}
