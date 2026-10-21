import 'package:flutter/material.dart';
import '../services/ride_categories.dart';
import '../services/supabase_service.dart';

class TripPromisePanel extends StatefulWidget {
  const TripPromisePanel({
    super.key,
    required this.tripId,
    required this.status,
    this.captain = false,
  });
  final String tripId, status;
  final bool captain;
  @override
  State<TripPromisePanel> createState() => _TripPromisePanelState();
}

class _TripPromisePanelState extends State<TripPromisePanel> {
  late Future<dynamic> _data;
  final Set<String> _confirmed = {};
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TripPromisePanel old) {
    super.didUpdateWidget(old);
    if (old.tripId != widget.tripId || old.status != widget.status) _load();
  }

  void _load() {
    _data = SupabaseService.instance.client
        .rpc('v3_trip_promise_status', params: {'p_trip': widget.tripId})
        .then((value) {
          _confirmed.clear();
          if (value is Map)
            _confirmed.addAll(List<String>.from(value['confirmed'] ?? []));
          return value;
        });
  }

  String _name(String key) => switch (key) {
    'quiet' => categoryCopy(context, 'مشوار هادي', 'Quiet ride'),
    'no_music' => categoryCopy(context, 'بدون أغاني', 'No music'),
    'ac' => categoryCopy(context, 'تكييف', 'Air conditioning'),
    'child' => categoryCopy(context, 'معايا طفل', 'Accompanying a child'),
    'baggage' => categoryCopy(context, 'مساعدة في الشنط', 'Baggage help'),
    'child_seat' => categoryCopy(context, 'كرسي أطفال', 'Child seat'),
    _ => key,
  };
  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: _data,
    builder: (context, s) {
      if (!s.hasData) return const SizedBox.shrink();
      final value = s.data as Map;
      final requested = List<String>.from(value['requested'] ?? []);
      if (requested.isEmpty) return const SizedBox.shrink();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      categoryCopy(context, 'وعد المشوار', 'Trip Promise'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(_load),
                    tooltip: categoryCopy(context, 'تحديث', 'Refresh'),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              Text(
                categoryCopy(
                  context,
                  widget.captain
                      ? 'أكد التفضيلات اللي تقدر توفرها، بدون تغيير السعر.'
                      : 'التفضيلات حسب تأكيد الكابتن، بدون زيادة تلقائية.',
                  widget.captain
                      ? 'Confirm preferences you can accommodate, without changing the fare.'
                      : 'Preferences depend on captain confirmation, with no automatic surcharge.',
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final option in requested)
                    FilterChip(
                      label: Text(_name(option)),
                      selected: _confirmed.contains(option),
                      onSelected:
                          widget.captain &&
                              value['can_confirm'] == true &&
                              !_busy
                          ? (v) => setState(
                              () => v
                                  ? _confirmed.add(option)
                                  : _confirmed.remove(option),
                            )
                          : null,
                    ),
                ],
              ),
              if (widget.captain && value['can_confirm'] == true)
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await SupabaseService.instance.client.rpc(
                              'v3_confirm_trip_promises',
                              params: {
                                'p_trip': widget.tripId,
                                'p_confirmed': _confirmed.toList(),
                              },
                            );
                            if (mounted) setState(_load);
                          } catch (_) {
                            if (context.mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    categoryCopy(
                                      context,
                                      'تعذر التأكيد. حاول تاني.',
                                      'Could not confirm. Try again.',
                                    ),
                                  ),
                                ),
                              );
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: Text(
                    categoryCopy(
                      context,
                      'تأكيد التفضيلات المتاحة',
                      'Confirm available preferences',
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
