import '../../services/ride_categories.dart';
import '../../l10n/strings.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../../widgets/captain_photo_v16.dart';

import '../../services/supabase_service.dart';

/// Read-only customer trip receipt. The backend remains the single source of truth.
class CustomerTripDetailsV46 extends StatefulWidget {
  final Map<String, dynamic> trip;
  final Future<Map<String, dynamic>> Function(String)? invoiceLoader;
  const CustomerTripDetailsV46({
    super.key,
    required this.trip,
    this.invoiceLoader,
  });

  @override
  State<CustomerTripDetailsV46> createState() => _CustomerTripDetailsV46State();
}

class _CustomerTripDetailsV46State extends State<CustomerTripDetailsV46> {
  Color get _background => Theme.of(context).brightness == Brightness.dark
      ? Color(0xFF0F1527)
      : Theme.of(context).colorScheme.surface;
  Color get _panel => Theme.of(context).brightness == Brightness.dark
      ? Color(0xFF1A2540)
      : Theme.of(context).colorScheme.surfaceContainer;
  Color get _gold => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFFFC629)
      : Theme.of(context).colorScheme.primary;
  Color get _light => Theme.of(context).brightness == Brightness.dark
      ? Color(0xFFF4F5FA)
      : Theme.of(context).colorScheme.onSurface;
  Color get _muted => Theme.of(context).brightness == Brightness.dark
      ? Color(0xFFB4BED5)
      : Theme.of(context).colorScheme.onSurfaceVariant;
  late final Future<Map<String, dynamic>> _details = _fetch();

  Future<Map<String, dynamic>> _fetch() async =>
      (widget.invoiceLoader ?? SupabaseService.instance.getTripInvoice)(
        widget.trip['id'].toString(),
      );

  String _text(dynamic value, [String empty = '—']) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty ? empty : s;
  }

  String get _formatLocale =>
      Localizations.localeOf(context).languageCode == 'ar' ? 'ar_EG' : 'en';

  double _value(dynamic input) =>
      num.tryParse('${input ?? 0}')?.toDouble() ?? 0;
  String _money(dynamic input) => context.strings.moneyValue(
    NumberFormat('0.00', _formatLocale).format(_value(input)),
  );

  String _date(dynamic input) {
    final d = DateTime.tryParse(_text(input, ''))?.toLocal();
    if (d == null) return '—';
    final locale = _formatLocale;
    return '${DateFormat.yMd(locale).format(d)}  •  ${DateFormat.Hm(locale).format(d)}';
  }

  String _status(String raw) => switch (raw) {
    'completed' => context.strings.receiptf1d6d15f,
    'cancelled' => context.strings.receiptd87ae61b,
    'requested' || 'offer_received' => context.strings.receiptc74d3b21,
    'accepted' => context.strings.receipt30d5d6b5,
    'arriving' => context.strings.receipt2de6d001,
    'arrived' => context.strings.receipt39ac9d30,
    'started' => context.strings.receiptc20f27ab,
    _ => raw,
  };

  String _service(String raw) => switch (raw) {
    'car_ride' => context.strings.receipt42816de2,
    'motorcycle_ride' => context.strings.receiptf8748198,
    'package' => context.strings.receiptccd99512,
    _ => context.strings.receiptc99f71b7,
  };

  Widget _caption(String label, String value, {Color? color}) => Padding(
    padding: EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle( color: _muted, fontSize: 12),
          ),
        ),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              
              color: color ?? _light,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _address(IconData icon, String title, dynamic address) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: _gold, size: 19),
      SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                
                fontSize: 11,
                color: _muted,
              ),
            ),
            Text(
              _text(address),
              style: TextStyle(
                
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _light,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _captain(Map<String, dynamic>? captain, Map<String, dynamic> trip) {
    if (captain == null || trip['captain_id'] == null) {
      return Text(
        context.strings.receiptdadf5afd,
        style: TextStyle( color: _muted, fontSize: 13),
      );
    }
    final name = _text(captain['full_name'], context.strings.receipt2f225a03);
    final photo = _text(
      captain['profile_photo_url'] ??
          captain['profile_photo'] ??
          captain['photo_url'],
      '',
    );
    final fallback = CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.person, color: _gold),
    );
    return Row(
      children: [
        if (photo.startsWith('https://') || photo.startsWith('v16-private://'))
          ClipOval(
            child: Image(
              image: captainPhotoV16(photo),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
          )
        else
          fallback,
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.strings.receiptc634600a,
                style: TextStyle(
                  
                  fontSize: 11,
                  color: _muted,
                ),
              ),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _light,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: Directionality.of(context),
    child: SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _details,
          builder: (context, snapshot) {
            final result = snapshot.data;
            final t = result?['trip'] is Map
                ? Map<String, dynamic>.from(result!['trip'] as Map)
                : widget.trip;
            final captain = result?['captain'] is Map
                ? Map<String, dynamic>.from(result!['captain'] as Map)
                : null;
            final state = _text(t['trip_status'], '');
            return ListView(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _muted.withAlpha(90),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.strings.receipte12a8659,
                        style: TextStyle(
                          
                          color: _light,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: _muted),
                    ),
                  ],
                ),
                Text(
                  _date(t['created_at']),
                  style: TextStyle(
                    
                    color: _muted,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tripCategoryLabel(context,t,_service(_text(t['service_type'], ''))),
                              style: TextStyle(
                                
                                color: _light,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            _status(state),
                            style: TextStyle(
                              
                              color: _gold,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Divider(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        height: 24,
                      ),
                      _address(
                        Icons.my_location_rounded,
                        context.strings.receipt4d7d679f,
                        t['pickup_address'],
                      ),
                      SizedBox(height: 14),
                      _address(
                        Icons.location_on_rounded,
                        context.strings.receipt97fe3fe5,
                        t['destination_address'],
                      ),
                      if (t['distance_km'] != null ||
                          t['duration_minutes'] != null) ...[
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 14,
                          children: [
                            if (t['distance_km'] != null)
                              Text(
                                context.strings.receiptDistance(
                                  NumberFormat(
                                    '0.0',
                                    _formatLocale,
                                  ).format(_value(t['distance_km'])),
                                ),
                                style: TextStyle(
                                  
                                  color: _muted,
                                ),
                              ),
                            if (t['duration_minutes'] != null)
                              Text(
                                context.strings.receiptMinutes(
                                  '${t['duration_minutes']}',
                                ),
                                style: TextStyle(
                                  
                                  color: _muted,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(color: _gold),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _captain(captain, t),
                            if (snapshot.hasError) ...[
                              SizedBox(height: 6),
                              Text(
                                context.strings.receipt4fe4aa51,
                                style: TextStyle(
                                  
                                  color: _muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.strings.receipt17d786d8,
                        style: TextStyle(
                          
                          color: _light,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      _caption(
                        context.strings.receipt7f29d28a,
                        _money(t['base_fare']),
                      ),
                      if (_value(t['waiting_charge']) > 0)
                        _caption(
                          context.strings.receipt4d1a2a15,
                          _money(t['waiting_charge']),
                        ),
                      if (_value(t['incentive_amount']) > 0)
                        _caption(
                          context.strings.receipt6432e51d,
                          _money(t['incentive_amount']),
                        ),
                      if (_value(t['promo_discount']) > 0)
                        _caption(
                          context.strings.receiptec9ccd93,
                          '-${_money(t['promo_discount'])}',
                        ),
                      if (_value(t['customer_previous_due']) > 0)
                        _caption(
                          context.strings.receiptf28e3f71,
                          _money(t['customer_previous_due']),
                        ),
                      Divider(color: Theme.of(context).colorScheme.outlineVariant),
                      _caption(
                        context.strings.receiptc5496762,
                        t['total_fare'] == null
                            ? context.strings.receipta455b08a
                            : _money(t['total_fare']),
                        color: _gold,
                      ),
                      _caption(
                        context.strings.receipt48c3380c,
                        _money(t['wallet_amount']),
                      ),
                      _caption(
                        context.strings.receipt1881ccb3,
                        _money(t['cash_amount']),
                      ),
                    ],
                  ),
                ),
                if (t['completed_at'] != null) ...[
                  SizedBox(height: 8),
                  Text(
                    context.strings.receiptCompletedAt(
                      _date(t['completed_at']),
                    ),
                    style: TextStyle(
                      
                      color: _muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );
}
