import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/app_sound_service.dart';
import '../../services/staff_access_v16.dart';
import '../../services/supabase_service.dart';
import '../../services/growth_service.dart';
import '../../services/phone_identity.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'team_chat_screen_v16.dart';

/// Minimal separate work desk for owner-authorized verification-only staff.
/// All permission checks and code assignment are validated by the backend.
class VerificationDeskV22 extends StatefulWidget {
  const VerificationDeskV22({super.key});
  @override
  State<VerificationDeskV22> createState() => _VerificationDeskV22State();
}

class _VerificationDeskV22State extends State<VerificationDeskV22>
    with WidgetsBindingObserver {
  RealtimeChannel? _channel;
  Timer? _refreshTimer;
  Timer? _secondTimer;
  bool _busy = false;
  bool _loading = true;
  bool _authorized = false;
  String? _error;
  bool _showTeamChat = false;
  String? _quickRequestId;
  List<Map<String, dynamic>> _requests = [];
  Map<String, dynamic>? _shift;
  int _secondsRemaining = 0;
  int _secondsToStart = 0;
  final Set<String> _alerted = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _channel = SupabaseService.instance.subscribeToVerificationRequests(
      (_) => _refresh(),
    );
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _refresh(),
    );
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) _secondsRemaining--;
        if (_secondsToStart > 0) _secondsToStart--;
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _secondTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    try {
      final access = await StaffAccessV16.load();
      if (!access.active ||
          !access.can('verification.view') ||
          !access.can('verification.manage')) {
        if (mounted)
          setState(() {
            _authorized = false;
            _loading = false;
            _requests = [];
            _quickRequestId = null;
          });
        return;
      }
      final client = Supabase.instance.client;
      final shiftRaw = await client.rpc('v22_my_verification_shift');
      final shift = shiftRaw is Map
          ? Map<String, dynamic>.from(shiftRaw)
          : <String, dynamic>{};
      final rows = await client
          .from('verification_requests')
          .select('id,phone,status,created_at,code,expires_at')
          .inFilter('status', ['pending', 'code_sent'])
          .order('created_at', ascending: true)
          .limit(80);
      final pendingIds = rows
          .where((r) => r['status'] == 'pending')
          .map((r) => r['id'].toString())
          .toSet();
      if (!mounted) return;
      final newlyArrived = pendingIds.difference(_alerted);
      _alerted.addAll(pendingIds);
      if (_alerted.length > 500) _alerted.clear();
      setState(() {
        _loading = false;
        _authorized = true;
        _requests = List<Map<String, dynamic>>.from(rows);
        _shift = shift;
        _secondsRemaining = (shift['seconds_remaining'] as num?)?.toInt() ?? 0;
        _secondsToStart = (shift['seconds_to_start'] as num?)?.toInt() ?? 0;
        _error = null;
        if (_quickRequestId != null && !pendingIds.contains(_quickRequestId)) {
          _quickRequestId = null;
        } else if (newlyArrived.isNotEmpty && !_showTeamChat) {
          _quickRequestId = newlyArrived.first;
        }
      });
      if (newlyArrived.isNotEmpty) {
        try {
          await HapticFeedback.mediumImpact();
        } catch (_) {}
        await AppSoundService.instance.playVerificationAlert();
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error =
              'تعذر تحميل الطلبات أو المواعيد. راجع SQL V22 واتصال الإنترنت.';
        });
    }
  }

  String _clock(int seconds) {
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _validPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('20') && digits.length == 12) return digits;
    if (RegExp(r'^01[0125]\d{8}$').hasMatch(digits))
      return '20${digits.substring(1)}';
    if (GrowthService.buildEnabled && input.trim().startsWith('+')) {
      try {
        return PhoneIdentity.parse(input, IsoCode.EG).e164.substring(1);
      } catch (_) {
        return '';
      }
    }
    return '';
  }

  Future<void> _openWhatsapp(String rawPhone, String code) async {
    final phone = _validPhone(rawPhone);
    if (phone.isEmpty || !RegExp(r'^\d{4}$').hasMatch(code)) {
      if (mounted)
        setState(() => _error = 'رقم الهاتف أو كود التحقق غير صالح.');
      return;
    }
    final text =
        'أهلًا بك في VETO SANYA 👋\nرمز التحقق الخاص بطلبك: $code\nصالح لمدة 10 دقائق. من فضلك لا تشاركه مع أي شخص.';
    final url = Uri.https('wa.me', '/$phone', {'text': text});
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
        mounted) {
      setState(() => _error = 'تم تجهيز الكود، لكن تعذر فتح واتساب.');
    }
  }

  Future<void> _generate(Map<String, dynamic> request) async {
    if (_busy) return;
    if (_secondsRemaining <= 0) {
      setState(
        () => _error =
            'إنشاء الأكواد متوقف خارج وقت الوردية. اطلب من الأونر مراجعة ساعات العمل من إدارة الفريق.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Generated and assigned atomically by the authorized server RPC.
      final code = await Supabase.instance.client.rpc(
        'v22_generate_verification_code',
        params: {'p_request_id': request['id']},
      );
      if (!mounted) return;
      setState(() => _quickRequestId = null);
      await _openWhatsapp(request['phone']?.toString() ?? '', code.toString());
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'تعذر إنشاء الكود. ربما انتهت الوردية أو تم التعامل مع الطلب بالفعل.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
      if (mounted) _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showTeamChat) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showTeamChat = false),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('العودة لطلبات التحقق'),
              ),
            ),
          ),
          const Expanded(child: TeamChatScreenV16()),
        ],
      );
    }
    final pending = _requests.where((r) => r['status'] == 'pending').toList();
    final active = _requests.where((r) => r['status'] == 'code_sent').toList();
    final quick = _quickRequestId == null
        ? null
        : (() {
            for (final row in pending) {
              if (row['id']?.toString() == _quickRequestId) return row;
            }
            return null;
          })();
    final quickOverlay = quick == null
        ? null
        : Positioned.fill(
            child: Container(
              color: const Color(0xB8091224),
              alignment: Alignment.center,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 470),
                    child: Card(
                      color: const Color(0xFF202C4A),
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Color(0xFFFFC107)),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: IconButton(
                                tooltip: 'تخطي العرض فقط - الطلب سيبقى في قائمة التحقق',
                                icon: const Icon(Icons.close_rounded, color: Colors.white),
                                onPressed: () => setState(() => _quickRequestId = null),
                              ),
                            ),
                            const Icon(
                              Icons.verified_user_rounded,
                              color: Color(0xFFFFC107),
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'طلب تحقق سريع جديد',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'عميل جديد في انتظار كود التحقق',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 10),
                            SelectableText(
                              quick['phone']?.toString() ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFFF9A9A),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (_secondsRemaining <= 0)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'مش هتقدر تصدر كود قبل ضبط مواعيد ورديتك من الأونر.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            FilledButton.icon(
                              onPressed: _busy || _secondsRemaining <= 0
                                  ? null
                                  : () => _generate(quick),
                              icon: const Icon(Icons.auto_awesome_rounded),
                              label: Text(
                                _secondsRemaining > 0
                                    ? 'إنشاء كود وفتح واتساب'
                                    : 'خارج وقت الوردية',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC107),
                                foregroundColor: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _quickRequestId = null),
                              child: const Text(
                                'عرض الطلبات كلها',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'مكتب التحقق السريع',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'تابع طلبات التحقق أولًا بأول، وجهّز الكود بنقرة واحدة، ثم أرسله للعميل عبر واتساب.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _authorized
                      ? () => setState(() {
                          _showTeamChat = true;
                          _quickRequestId = null;
                        })
                      : null,
                  icon: const Icon(Icons.forum_rounded),
                  label: const Text('محادثات الفريق • رسائل ومجموعات'),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              color: Color(0xFFFFBC08),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _shift == null || _shift!['configured'] != true
                                    ? 'مواعيد عملك لم تُحدَّد بعد'
                                    : _secondsRemaining > 0
                                    ? 'أنت الآن في وقت العمل'
                                    : 'خارج ساعات العمل',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _secondsRemaining > 0
                              ? _clock(_secondsRemaining)
                              : _secondsToStart > 0
                              ? 'تبدأ الوردية القادمة بعد ${_clock(_secondsToStart)}'
                              : 'اسأل الإدارة عن جدول ورديتك',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFFBC08),
                          ),
                        ),
                        const Text(
                          'الوقت المتبقي من الوردية • بتوقيت القاهرة',
                          style: TextStyle(fontSize: 12),
                        ),
                        if (_secondsRemaining <= 0)
                          const Padding(
                            padding: EdgeInsets.only(top: 9),
                            child: Text(
                              'زر إنشاء الكود يتاح وقت الوردية فقط. إذا لم تُحدد مواعيدك بعد، اطلب من الأونر ضبطها في إدارة الفريق.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFE8B45B),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (_error != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                if (_loading) const Center(child: CircularProgressIndicator()),
                if (!_loading && !_authorized)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.lock_outline),
                      title: Text('حساب التحقق غير مفعل'),
                      subtitle: Text('اطلب من الأونر تفعيل صلاحيات التحقق.'),
                    ),
                  ),
                if (_authorized) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'طلبات جديدة (${pending.length})',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  if (pending.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline),
                        title: Text('لا توجد طلبات جديدة الآن'),
                        subtitle: Text('ستظهر هنا تلقائيًا عند وصولها.'),
                      ),
                    ),
                  for (final req in pending) _requestCard(req, true),
                  const SizedBox(height: 12),
                  Text(
                    'أكواد جاهزة للإرسال (${active.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  for (final req in active) _requestCard(req, false),
                ],
              ],
            ),
          ),
          if (quickOverlay != null) quickOverlay,
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> req, bool pending) {
    final phone = req['phone']?.toString() ?? '';
    final code = req['code']?.toString() ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.phone_android_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    phone,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: phone)),
                  icon: const Icon(Icons.copy_rounded),
                  tooltip: 'نسخ الرقم',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (pending)
              FilledButton.icon(
                onPressed: _busy || _secondsRemaining <= 0
                    ? null
                    : () => _generate(req),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('إنشاء كود من 4 أرقام وإرساله على واتساب'),
              )
            else ...[
              Text(
                'كود هذا الطلب: $code',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _openWhatsapp(phone, code),
                icon: const Icon(Icons.send_rounded),
                label: const Text('فتح واتساب لإرسال الكود'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
