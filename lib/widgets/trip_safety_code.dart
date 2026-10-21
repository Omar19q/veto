import 'package:flutter/material.dart';
import '../services/ride_categories.dart';
import '../services/supabase_service.dart';

class CustomerTripSafetyCode extends StatefulWidget {
  const CustomerTripSafetyCode({super.key, required this.tripId});
  final String tripId;
  @override
  State<CustomerTripSafetyCode> createState() => _CustomerTripSafetyCodeState();
}

class _CustomerTripSafetyCodeState extends State<CustomerTripSafetyCode> {
  late Future<dynamic> _data;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CustomerTripSafetyCode old) {
    super.didUpdateWidget(old);
    if (old.tripId != widget.tripId) _load();
  }

  void _load() {
    _data = SupabaseService.instance.client.rpc(
      'v3_customer_trip_code',
      params: {'p_trip': widget.tripId},
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: _data,
    builder: (context, s) {
      if (s.hasError)
        return ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: Text(
            categoryCopy(
              context,
              'تعذر تحميل كود الأمان',
              'Unable to load trip code',
            ),
          ),
          trailing: IconButton(
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh),
          ),
        );
      final value = s.data;
      if (value is! Map || value.isEmpty) return const SizedBox.shrink();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                categoryCopy(context, 'كود أمان المشوار', 'VETO SAFE'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (value['verified'] == true)
                Text(categoryCopy(context, 'الكود اتأكد', 'Code verified'))
              else ...[
                Text(
                  categoryCopy(
                    context,
                    'اتأكد إن دي عربيتك قبل ما تركب. قول كود المشوار للكابتن لما يوصل.',
                    'Check the vehicle before boarding. Share this code with your assigned captain at pickup.',
                  ),
                ),
                Semantics(
                  label: categoryCopy(context, 'كود المشوار', 'Trip code'),
                  child: Text(
                    '${value['pin'] ?? ''}',
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                    ),
                  ),
                ),
                if (value['locked'] == true)
                  Text(
                    categoryCopy(
                      context,
                      'المحاولات خلصت. تواصل مع الدعم.',
                      'Attempts exhausted. Contact support.',
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> verifyCaptainTripCode(BuildContext context, String tripId) async {
  final input = TextEditingController();
  bool busy = false;
  String? error;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          categoryCopy(context, 'كود أمان المشوار', 'Trip safety code'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                categoryCopy(
                  context,
                  'اطلب كود المشوار من العميل.',
                  'Ask the passenger for the trip code.',
                ),
              ),
              TextField(
                controller: input,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: categoryCopy(context, 'الكود', 'Code'),
                  errorText: error,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context, false),
            child: Text(categoryCopy(context, 'رجوع', 'Back')),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      final r = await SupabaseService.instance.client.rpc(
                        'v3_verify_trip_code',
                        params: {'p_trip': tripId, 'p_code': input.text.trim()},
                      );
                      if (!context.mounted) return;
                      if (r is Map && r['success'] == true) {
                        Navigator.pop(context, true);
                        return;
                      }
                      setState(
                        () => error = categoryCopy(
                          context,
                          'الكود غير صحيح أو انتهت المحاولات.',
                          'Invalid code or attempts exhausted.',
                        ),
                      );
                    } catch (_) {
                      if (context.mounted)
                        setState(
                          () => error = categoryCopy(
                            context,
                            'تعذر التأكيد. حاول مرة تانية.',
                            'Unable to verify. Try again.',
                          ),
                        );
                    } finally {
                      if (context.mounted) setState(() => busy = false);
                    }
                  },
            child: Text(
              categoryCopy(
                context,
                busy ? 'جاري التأكيد…' : 'تأكيد',
                busy ? 'Verifying…' : 'Verify',
              ),
            ),
          ),
        ],
      ),
    ),
  );
  // Dialog's closing animation can still reference its controller.
  Future<void>.delayed(const Duration(seconds: 1), input.dispose);
  return result == true;
}
