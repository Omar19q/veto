import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';
import '../../theme/admin_theme.dart';

/// Read-only reports. Financial amounts are summed from completed trip invoices;
/// claims paid to Vodafone Cash are displayed separately from app wallets.
class AdminReportsPanel extends StatefulWidget {
  const AdminReportsPanel({super.key});
  @override
  State<AdminReportsPanel> createState() => _AdminReportsPanelState();
}

class _AdminReportsPanelState extends State<AdminReportsPanel> {
  DateTime _start = DateUtils.dateOnly(DateTime.now());
  DateTime _end = DateUtils.dateOnly(DateTime.now());
  String _period = 'today';
  Map<String, dynamic> _report = {};
  String? _error;
  bool _loading = true;
  int _requestId = 0;
  TripRealtimeLease? _tripsChannel;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _tripsChannel = SupabaseService.instance.subscribeToAllTrips((_, __) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer(const Duration(milliseconds: 700), _load);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _requestId++;
    _tripsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'admin_trip_kpis_v10',
        params: {
          'p_start': _start.toIso8601String().substring(0, 10),
          'p_end': _end.toIso8601String().substring(0, 10),
        },
      );
      final result = Map<String, dynamic>.from(raw as Map);
      if (mounted && id == _requestId)
        setState(() {
          _report = result;
          _loading = false;
        });
    } catch (_) {
      if (mounted && id == _requestId)
        setState(() {
          _error = 'تعذر قراءة التقرير. حاول التحديث مرة أخرى.';
          _loading = false;
        });
    }
  }

  void _choosePeriod(String next) {
    final now = DateUtils.dateOnly(DateTime.now());
    setState(() {
      _period = next;
      if (next == 'today') {
        _start = now;
        _end = now;
      } else if (next == 'month') {
        _start = DateTime(now.year, now.month);
        _end = now;
      } else if (next == 'week') {
        _start = now.subtract(Duration(days: now.weekday - 1));
        _end = now;
      }
    });
    if (next != 'custom') _load();
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      helpText: start ? 'تاريخ بداية التقرير' : 'تاريخ نهاية التقرير',
    );
    if (picked == null || !mounted) return;
    final date = DateUtils.dateOnly(picked);
    setState(() {
      if (start) {
        _start = date;
        if (_end.isBefore(date)) _end = date;
      } else {
        _end = date;
        if (_start.isAfter(date)) _start = date;
      }
    });
    _load();
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _money(String key) {
    final value = _report[key];
    final number = value is num
        ? value.toDouble()
        : double.tryParse('$value') ?? 0;
    return '${number.toStringAsFixed(2)} ج';
  }

  Widget _metric(String title, Object? value, IconData icon) => Container(
    width: 190,
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AdminTheme.surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AdminTheme.borderSoft),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AdminTheme.goldDark),
        SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Cairo',
            color: AdminTheme.muted,
            fontSize: 12,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '${value ?? 0}',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: AdminTheme.ink,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _section(String title, List<(String, String)> items) => Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AdminTheme.surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AdminTheme.borderSoft),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Cairo',
            color: AdminTheme.goldDark,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        Divider(color: AdminTheme.borderSoft),
        ...items.map(
          (item) => Padding(
            padding: EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.$1,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AdminTheme.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  item.$2,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AdminTheme.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(
      padding: EdgeInsets.all(18),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'التقارير والإحصائيات',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AdminTheme.ink,
                ),
              ),
            ),
            IconButton(
              tooltip: 'تحديث التقرير',
              onPressed: _load,
              icon: Icon(Icons.refresh_rounded, color: AdminTheme.goldDark),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'حدد الفترة بالتوقيت المحلي للقاهرة. الأرقام قراءة فقط ولا تغيّر الأرصدة.',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: AdminTheme.muted,
            fontSize: 12,
          ),
        ),
        SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text('اليوم'),
              selected: _period == 'today',
              onSelected: (_) => _choosePeriod('today'),
            ),
            ChoiceChip(
              label: Text('هذا الأسبوع'),
              selected: _period == 'week',
              onSelected: (_) => _choosePeriod('week'),
            ),
            ChoiceChip(
              label: Text('هذا الشهر'),
              selected: _period == 'month',
              onSelected: (_) => _choosePeriod('month'),
            ),
            ChoiceChip(
              label: Text('تاريخ مخصص'),
              selected: _period == 'custom',
              onSelected: (_) => _choosePeriod('custom'),
            ),
          ],
        ),
        SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                setState(() => _period = 'custom');
                await _pickDate(true);
              },
              icon: Icon(Icons.date_range_rounded),
              label: Text('من: ${_date(_start)}'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                setState(() => _period = 'custom');
                await _pickDate(false);
              },
              icon: Icon(Icons.event_rounded),
              label: Text('إلى: ${_date(_end)}'),
            ),
          ],
        ),
        SizedBox(height: 18),
        if (_loading)
          Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: AdminTheme.goldDark),
            ),
          )
        else if (_error != null)
          _section('حدث خطأ', [(_error!, '')])
        else ...[
          Text(
            'حركة الرحلات',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: AdminTheme.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metric(
                'رحلات searching',
                _report['searching_trips'],
                Icons.radar,
              ),
              _metric(
                'نسبة القبول',
                '${(((_report['acceptance_rate'] as num?) ?? 0) * 100).toStringAsFixed(1)}%',
                Icons.check_circle,
              ),
              _metric(
                'نسبة الإلغاء',
                '${(((_report['cancellation_rate'] as num?) ?? 0) * 100).toStringAsFixed(1)}%',
                Icons.cancel,
              ),
              _metric(
                'متوسط المطابقة بالدقائق',
                _report['average_matching_minutes'] ?? '—',
                Icons.timer,
              ),
              _metric(
                'متوسط ETA بالدقائق',
                _report['average_eta_minutes'] ?? '—',
                Icons.route,
              ),
              _metric('تقييمات منخفضة', _report['low_ratings'], Icons.star),
              _metric('حالات مفتوحة', _report['open_incidents'], Icons.warning),
              _metric(
                'كباتن Online',
                _report['online_captains'],
                Icons.local_taxi,
              ),
              _metric('رحلات أُنشئت', _report['trips'], Icons.add_road_rounded),
              _metric(
                'رحلات مكتملة',
                _report['completed_trips'],
                Icons.check_circle_outline,
              ),
              _metric(
                'رحلات ملغاة',
                _report['cancelled_trips'],
                Icons.cancel_outlined,
              ),
              _metric(
                'ما زالت نشطة من هذه الفترة',
                _report['active_trips'],
                Icons.directions_car,
              ),
            ],
          ),
          SizedBox(height: 14),
          _section('فواتير الرحلات المكتملة في الفترة', [
            ('إجمالي قيمة الفواتير', _money('gross_revenue')),
            ('الأجرة الأساسية', _money('base_fares')),
            ('رسوم الانتظار', _money('waiting_charges')),
            ('الحوافز', _money('incentives')),
            ('خصم البروموكود', _money('discounts')),
          ]),
          SizedBox(height: 12),
          _section('القيم المسجلة بالفواتير والتسوية', [
            ('جزء المحفظة المسجل', _money('wallet_collected')),
            ('جزء الكاش المسجل', _money('cash_collected')),
            ('مستحقات سابقة مدرجة', _money('previous_due')),
            ('مستحقات سابقة محصلة', _money('previous_due_collected')),
            ('عمولة الشركة', _money('commission')),
            ('نصيب الشركة من الحافز', _money('company_incentives')),
            ('صافي الشركة بعد الخصم', _money('company_profit')),
            ('مستحقات الكباتن', _money('captain_earnings')),
          ]),
          SizedBox(height: 12),
          SizedBox(height: 10),
          Text(
            'رحلات الإنشاء تُحسب بتاريخ الطلب، والمكتملة بتاريخ الإكمال، '
            'والملغاة بتاريخ الإلغاء. المبالغ من فواتير الرحلات المكتملة فقط. '
            'قيمة الكاش المسجلة لا تمثل مراجعة خزينة فعلية.',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: AdminTheme.muted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ],
    ),
  );
}
