import '../../../l10n/strings.dart';
import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';

class TripRatingSheetV10 extends StatefulWidget {
  final String tripId, captainName;
  const TripRatingSheetV10({
    super.key,
    required this.tripId,
    required this.captainName,
  });
  @override
  State<TripRatingSheetV10> createState() => _TripRatingSheetV10State();
}

class _TripRatingSheetV10State extends State<TripRatingSheetV10> {
  int stars = 5;
  bool busy = false;
  bool failed = false;
  final reasons = <String>{};
  final comment = TextEditingController();
  String _reasonLabel(String canonical) => switch (canonical) {
    'اتأخر عليّا' => context.strings.customerRatingReason0,
    'أسلوبه مش مناسب' => context.strings.customerRatingReason1,
    'قيادة مش مريحة' => context.strings.customerRatingReason2,
    'طلب فلوس زيادة' => context.strings.customerRatingReason3,
    'المركبة مختلفة' => context.strings.customerRatingReason4,
    'الطريق كان غريب' => context.strings.customerRatingReason5,
    'مشكلة تانية' => context.strings.customerRatingReason6,
    'وصل بسرعة' => context.strings.customerRatingReason7,
    'محترم' => context.strings.customerRatingReason8,
    'قيادة مريحة' => context.strings.customerRatingReason9,
    'المركبة نضيفة' => context.strings.customerRatingReason10,
    'تجربة ممتازة' => context.strings.customerRatingReason11,
    _ => canonical,
  };

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: Directionality.of(context),
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        22,
        20,
        22,
        22 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.strings.customerRatingTitle,
            style: TextStyle(
              
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            context.strings.customerRatingCaptain(widget.captainName),
            style: const TextStyle(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => IconButton(
                tooltip: context.strings.customerRatingStars('${i + 1}'),
                onPressed: busy
                    ? null
                    : () => setState(() {
                        stars = i + 1;
                        reasons.clear();
                      }),
                icon: Icon(
                  i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 36,
                ),
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                (stars <= 3
                        ? [
                            'اتأخر عليّا',
                            'أسلوبه مش مناسب',
                            'قيادة مش مريحة',
                            'طلب فلوس زيادة',
                            'المركبة مختلفة',
                            'الطريق كان غريب',
                            'مشكلة تانية',
                          ]
                        : [
                            'وصل بسرعة',
                            'محترم',
                            'قيادة مريحة',
                            'المركبة نضيفة',
                            'تجربة ممتازة',
                          ])
                    .map(
                      (s) => FilterChip(
                        label: Text(_reasonLabel(s)),
                        selected: reasons.contains(s),
                        onSelected: busy
                            ? null
                            : (on) => setState(
                                () => on ? reasons.add(s) : reasons.remove(s),
                              ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: comment,
            maxLength: 1000,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: context.strings.customerRatingComment,
              border: OutlineInputBorder(),
            ),
          ),
          Text(
            context.strings.customerRatingPrivacy,
            style: TextStyle(fontSize: 11),
          ),
          if (failed)
            Text(
              context.strings.ratingUnconfirmed,
              style: const TextStyle(color: Colors.red),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      failed = false;
                    });
                    try {
                      final raw = await SupabaseService.instance.client
                          .rpc(
                            'submit_trip_rating_v10',
                            params: {
                              'p_trip_id': widget.tripId,
                              'p_stars': stars,
                              'p_reasons': reasons.toList(),
                              'p_comment': comment.text.trim(),
                            },
                          )
                          .timeout(const Duration(seconds: 12));
                      if (raw is! Map || raw['success'] != true)
                        throw StateError('rating_failed');
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (_) {
                      if (mounted) setState(() => failed = true);
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text(
              busy
                  ? context.strings.customerRatingSending
                  : context.strings.ratingSend,
            ),
          ),
        ],
      ),
    ),
  );
}
