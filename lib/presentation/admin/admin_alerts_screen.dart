import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/admin_theme.dart';
import 'package:go_router/go_router.dart';

import '../../services/supabase_service.dart';

class AdminAlertsScreen extends StatefulWidget {
  const AdminAlertsScreen({super.key});
  @override
  State<AdminAlertsScreen> createState() => _AdminAlertsScreenState();
}

class _AdminAlertsScreenState extends State<AdminAlertsScreen> {
  final _db = SupabaseService.instance.client;
  List<Map<String, dynamic>> _alerts = [];
  TripRealtimeLease? _channel;
  bool _loading = true, _working = false, _hasMore = false;
  String? _error;
  String _filter = 'open';
  int _limit = 50;
  static final _labels = {
    'late_arrival': 'تأخير في الوصول',
    'low_rating': 'تقييم ضعيف',
    'appeal': 'التماس من الكابتن',
  };
  static final _statuses = {
    'open': 'جديد',
    'warned': 'تم توجيه تحذير',
    'banned': 'تم الحظر',
    'dismissed': 'تم الحفظ',
  };
  @override
  void initState() {
    super.initState();
    _load();
    _channel = SupabaseService.instance.subscribeToScaleAdminPulse(_load);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  bool _again = false;
  Future<void> _load() async {
    if (_working) {
      _again = true;
      return;
    }
    _working = true;
    final filter = _filter;
    final limit = _limit;
    try {
      final rows = await _db
          .from('admin_alerts')
          .select('*,captains(full_name,phone)')
          .eq('status', filter)
          .order('created_at', ascending: false)
          .order('id')
          .limit(limit + 1);
      if (mounted && filter == _filter)
        setState(() {
          _alerts = List<Map<String, dynamic>>.from(rows.take(limit));
          _hasMore = rows.length > limit;
          _error = null;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل التنبيهات. تأكد من الاتصال وتطبيق SQL الجديد.';
        });
    } finally {
      _working = false;
      if (_again && mounted) {
        _again = false;
        unawaited(_load());
      }
    }
  }

  String _time(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'غير مسجل';
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _review(Map<String, dynamic> alert) async {
    final captain = alert['captains'] as Map? ?? {};
    final evidence = alert['evidence'] as Map? ?? {};
    var action = 'warn';
    var minutes = 15;
    var sending = false;
    final reason = TextEditingController(
      text: alert['kind'] == 'appeal'
          ? 'تمت مراجعة الالتماس بواسطة الإدارة'
          : alert['reason']?.toString() ?? '',
    );
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: Text('مراجعة ${captain['full_name'] ?? 'الكابتن'}'),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert['reason']?.toString() ?? ''),
                  SizedBox(height: 12),
                  if (evidence['elapsed_minutes'] is num)
                    Text(
                      'الوقت المسجل: ${(evidence['elapsed_minutes'] as num).toStringAsFixed(1)} دقيقة',
                    ),
                  if (evidence['threshold_minutes'] != null)
                    Text('حد التنبيه: ${evidence['threshold_minutes']} دقيقة'),
                  if (evidence['stars'] != null)
                    Text('تقييم العميل: ${evidence['stars']} نجمة'),
                  if (evidence['comment'] != null)
                    Text('تعليق العميل: ${evidence['comment']}'),
                  SizedBox(height: 12),
                  Text(
                    'التنبيه يحتاج مراجعة ظروف الرحلة. التأخير أو التقييم وحده مش دليل نهائي.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                  if (alert['trip_id'] != null)
                    TextButton.icon(
                      onPressed: sending
                          ? null
                          : () {
                              Navigator.pop(dialogContext);
                              context.push(
                                '/admin/trip-details?tripId=${alert['trip_id']}',
                              );
                            },
                      icon: Icon(Icons.route),
                      label: Text('شوف الرحلة والشات'),
                    ),
                  if (alert['status'] == 'open') ...[
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: action,
                      decoration: InputDecoration(labelText: 'قرار الإدارة'),
                      items: [
                        DropdownMenuItem(
                          value: 'warn',
                          child: Text('توجيه تحذير'),
                        ),
                        DropdownMenuItem(value: 'ban', child: Text('حظر مؤقت')),
                        DropdownMenuItem(
                          value: 'dismiss',
                          child: Text('حفظ التنبيه دون عقوبة'),
                        ),
                      ],
                      onChanged: sending
                          ? null
                          : (value) => setDialog(() => action = value!),
                    ),
                    if (action == 'ban')
                      Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: DropdownButtonFormField<int>(
                          initialValue: minutes,
                          decoration: InputDecoration(labelText: 'مدة الحظر'),
                          items: [
                            DropdownMenuItem(
                              value: 15,
                              child: Text('15 دقيقة'),
                            ),
                            DropdownMenuItem(value: 60, child: Text('ساعة')),
                            DropdownMenuItem(value: 1440, child: Text('يوم')),
                          ],
                          onChanged: sending
                              ? null
                              : (value) => setDialog(() => minutes = value!),
                        ),
                      ),
                    SizedBox(height: 12),
                    TextField(
                      controller: reason,
                      maxLength: 500,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'السبب اللي هيظهر للكابتن',
                      ),
                    ),
                  ] else
                    Text(
                      'الإجراء: ${_statuses[alert['status']]}\nالسبب: ${alert['action_reason'] ?? 'غير مسجل'}',
                    ),
                  if (error != null)
                    Text(error!, style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(dialogContext),
              child: Text('رجوع'),
            ),
            if (alert['status'] == 'open')
              FilledButton(
                onPressed: sending
                    ? null
                    : () async {
                        if (reason.text.trim().length < 5) {
                          setDialog(
                            () => error = 'اكتب سببًا من 5 حروف على الأقل.',
                          );
                          return;
                        }
                        setDialog(() {
                          sending = true;
                          error = null;
                        });
                        try {
                          await _db.rpc(
                            'admin_handle_captain_alert',
                            params: {
                              'p_alert_id': alert['id'],
                              'p_action': action,
                              'p_reason': reason.text.trim(),
                              'p_minutes': action == 'ban' ? minutes : null,
                            },
                          );
                          if (dialogContext.mounted)
                            Navigator.pop(dialogContext);
                          await _load();
                        } catch (_) {
                          if (dialogContext.mounted)
                            setDialog(() {
                              sending = false;
                              error = 'تعذر حفظ القرار. جرّب تاني.';
                            });
                        }
                      },
                child: Text(sending ? 'جارٍ الحفظ' : 'تطبيق القرار'),
              ),
          ],
        ),
      ),
    );
    reason.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AdminTheme.theme,
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AdminTheme.background,
        appBar: AppBar(
          title: Text('الرقابة وتنبيهات الكباتن'),
          actions: [IconButton(onPressed: _load, icon: Icon(Icons.refresh))],
        ),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                initialValue: _filter,
                decoration: InputDecoration(labelText: 'عرض التنبيهات'),
                items: _statuses.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _filter = value!;
                    _limit = 50;
                    _loading = true;
                  });
                  _load();
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: EdgeInsets.all(12),
                child: Text(_error!, style: TextStyle(color: Colors.orange)),
              ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        physics: AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _alerts.isEmpty
                            ? 1
                            : _alerts.length + (_hasMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (_alerts.isEmpty)
                            return Padding(
                              padding: EdgeInsets.all(50),
                              child: Center(
                                child: Text('مفيش تنبيهات في القائمة دي.'),
                              ),
                            );
                          if (i == _alerts.length)
                            return TextButton(
                              onPressed: () {
                                _limit += 50;
                                _load();
                              },
                              child: Text('تحميل المزيد'),
                            );
                          final alert = _alerts[i];
                          final captain = alert['captains'] as Map? ?? {};
                          final appeal = alert['kind'] == 'appeal';
                          return Card(
                            margin: EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor: appeal
                                    ? Colors.teal.withAlpha(40)
                                    : Colors.orange.withAlpha(40),
                                child: Icon(
                                  appeal
                                      ? Icons.support_agent
                                      : Icons.warning_amber_rounded,
                                  color: appeal
                                      ? Colors.tealAccent
                                      : Colors.orange,
                                ),
                              ),
                              title: Text(
                                '${_labels[alert['kind']] ?? alert['kind']} — ${captain['full_name'] ?? 'كابتن'}',
                              ),
                              subtitle: Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  '${alert['reason']}\n${_time(alert['created_at'])}',
                                ),
                              ),
                              trailing: Icon(Icons.chevron_left),
                              onTap: () => _review(alert),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
