import '../../../l10n/strings.dart';
import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';

/// Optional, one-time captain feedback. All trip/money status stays server-owned.
class CaptainCustomerRatingV29 extends StatefulWidget {
  final String tripId;
  final String customerName;
  const CaptainCustomerRatingV29({
    super.key,
    required this.tripId,
    required this.customerName,
  });

  static final Set<String> _openTrips = <String>{};

  static Future<bool> request(
    BuildContext context, {
    required String tripId,
    required String customerName,
  }) async {
    if (!_openTrips.add(tripId)) return false;
    try {
      final sent = await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF121A2B)
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => CaptainCustomerRatingV29(
          tripId: tripId,
          customerName: customerName,
        ),
      );
      return sent == true;
    } finally {
      _openTrips.remove(tripId);
    }
  }

  @override
  State<CaptainCustomerRatingV29> createState() =>
      _CaptainCustomerRatingV29State();
}

class _CaptainCustomerRatingV29State extends State<CaptainCustomerRatingV29> {
  int _stars = 0;
  bool _busy = false;
  bool _blockCustomer = false;
  bool _failed = false;
  final Set<String> _reasons = {};
  final _note = TextEditingController();

  static const _suggestions = <String>[
    'التأخر عن نقطة اللقاء',
    'أسلوب غير مناسب',
    'تغيير الوجهة',
    'تواصل غير مريح',
    'أخرى',
  ];

  String _reasonLabel(String value) => switch (value) {
    'التأخر عن نقطة اللقاء' => context.strings.ratingReason0,
    'أسلوب غير مناسب' => context.strings.ratingReason1,
    'تغيير الوجهة' => context.strings.ratingReason2,
    'تواصل غير مريح' => context.strings.ratingReason3,
    'أخرى' => context.strings.ratingReason4,
    _ => value,
  };

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _stars == 0) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final feedback = <String>[
      if (_stars <= 2) ..._reasons,
      if (_note.text.trim().isNotEmpty) _note.text.trim(),
    ].join('؛ ');
    try {
      final api = SupabaseService.instance.client;
      final data = await api
          .rpc(
            'captain_rate_customer_v29',
            params: {
              'p_trip_id': widget.tripId,
              'p_stars': _stars,
              'p_feedback': feedback.length > 500
                  ? feedback.substring(0, 500)
                  : feedback,
            },
          )
          .timeout(Duration(seconds: 15));
      if (data is! Map || data['success'] != true) {
        throw StateError('rating_failed');
      }
      // One star is blocked by a server trigger, atomically with the rating.
      if (_stars > 1 && _blockCustomer) {
        await api
            .rpc(
              'v34_block_customer_for_captain',
              params: {'p_trip_id': widget.tripId},
            )
            .timeout(Duration(seconds: 12));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: Directionality.of(context),
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Color(0xFF435066),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            SizedBox(height: 18),
            CircleAvatar(
              radius: 27,
              backgroundColor: Color(0xFF253753),
              child: Icon(
                Icons.person_rounded,
                size: 34,
                color: Color(0xFFF4C451),
              ),
            ),
            SizedBox(height: 12),
            Text(
              context.strings.ratingExperience,
              textAlign: TextAlign.center,
              style: TextStyle(
                
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              widget.customerName,
              textAlign: TextAlign.center,
              style: TextStyle(
                
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => IconButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _stars = i + 1;
                          if (_stars >= 3) {
                            _reasons.clear();
                            _blockCustomer = false;
                          }
                        }),
                  icon: Icon(
                    i < _stars ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Color(0xFFFFC743),
                    size: 37,
                  ),
                  tooltip: context.strings.ratingStars('${i + 1}'),
                ),
              ),
            ),
            if (_stars > 0) ...[
              SizedBox(height: 4),
              Text(
                switch (_stars) {
                  5 => context.strings.ratingExcellent,
                  4 => context.strings.ratingVeryGood,
                  3 => context.strings.ratingGood,
                  2 => context.strings.ratingImprove,
                  _ => context.strings.ratingUncomfortable,
                },
                style: TextStyle(
                  
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
            if (_stars > 0 && _stars <= 2) ...[
              SizedBox(height: 18),
              Text(
                context.strings.ratingWhatHappened,
                style: TextStyle(
                  
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 0,
                children: _suggestions
                    .map(
                      (reason) => FilterChip(
                        label: Text(
                          _reasonLabel(reason),
                          style: TextStyle( fontSize: 11),
                        ),
                        selected: _reasons.contains(reason),
                        onSelected: _busy
                            ? null
                            : (yes) => setState(() {
                                if (yes) {
                                  _reasons.add(reason);
                                } else {
                                  _reasons.remove(reason);
                                }
                              }),
                      ),
                    )
                    .toList(),
              ),
              if (_stars == 1)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    context.strings.ratingBlocked,
                    style: TextStyle(
                      
                      fontSize: 12,
                      color: Color(0xFFFFBE68),
                    ),
                  ),
                ),
              if (_stars == 2)
                SwitchListTile.adaptive(
                  value: _blockCustomer,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _blockCustomer = v),
                  title: Text(
                    context.strings.ratingBlockOption,
                    style: TextStyle(
                      
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
            ],
            SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 350,
              maxLines: 2,
              style: TextStyle(
                
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: context.strings.ratingNote,
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (_failed)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  context.strings.ratingUnconfirmed,
                  style: TextStyle(color: Colors.orangeAccent),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _busy || _stars == 0 ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Color(0xFFF6C34C),
                  foregroundColor: Color(0xFF121A2B),
                ),
                child: Text(
                  _busy
                      ? context.strings.ratingSending
                      : context.strings.ratingSend,
                  style: TextStyle(
                    
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: Text(
                context.strings.ratingLater,
                style: TextStyle(
                  
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
