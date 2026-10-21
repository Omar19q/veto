import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/admin_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/supabase_service.dart';

final adminTripStatusLabels = <String, String>{
  'requested': 'طلب جديد',
  'offer_received': 'وصل عرض',
  'accepted': 'الكابتن قبل الطلب',
  'arriving': 'الكابتن في الطريق',
  'arrived': 'الكابتن وصل للعميل',
  'started': 'الرحلة بدأت',
  'completed': 'الرحلة خلصت',
  'cancelled': 'الرحلة اتلغت',
};

class AdminTripDetailsScreen extends StatefulWidget {
  final String tripId;
  const AdminTripDetailsScreen({super.key, required this.tripId});
  @override
  State<AdminTripDetailsScreen> createState() => _AdminTripDetailsScreenState();
}

class _AdminTripDetailsScreenState extends State<AdminTripDetailsScreen> {
  final _db = SupabaseService.instance.client;
  Map<String, dynamic>? _details;
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = true, _saving = false, _chatLoading = false, _hasOlder = true;
  String? _error, _selected;
  TripRealtimeLease? _channel;
  RealtimeChannel? _chatChannel;
  String? _lastTripRevision;
  String _time(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'غير مسجل';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}/${two(date.month)}/${two(date.day)} ${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }

  @override
  void initState() {
    super.initState();
    _reload();
    _channel = SupabaseService.instance.subscribeToTripStatus(widget.tripId, (
      row,
    ) {
      final revision =
          '${row['updated_at']}_${row['trip_status']}_${(row['trip_event_v11'] as Map?)?['id']}';
      if (_lastTripRevision != revision) {
        _lastTripRevision = revision;
        _reload();
      }
    });
    _chatChannel = SupabaseService.instance.subscribeToChatMessages(
      widget.tripId,
      (row) {
        if (mounted) setState(() => _mergeMessages([row]));
      },
      onReconnect: () => _reload(),
    );
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _chatChannel?.unsubscribe();
    super.dispose();
  }

  bool _reloading = false;
  bool _reloadAgain = false;
  Future<void> _reload() async {
    if (_reloading) {
      _reloadAgain = true;
      return;
    }
    _reloading = true;
    try {
      final details = await _db
          .rpc('admin_trip_details_v14', params: {'p_trip_id': widget.tripId})
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final map = Map<String, dynamic>.from(details as Map);

      var rows = <Map<String, dynamic>>[];
      try {
        final recent = await _db
            .rpc(
              'admin_trip_chat_v13',
              params: {'p_trip_id': widget.tripId, 'p_limit': 100},
            )
            .timeout(const Duration(seconds: 3));
        if (recent is List) {
          rows = recent
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
        }
      } catch (_) {
        // Trip details must stay usable even if chat history is temporarily
        // unavailable or the chat RPC has not been deployed yet.
      }

      if (!mounted) return;
      setState(() {
        _details = map;
        _loading = false;
        _error = null;
        _selected = (map['trip'] as Map)['trip_status']?.toString();
        if (_messages.isEmpty) _hasOlder = rows.length == 100;
        _mergeMessages(rows);
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error =
              'تعذر تحميل تفاصيل الرحلة. اضغط تحديث؛ لو استمرت المشكلة تأكد أن RUN_THIS_SQL_V13.sql تم تشغيله بنجاح.';
        });
    } finally {
      _reloading = false;
      if (_reloadAgain && mounted) {
        _reloadAgain = false;
        unawaited(_reload());
      }
    }
  }

  void _mergeMessages(List<Map<String, dynamic>> rows) {
    final map = {
      for (final message in _messages) message['id'].toString(): message,
    };
    for (final message in rows) {
      map[message['id'].toString()] = message;
    }
    _messages
      ..clear()
      ..addAll(map.values);
    _messages.sort((a, b) {
      final result = a['created_at'].toString().compareTo(
        b['created_at'].toString(),
      );
      return result != 0
          ? result
          : a['id'].toString().compareTo(b['id'].toString());
    });
  }

  Future<void> _olderChat() async {
    if (_chatLoading || !_hasOlder || _messages.isEmpty) return;
    setState(() => _chatLoading = true);
    try {
      final first = _messages.first;
      final result = await _db.rpc(
        'admin_trip_chat_v13',
        params: {
          'p_trip_id': widget.tripId,
          'p_before': first['created_at'],
          'p_before_id': first['id'],
          'p_limit': 100,
        },
      );
      final rows = List<Map<String, dynamic>>.from(result as List);
      if (mounted)
        setState(() {
          _mergeMessages(rows);
          _hasOlder = rows.length == 100;
        });
    } catch (_) {
      _notice('تعذر تحميل الرسائل الأقدم.');
    } finally {
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  void _notice(String message) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _override() async {
    if (_saving || _selected == null) return;
    final reason = TextEditingController();
    final why = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تأكيد تعديل حالة الرحلة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'هتغيّر الحالة إلى: ${adminTripStatusLabels[_selected]}. الإجراء بيتسجل باسمك في سجل الرقابة.',
              ),
              SizedBox(height: 12),
              Text(
                'تغيير الحالة وحده لا ينشئ تحصيلاً نقدياً أو رد محفظة جديداً. راجع الحسابات عند التسوية اليدوية.',
                style: TextStyle(color: Colors.orange),
              ),
              SizedBox(height: 12),
              TextField(
                controller: reason,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'سبب التعديل'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, reason.text.trim()),
            child: Text('تأكيد التغيير'),
          ),
        ],
      ),
    );
    reason.dispose();
    if (!mounted || why == null) return;
    if (why.length < 5) {
      _notice('اكتب سببًا واضحًا من 5 حروف على الأقل.');
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await _db.rpc(
        'admin_force_update_trip_status_v13',
        params: {
          'p_trip_id': widget.tripId,
          'p_new_status': _selected,
          'p_reason': why,
        },
      );
      final data = Map<String, dynamic>.from((result as Map?) ?? {});
      if (data['success'] != true) {
        throw StateError(data['error']?.toString() ?? 'admin_update_failed');
      }
      await _reload();
      _notice('تم تعديل الحالة وتسجيل الإجراء.');
    } catch (_) {
      _notice(
        'تعذر تعديل الحالة. راجع الصلاحية والاتصال وقيود قاعدة البيانات.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _line(String title, dynamic value) => Padding(
    padding: EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(title, style: TextStyle(color: AdminTheme.muted)),
        ),
        Expanded(
          child: SelectableText(
            value?.toString() ?? 'غير مسجل',
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );
  String _eventDetailsV10(dynamic raw) {
    if (raw is! Map) return raw?.toString() ?? '';
    final parts = <String>[];
    if (raw['previous_total'] != null)
      parts.add('السعر السابق: ${raw['previous_total']} ج');
    if (raw['total'] != null) parts.add('الإجمالي: ${raw['total']} ج');
    if (raw['incentive'] != null) parts.add('الحافز: ${raw['incentive']} ج');
    if (raw['increment'] != null)
      parts.add('زيادة الحافز: ${raw['increment']} ج');
    if (raw['stars'] != null) parts.add('التقييم: ${raw['stars']}/5');
    if (raw['reason'] != null) parts.add('السبب: ${raw['reason']}');
    if (raw['captain_id'] != null) parts.add('الكابتن: ${raw['captain_id']}');
    if (raw['wave'] != null) parts.add('مرحلة العرض: ${raw['wave']}');
    if (raw['action'] != null)
      parts.add(
        'الإجراء: ${{'notice': 'تنبيه', 'warning': 'إنذار', 'suspend': 'إيقاف مؤقت', 'ban': 'حظر', 'restore': 'فك الإيقاف'}[raw['action']] ?? raw['action']}',
      );
    return parts.join(' • ');
  }

  Widget _card(String title, List<Widget> children) => Card(
    margin: EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AdminTheme.goldDark,
            ),
          ),
          SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  LatLng? _point(dynamic lat, dynamic lng) {
    final a = (lat as num?)?.toDouble(), b = (lng as num?)?.toDouble();
    if (a == null ||
        b == null ||
        !a.isFinite ||
        !b.isFinite ||
        a.abs() > 90 ||
        b.abs() > 180)
      return null;
    return LatLng(a, b);
  }

  Widget _route(Map<String, dynamic> trip) {
    final pickup = _point(trip['pickup_latitude'], trip['pickup_longitude']);
    final destination = _point(
      trip['destination_latitude'],
      trip['destination_longitude'],
    );
    final track = <LatLng>[];
    for (final row in (_details?['track'] as List? ?? [])) {
      final point = _point(row['latitude'], row['longitude']);
      if (point != null) track.add(point);
    }
    final points = track.length >= 2
        ? track
        : [if (pickup != null) pickup, if (destination != null) destination];
    if (points.isEmpty) return Text('لا توجد إحداثيات مسجلة للرحلة.');
    return Column(
      children: [
        SizedBox(
          height: 260,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: FlutterMap(
              key: ValueKey(widget.tripId),
              options: MapOptions(
                initialCenter: points.first,
                initialZoom: 14,
                initialCameraFit: points.length > 1
                    ? CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(points),
                        padding: EdgeInsets.all(35),
                      )
                    : null,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.vetosanya.app',
                ),
                if (points.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        color: AdminTheme.goldDark,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (pickup != null)
                      Marker(
                        point: pickup,
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.trip_origin,
                          color: Colors.green,
                          size: 32,
                        ),
                      ),
                    if (destination != null)
                      Marker(
                        point: destination,
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 35,
                        ),
                      ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          track.length >= 2
              ? 'مسار GPS المسجل — ${track.length} نقطة'
              : 'خط الربط بين الانطلاق والوجهة؛ المسار الفعلي غير مسجل لهذه الرحلة.',
          style: TextStyle(color: AdminTheme.muted, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = Map<String, dynamic>.from(_details?['trip'] as Map? ?? {});
    final customer = Map<String, dynamic>.from(
      _details?['customer'] as Map? ?? {},
    );
    final captain = Map<String, dynamic>.from(
      _details?['captain'] as Map? ?? {},
    );
    final pricing = Map<String, dynamic>.from(
      trip['pricing_snapshot'] as Map? ?? {},
    );
    final pressure = Map<String, dynamic>.from(
      pricing['dynamic_context_v10'] as Map? ?? {},
    );
    const pressureReasons = {
      'demand_exceeds_available_supply': 'الطلبات أكثر من الكباتن المتاحين',
      'long_matching_or_waiting': 'وقت الانتظار أو المطابقة مرتفع',
      'low_acceptance_rate': 'نسبة القبول منخفضة في العينة',
      'peak_hours_with_active_demand': 'وقت ذروة مع طلب فعلي',
      'nearest_available_captain_over_2km': 'أقرب كابتن متاح بعيد أكثر من 2 كم',
      'slow_server_route': 'زمن المسار مرتفع بالنسبة للمسافة',
    };
    final change = Map<String, dynamic>.from(_details?['change'] as Map? ?? {});
    final events = List<Map<String, dynamic>>.from(
      _details?['events'] as List? ?? [],
    );
    final arrivalByAdmin = events.any(
      (event) =>
          event['new_status'] == 'arrived' &&
          event['source'] == 'admin_override',
    );
    return Theme(
      data: AdminTheme.theme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AdminTheme.background,
          appBar: AppBar(
            title: Text('تفاصيل الرحلة والرقابة'),
            actions: [
              IconButton(onPressed: _reload, icon: Icon(Icons.refresh)),
            ],
          ),
          body: _loading
              ? Center(child: CircularProgressIndicator())
              : _details == null
              ? Center(child: Text(_error ?? 'الرحلة غير موجودة'))
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: EdgeInsets.all(16),
                    children: [
                      if (_error != null)
                        Text(_error!, style: TextStyle(color: Colors.orange)),
                      _card('بيانات المشوار', [
                        _line('رقم الرحلة', widget.tripId),
                        _line('العميل', customer['name']),
                        _line('رقم العميل', customer['phone']),
                        _line('الكابتن', captain['name']),
                        _line('رقم الكابتن', captain['phone']),
                        _line(
                          'الحالة الحالية',
                          adminTripStatusLabels[trip['trip_status']] ??
                              trip['trip_status'],
                        ),
                        _line('من', trip['pickup_address']),
                        _line('إلى', trip['destination_address']),
                        _line('طلبات هاتلي معاك', trip['extra_requests']),
                        _line('قيمة الرحلة', trip['total_fare']),
                        _line('الأجرة الأساسية', trip['base_fare']),
                        _line('الحافز', trip['incentive_amount']),
                        _line(
                          'المضاعف المثبت',
                          trip['pricing_multiplier_used'],
                        ),
                        _line('الخصم', trip['promo_discount']),
                        _line('المحفظة', trip['wallet_amount']),
                        _line('الكاش', trip['cash_amount']),
                        _line('المستحق السابق', trip['customer_previous_due']),
                        _line(
                          'المستحق السابق المحصل',
                          trip['previous_due_collected'],
                        ),
                        _line(
                          'تعويض الإلغاء',
                          (_details?['cancellation'] as Map?)?['compensation'],
                        ),
                        _line(
                          'نصيب الشركة من الحافز',
                          trip['company_incentive_amount'],
                        ),
                        _line('الانتظار', trip['waiting_charge']),
                        _line('المسافة', trip['distance_km']),
                        _line('المدة المتوقعة', trip['duration_minutes']),
                        _line('عمولة الرحلة', trip['commission_amount']),
                        _line('صافي الكابتن', trip['captain_earnings']),

                        _line(
                          'الفكّة اللي رجعت للعميل',
                          '${(change['amount'] as num? ?? 0).toStringAsFixed(2)} ج',
                        ),
                        _line('وقت تحويل الفكّة', _time(change['created_at'])),
                      ]),
                      if (pressure.isNotEmpty)
                        _card('تفسير السعر وقت الحجز', [
                          _line('المنطقة', pricing['zone_name']),
                          _line('الطلبات الباحثة', pressure['demand']),
                          _line('الكباتن المتاحون', pressure['supply']),
                          _line('نسبة الطلب إلى العرض', pressure['ratio']),
                          _line(
                            'متوسط الانتظار بالدقائق',
                            pressure['average_wait_minutes'],
                          ),
                          _line(
                            'بعد أقرب كابتن بالكيلومتر',
                            pressure['nearest_available_km'],
                          ),
                          _line('المعامل المثبت', pressure['multiplier']),
                          Text(
                            (pressure['reasons'] as List? ?? []).isEmpty
                                ? 'تسعير عادي؛ لا توجد أسباب زيادة مسجلة.'
                                : (pressure['reasons'] as List)
                                      .map(
                                        (r) =>
                                            pressureReasons[r] ??
                                            'سبب إضافي مسجل بالسياسة',
                                      )
                                      .join(' • '),
                          ),
                        ]),
                      _card('التوقيتات المسجلة', [
                        _line('وقت قبول الطلب', _time(trip['accepted_at'])),
                        _line(
                          arrivalByAdmin
                              ? 'وقت الوصول — تعديل إداري'
                              : 'وقت تسجيل الوصول للعميل',
                          _time(trip['arrived_at']),
                        ),
                        _line('وقت بدء الرحلة', _time(trip['started_at'])),
                        _line('وقت إنهاء الرحلة', _time(trip['completed_at'])),
                        _line('وقت إنشاء الطلب', _time(trip['created_at'])),
                        _line('وقت الإلغاء', _time(trip['cancelled_at'])),
                        Text(
                          'التوقيتات تعرض الثواني المسجلة في النظام. الرحلات القديمة قد لا تتوفر لها بيانات قبول أو مسار.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AdminTheme.muted,
                          ),
                        ),
                      ]),
                      _card('المسار', [_route(trip)]),
                      _card('تغيير الحالة بواسطة الأدمن', [
                        DropdownButtonFormField<String>(
                          initialValue: _selected,
                          decoration: InputDecoration(
                            labelText: 'الحالة الجديدة',
                          ),
                          items: adminTripStatusLabels.entries
                              .where((e) {
                                final current = trip['trip_status']?.toString();
                                final allowed = <String>{
                                  if (current != null) current,
                                };
                                if (!{
                                  'completed',
                                  'cancelled',
                                  'started',
                                }.contains(current))
                                  allowed.add('cancelled');
                                if (trip['captain_id'] != null)
                                  allowed.addAll(switch (current) {
                                    'accepted' => {'arriving', 'arrived'},
                                    'arriving' => {'arrived'},
                                    'arrived' => {'started'},
                                    'started' => {'completed'},
                                    _ => <String>{},
                                  });
                                return allowed.contains(e.key);
                              })
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _selected = value),
                        ),
                        SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _saving ? null : _override,
                          icon: Icon(Icons.admin_panel_settings),
                          label: Text(
                            _saving ? 'جارٍ التعديل' : 'تطبيق الحالة',
                          ),
                        ),
                      ]),
                      _card('محادثة العميل والكابتن', [
                        Text(
                          'مراجعة فقط — الرسائل الأصلية كما كتبها أصحابها.',
                          style: TextStyle(
                            color: AdminTheme.muted,
                            fontSize: 12,
                          ),
                        ),
                        if (_hasOlder && _messages.isNotEmpty)
                          TextButton(
                            onPressed: _chatLoading ? null : _olderChat,
                            child: Text(
                              _chatLoading
                                  ? 'جارٍ التحميل'
                                  : 'تحميل رسائل أقدم',
                            ),
                          ),
                        if (_messages.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('مفيش رسائل في الرحلة دي.'),
                          ),
                        ..._messages.map((message) {
                          final fromCaptain =
                              message['sender_id'] == captain['user_id'];
                          return Align(
                            alignment: fromCaptain
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(maxWidth: 330),
                              margin: EdgeInsets.symmetric(vertical: 5),
                              padding: EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: fromCaptain
                                    ? AdminTheme.surfaceStrong
                                    : AdminTheme.surfaceSoft,
                                borderRadius: BorderRadius.circular(17),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fromCaptain ? 'الكابتن' : 'العميل',
                                    style: TextStyle(
                                      color: AdminTheme.goldDark,
                                      fontSize: 11,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  SelectableText(
                                    message['message']?.toString() ?? '',
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    _time(message['created_at']),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AdminTheme.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ]),
                      _card('تايملاين الرحلة', [
                        if (events.isEmpty)
                          Text('مفيش تغييرات مسجلة بعد التحديث.'),
                        ...events.map(
                          (event) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              event['source'] == 'admin_override'
                                  ? Icons.admin_panel_settings
                                  : Icons.route,
                            ),
                            title: Text(
                              event['source'] == 'v10' ||
                                      event['source'] == 'dispatch'
                                  ? '${{'boost': 'حافز العميل', 'price_changed': 'تعديل السعر', 'rating': 'تقييم العميل', 'offer': 'عرض على كابتن', 'incident_review': 'مراجعة إدارية', 'ai_review': 'تحليل ذكي', 'captain_admin_action': 'إجراء إداري للكابتن'}[event['new_status']] ?? event['new_status']}'
                                  : '${adminTripStatusLabels[event['old_status']] ?? event['old_status']} ← ${adminTripStatusLabels[event['new_status']] ?? event['new_status']}',
                            ),
                            subtitle: Text(
                              '${_time(event['recorded_at'])}\n${event['source'] == 'admin_override'
                                  ? 'تعديل إداري: ${event['reason']}'
                                  : event['source'] == 'v10' || event['source'] == 'dispatch'
                                  ? _eventDetailsV10(event['reason'])
                                  : 'تحديث من التطبيق'}',
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
