import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/staff_access_v16.dart';
import '../../services/veto_mode_v21.dart';

class StaffLoginV16 extends StatefulWidget {
  const StaffLoginV16({super.key});
  @override
  State<StaffLoginV16> createState() => _StaffLoginV16State();
}

class _StaffLoginV16State extends State<StaffLoginV16> {
  final _phone = TextEditingController(), _code = TextEditingController();
  bool _busy = false, _sent = false;
  String? _requestId;
  String? _message;
  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _perform() async {
    if (_busy) return;
    if (!RegExp(r'^01[0125]\d{8}$').hasMatch(_phone.text.trim())) {
      setState(() => _message = 'أدخل رقم الهاتف المصري المضاف بواسطة الأونر.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (!_sent) {
        final request = await SupabaseService.instance.createVerificationRequest(
          _phone.text.trim(),
        );
        final id = request['request_id']?.toString();
        if (id == null || id.isEmpty) throw StateError('server_unavailable');
        if (mounted) setState(() { _sent = true; _requestId = id; _code.clear(); });
        return;
      }
      final client = Supabase.instance.client;
      final response = await client.functions.invoke(
        'staff-code-login',
        body: {'phone': _phone.text.trim(), 'code': _code.text.trim(), 'request_id': _requestId},
      );
      final data = response.data;
      if (data is! Map) throw StateError('server_unavailable');
      if (data['success'] != true) {
        final reason = data['error']?.toString() ?? 'verification_invalid';
        final remaining = data['remaining'];
        throw StateError(remaining is int ? '$reason:$remaining' : reason);
      }
      if (data['email'] is! String || data['token'] is! String) {
        throw StateError('server_unavailable');
      }
      await client.auth.verifyOTP(
        email: data['email'],
        token: data['token'],
        type: OtpType.magiclink,
      );
      await SupabaseService.instance.activateSessionV25();
      final access = await StaffAccessV16.load();
      if (!access.active) {
        await client.auth.signOut();
        throw StateError('staff_unavailable');
      }
      VetoModeV21.staffView = true;
      VetoModeV21.customerView = false;
      if (mounted) context.go('/admin/dashboard');
    } catch (e) {
      if (mounted) {
        final reason = e.toString();
        final details = reason.contains('attempts_exhausted')
            ? 'انتهت محاولات الكود الحالي. اطلب من الأونر إلغاء طلب التحقق المنتهي من لوحة الإدارة قبل طلب كود جديد.'
            : reason.contains('verification_not_ready')
            ? 'الإدارة لم تسجل الكود لهذا الطلب بعد. انتظر رسالة الكود ثم حاول مجددًا.'
            : reason.contains('wrong_code')
            ? 'الكود غير مطابق للطلب الحالي. تأكد من آخر كود أرسلته الإدارة.'
            : reason.contains('verification_expired')
            ? 'انتهت صلاحية الطلب؛ اطلب من الإدارة إلغاء الطلب القديم أولًا إذا تعذر إنشاء جديد.'
            : reason.contains('login_rate_limit')
            ? 'محاولات كثيرة. أعد المحاولة لاحقًا.'
            : reason.contains('server_not_configured') ||
                reason.contains('server_unavailable') ||
                reason.contains('staff_login_unavailable') ||
                reason.contains('FunctionException') ||
                reason.contains('function not found')
            ? 'خدمة دخول الفريق غير متاحة. راجع تثبيت V16 SQL ووظيفة staff-code-login.'
            : reason.contains('staff_login_retry')
            ? 'تعذر استكمال الجلسة. اطلب كود تحقق جديدًا وحاول مرة أخرى.'
            : 'الرقم أو الكود غير صحيح، أو حساب الموظف غير مفعل بواسطة الأونر.';
        setState(() => _message = details);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('دخول فريق VETO')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.badge_outlined,
                size: 64,
                color: Color(0xFFD4AF37),
              ),
              const SizedBox(height: 20),
              const Text(
                'رقم عملك هو هويتك',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Text(
                'استخدم الرقم المضاف بواسطة الأونر. سيصلك كود التحقق عبر آلية واتساب المعتمدة.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _phone,
                enabled: !_sent && !_busy,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
              ),
              if (_sent && _requestId != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('رقم طلب التحقق: ${_requestId!.substring(0, 8)}',
                    textAlign: TextAlign.center),
                ),
              if (_sent)
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(labelText: 'كود التحقق'),
                ),
              if (_message != null)
                Text(_message!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _perform,
                child: Text(
                  _busy
                      ? 'جارٍ التحقق…'
                      : _sent
                      ? 'دخول آمن'
                      : 'طلب كود التحقق',
                ),
              ),
              if (_sent)
                TextButton(
                  onPressed: _busy ? null : () => setState(() { _sent = false; _requestId = null; _code.clear(); _message = null; }),
                  child: const Text('تغيير الرقم أو طلب كود جديد'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
