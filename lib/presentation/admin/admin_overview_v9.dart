import 'dart:math' as math;
import 'dart:async';
import '../../services/supabase_service.dart';
import 'package:flutter/material.dart';
import '../../theme/admin_theme.dart';

class AdminOverviewV9 extends StatefulWidget {
  final bool isLoading;
  final Map<String, dynamic> stats;
  final String? errorMessage;
  final VoidCallback onRefresh;
  final void Function(int, String?) onNavigate;
  const AdminOverviewV9({
    super.key,
    required this.isLoading,
    required this.stats,
    this.errorMessage,
    required this.onRefresh,
    required this.onNavigate,
  });
  @override
  State<AdminOverviewV9> createState() => _AdminOverviewV9State();
}

class _AdminOverviewV9State extends State<AdminOverviewV9> {
  int _days = 7;
  String _metric = 'profit';
  Map<String,dynamic> _liveCounts={};
  Timer? _liveCountTimer;
  DateTime? _countsUpdatedAt;
  @override void initState(){
    super.initState();
    _refreshCounts();
    _liveCountTimer=Timer.periodic(const Duration(seconds:30),(_)=>_refreshCounts());
  }
  @override void dispose(){
    _liveCountTimer?.cancel();
    super.dispose();
  }
  Future<void> _refreshCounts() async {
    try {
      final data=await SupabaseService.instance.client.rpc('v58_admin_live_counts');
      if(mounted && data is Map) setState((){
        _liveCounts=Map<String,dynamic>.from(data);
        _countsUpdatedAt=DateTime.now();
      });
    } catch (_) { /* Keep previous count and show last refresh timestamp. */ }
  }
  double n(String key) {
    final mapped=key=='total_customers'?'customers'
      :key=='total_captains'?'captains':key;
    if (_liveCounts[mapped] is num) return (_liveCounts[mapped] as num).toDouble();
    return (widget.stats[key] as num?)?.toDouble() ?? 0;
  }
  String money(double x) => '${x.toStringAsFixed(2)} ج';
  Widget glass(Widget child) => Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AdminTheme.surface.withValues(alpha: .82),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AdminTheme.borderSoft.withValues(alpha: .8)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: AdminTheme.dark.value ? 0.12 : 0.035,
          ),
          blurRadius: 26,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: child,
  );
  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return Center(child: CircularProgressIndicator());
    if (widget.errorMessage != null)
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.errorMessage!),
            SizedBox(height: 16),
            FilledButton(
              onPressed: widget.onRefresh,
              child: Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    final all = (widget.stats['daily'] as List? ?? [])
        .whereType<Map>()
        .map((x) => Map<String, dynamic>.from(x))
        .toList();
    final daily = all.skip(math.max(0, all.length - _days)).toList();
    final states = Map<String, dynamic>.from(
      widget.stats['states'] as Map? ?? {},
    );
    final total = states.values.fold<double>(
      0,
      (a, b) => a + (b as num).toDouble(),
    );
    final periodProfit = daily.fold<double>(
      0,
      (a, b) => a + ((b['profit'] as num?)?.toDouble() ?? 0),
    );
    final previous = all.length >= _days * 2
        ? all
              .sublist(all.length - _days * 2, all.length - _days)
              .fold<double>(
                0,
                (a, b) => a + ((b['profit'] as num?)?.toDouble() ?? 0),
              )
        : null;
    final change = previous == null
        ? null
        : previous == 0
        ? null
        : (periodProfit - previous) / previous * 100;
    final labels = {
      'profit': 'صافي الشركة',
      'revenue': 'تحصيلات العملاء',
      'trips': 'الرحلات',
      'customers': 'العملاء الجدد',
      'captains': 'الكباتن الجدد',
    };
    final ops = Map<String, dynamic>.from(
      widget.stats['operations_v10'] as Map? ?? {},
    );
    String op(String key) => (ops[key] ?? '—').toString();
    String rate(String key) => ops[key] is num
        ? '${((ops[key] as num) * 100).toStringAsFixed(1)}%'
        : '—';
    final rows = [
      (
        'عملاء المنصة',
        n('total_customers').toInt().toString(),
        Icons.people_outline,
        2,
      ),
      (
        'كباتن المنصة',
        n('total_captains').toInt().toString(),
        Icons.local_taxi_outlined,
        3,
      ),
      ('كباتن سيارات',(_liveCounts['car_captains']??'—').toString(),
        Icons.directions_car_outlined,3),
      ('كباتن موتوسيكل',(_liveCounts['motorcycle_captains']??'—').toString(),
        Icons.two_wheeler_outlined,3),
      (
        'رحلات اليوم',
        n('today_trips').toInt().toString(),
        Icons.route_outlined,
        4,
      ),
      ('تحصيلات اليوم', money(n('today_revenue')), Icons.payments_outlined, 14),
      (
        'صافي الشركة اليوم',
        money(n('today_company_profit')),
        Icons.savings_outlined,
        14,
      ),
      ('رحلات جارية', n('active_trips').toInt().toString(), Icons.radar, 4),
      ('طلبات بتدور على كابتن', op('searching_trips'), Icons.search, 4),
      (
        'نسبة القبول اليوم',
        rate('acceptance_rate'),
        Icons.check_circle_outline,
        14,
      ),
      (
        'نسبة الإلغاء اليوم',
        rate('cancellation_rate'),
        Icons.cancel_outlined,
        14,
      ),
      (
        'متوسط المطابقة / دقيقة',
        op('average_matching_minutes'),
        Icons.timer_outlined,
        14,
      ),
      (
        'متوسط ETA / دقيقة',
        op('average_eta_minutes'),
        Icons.navigation_outlined,
        14,
      ),
      ('تقييمات منخفضة اليوم', op('low_ratings'), Icons.star_border, 22),
      ('حالات تحتاج مراجعة', op('open_incidents'), Icons.warning_amber, 22),
      (
        'عمولة الشركة اليوم',
        ops['commission'] == null
            ? '—'
            : money((ops['commission'] as num).toDouble()),
        Icons.account_balance,
        14,
      ),
      (
        'مستحقات الكباتن اليوم',
        ops['captain_earnings'] == null
            ? '—'
            : money((ops['captain_earnings'] as num).toDouble()),
        Icons.wallet,
        14,
      ),
    ];
    return RefreshIndicator(
      onRefresh: () async { widget.onRefresh(); await _refreshCounts(); },
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            glass(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'رؤية واضحة لكل رحلة',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'مؤشرات الرحلات بتوقيت القاهرة • العدّادات المباشرة: ${_countsUpdatedAt==null?'قيد الاتصال':_countsUpdatedAt!.hour.toString().padLeft(2,'0')+':'+_countsUpdatedAt!.minute.toString().padLeft(2,'0')}',
                              style: TextStyle(color: AdminTheme.muted),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.auto_graph_rounded,
                        color: AdminTheme.gold,
                        size: 42,
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => widget.onNavigate(4, null),
                        icon: Icon(Icons.route),
                        label: Text('إدارة الرحلات'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => widget.onNavigate(13, null),
                        icon: Icon(Icons.tune),
                        label: Text('قواعد الرحلات'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => widget.onNavigate(21, null),
                        icon: Icon(Icons.map_outlined),
                        label: Text('الخريطة الحية'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => widget.onNavigate(14, null),
                        icon: Icon(Icons.date_range),
                        label: Text(
                          'تقارير اليوم / الأسبوع / الشهر / فترة مخصصة',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth < 600
                    ? 2
                    : c.maxWidth < 1100
                    ? 3
                    : 6;
                final width = (c.maxWidth - (cols - 1) * 12) / cols;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final r in rows)
                      SizedBox(
                        width: width,
                        child: glass(
                          InkWell(
                            onTap: () => widget.onNavigate(r.$4, null),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(r.$3, color: AdminTheme.goldDark),
                                SizedBox(height: 14),
                                FittedBox(
                                  child: Text(
                                    r.$2,
                                    style: TextStyle(
                                      color: AdminTheme.ink,
                                      fontSize: 25,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  r.$1,
                                  style: TextStyle(
                                    color: AdminTheme.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                final cards = [
                  glass(
                    _ring(
                      'إتمام رحلات اليوم',
                      n('completion_rate'),
                      '${(n('completion_rate') * 100).toStringAsFixed(1)}%',
                    ),
                  ),
                  glass(
                    _ring(
                      'الكباتن المتصلون',
                      n('total_captains') == 0
                          ? 0
                          : n('online_captains') / n('total_captains'),
                      '${n('online_captains').toInt()} / ${n('total_captains').toInt()}',
                    ),
                  ),
                  glass(
                    _ring(
                      'إلغاء الرحلات المسجلة',
                      total == 0
                          ? 0
                          : ((states['cancelled'] as num?)?.toDouble() ?? 0) /
                                total,
                      '${(states['cancelled'] as num?)?.toInt() ?? 0} رحلة',
                    ),
                  ),
                ];
                return c.maxWidth < 680
                    ? Column(
                        children: [
                          for (final card in cards)
                            Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: card,
                            ),
                        ],
                      )
                    : Row(
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            Expanded(child: cards[i]),
                            if (i < cards.length - 1) SizedBox(width: 12),
                          ],
                        ],
                      );
              },
            ),
            SizedBox(height: 16),
            glass(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Text(
                        'حركة المنصة',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SegmentedButton<int>(
                        segments: [
                          ButtonSegment(value: 7, label: Text('7 أيام')),
                          ButtonSegment(value: 30, label: Text('30 يومًا')),
                        ],
                        selected: {_days},
                        onSelectionChanged: (x) =>
                            setState(() => _days = x.first),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in labels.entries)
                        ChoiceChip(
                          label: Text(e.value),
                          selected: _metric == e.key,
                          onSelected: (_) => setState(() => _metric = e.key),
                        ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'صافي الشركة خلال $_days أيام: ${money(periodProfit)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AdminTheme.ink,
                    ),
                  ),
                  Text(
                    change == null
                        ? 'المقارنة غير متاحة لهذه الفترة'
                        : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% مقارنة بالفترة السابقة',
                    style: TextStyle(color: AdminTheme.muted, fontSize: 12),
                  ),
                  SizedBox(height: 18),
                  if (daily.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(30),
                      child: Text(
                        'لا توجد بيانات للتقارير. تأكد من تطبيق تحديث V9.',
                      ),
                    )
                  else
                    V9BarChart(
                      daily: daily,
                      metric: _metric,
                      label: labels[_metric]!,
                    ),
                ],
              ),
            ),
            SizedBox(height: 16),
            glass(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'كل حالات الرحلات',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 16),
                  for (final e in {
                    'requested': 'جاري البحث',
                    'offer_received': 'عروض مرسلة',
                    'accepted': 'مقبولة',
                    'arriving': 'الكابتن في الطريق',
                    'arrived': 'وصل الكابتن',
                    'started': 'بدأت',
                    'completed': 'مكتملة',
                    'cancelled': 'ملغاة',
                  }.entries)
                    Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          SizedBox(width: 120, child: Text(e.value)),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                minHeight: 8,
                                value: total == 0
                                    ? 0
                                    : ((states[e.key] as num?)?.toDouble() ??
                                              0) /
                                          total,
                                color: e.key == 'cancelled'
                                    ? AdminTheme.error
                                    : AdminTheme.gold,
                                backgroundColor: AdminTheme.surfaceSoft,
                              ),
                            ),
                          ),
                          SizedBox(width: 14),
                          SizedBox(
                            width: 38,
                            child: Text(
                              '${states[e.key] ?? 0}',
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 18),
            Text(
              'التحصيلات تشمل المستحق السابق؛ صافي الشركة = العمولة + نصيب الحافز − الخصم. المبالغ بتاريخ إكمال الرحلة، والخسارة تظهر باللون الأحمر.',
              style: TextStyle(color: AdminTheme.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ring(String title, double value, String label) =>
      TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 900),
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        builder: (context, v, _) => Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: v,
                      strokeWidth: 7,
                      backgroundColor: AdminTheme.surfaceSoft,
                      color: AdminTheme.gold,
                    ),
                  ),
                  Text(
                    '${(v * 100).round()}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AdminTheme.ink,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: AdminTheme.muted, fontSize: 12),
                  ),
                  SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AdminTheme.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class V9BarChart extends StatelessWidget {
  final List<Map<String, dynamic>> daily;
  final String metric, label;
  const V9BarChart({
    super.key,
    required this.daily,
    required this.metric,
    required this.label,
  });
  @override
  Widget build(BuildContext context) {
    final peak = daily.fold<double>(
      0,
      (a, b) => math.max(a, ((b[metric] as num?)?.toDouble() ?? 0).abs()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label • أكبر قيمة مطلقة ${peak.toStringAsFixed(2)}',
          style: TextStyle(color: AdminTheme.muted, fontSize: 11),
        ),
        SizedBox(height: 12),
        SizedBox(
          height: 185,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in daily)
                Expanded(
                  child: Tooltip(
                    message: '${d['day']}\n$label: ${d[metric] ?? 0}',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TweenAnimationBuilder<double>(
                            duration: Duration(milliseconds: 650),
                            tween: Tween(
                              begin: 0,
                              end: peak == 0
                                  ? 0
                                  : ((d[metric] as num?)?.toDouble() ?? 0)
                                            .abs() /
                                        peak,
                            ),
                            builder: (context, v, _) => Container(
                              height: math.max(3, v * 135),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    if (((d[metric] as num?)?.toDouble() ?? 0) <
                                        0) ...[
                                      Colors.red.shade700,
                                      Colors.red.shade300,
                                    ] else ...[
                                      AdminTheme.goldDark,
                                      AdminTheme.goldLight,
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          if (((d[metric] as num?)?.toDouble() ?? 0) < 0)
                            const Text(
                              '−',
                              style: TextStyle(color: Colors.red),
                            ),
                          Text(
                            daily.length <= 7
                                ? d['day'].toString().substring(8, 10)
                                : '',
                            style: TextStyle(
                              fontSize: 10,
                              color: AdminTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
