import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class AdminCaptainActionsV10 extends StatefulWidget {
  final String captainId, name;
  const AdminCaptainActionsV10({
    super.key,
    required this.captainId,
    required this.name,
  });
  @override
  State<AdminCaptainActionsV10> createState() => _AdminCaptainActionsV10State();
}

class _AdminCaptainActionsV10State extends State<AdminCaptainActionsV10> {
  final reason = TextEditingController(),
      custom = TextEditingController(text: '15');
  String action = 'notice';
  int seconds = 900;
  bool busy = false;
  String? error;
  String requestId = SupabaseService.newFinancialRequestId();
  @override
  void dispose() {
    reason.dispose();
    custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        22,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'إدارة الكابتن ${widget.name}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: action,
            items: const [
              DropdownMenuItem(value: 'notice', child: Text('إرسال تنبيه')),
              DropdownMenuItem(value: 'warning', child: Text('إنذار رسمي')),
              DropdownMenuItem(value: 'suspend', child: Text('إيقاف مؤقت')),
              DropdownMenuItem(value: 'ban', child: Text('حظر')),
              DropdownMenuItem(value: 'restore', child: Text('فك الإيقاف')),
              DropdownMenuItem(
                value: 'verify_identity',
                child: Text('توثيق الهوية بعد المراجعة'),
              ),
              DropdownMenuItem(
                value: 'verify_vehicle',
                child: Text('توثيق المركبة بعد المراجعة'),
              ),
              DropdownMenuItem(
                value: 'unverify_identity',
                child: Text('إلغاء توثيق الهوية'),
              ),
              DropdownMenuItem(
                value: 'unverify_vehicle',
                child: Text('إلغاء توثيق المركبة'),
              ),
            ],
            onChanged: busy
                ? null
                : (v) => setState(() {
                    action = v!;
                    requestId = SupabaseService.newFinancialRequestId();
                  }),
          ),
          if (action == 'suspend') ...[
            Wrap(
              spacing: 6,
              children: [
                for (final option in [
                  (900, '15 دقيقة'),
                  (1800, '30 دقيقة'),
                  (3600, 'ساعة'),
                  (86400, 'يوم'),
                ])
                  ChoiceChip(
                    label: Text(option.$2),
                    selected: seconds == option.$1,
                    onSelected: busy
                        ? null
                        : (_) => setState(() => seconds = option.$1),
                  ),
              ],
            ),
            TextField(
              controller: custom,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'مدة مخصصة بالدقائق',
              ),
              onChanged: (v) {
                final minutes = int.tryParse(v);
                if (minutes != null) seconds = minutes * 60;
              },
            ),
          ],
          TextField(
            controller: reason,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'السبب — مطلوب'),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (reason.text.trim().length < 3) {
                      setState(() => error = 'اكتب سببًا واضحًا');
                      return;
                    }
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await SupabaseService.instance.client
                          .rpc(
                            'admin_captain_action_v10',
                            params: {
                              'p_captain_id': widget.captainId,
                              'p_action': action,
                              'p_reason': reason.text.trim(),
                              'p_seconds': seconds,
                              'p_request_id': requestId,
                            },
                          )
                          .timeout(const Duration(seconds: 12));
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (_) {
                      if (mounted)
                        setState(
                          () => error = 'تعذر تنفيذ الإجراء. حاول مرة أخرى.',
                        );
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text(busy ? 'جارٍ التنفيذ…' : 'تنفيذ وتسجيل الإجراء'),
          ),
        ],
      ),
    ),
  );
}
