import '../../l10n/strings.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/growth_service.dart';

class GrowthZeroPanel extends StatefulWidget {
  const GrowthZeroPanel({super.key, required this.service});
  final GrowthService service;
  @override
  State<GrowthZeroPanel> createState() => _GrowthZeroPanelState();
}

class _GrowthZeroPanelState extends State<GrowthZeroPanel> {
  Map<String, dynamic>? data;
  String? error;
  bool busy = false;
  final elapsed = Stopwatch();
  Timer? timer;
  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted && data != null) setState(() {});
    });
  }

  Future<void> load() async {
    try {
      final result = await widget.service.call('growth_zero_status_v1');
      if (mounted) {
        setState(() {
          data = result;
          error = null;
          elapsed.reset();
          elapsed.start();
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = context.strings.zeroLoadFailed);
    }
  }

  Future<void> activateReward(String id) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.service.call('growth_activate_zero_v1', {'p_id': id});
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              context.strings.zeroActivateFailed,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    elapsed.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.tryParse(data?['server_now']?.toString() ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null)
          Text(error!, style: TextStyle(color: Colors.orange)),
        for (final w in (data?['windows'] as List? ?? []))
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Builder(
                builder: (_) {
                  final end = DateTime.tryParse(w['ends_at']?.toString() ?? '');
                  final remaining = end == null || now == null
                      ? Duration.zero
                      : end.difference(now) - elapsed.elapsed;
                  final seconds = remaining.isNegative
                      ? 0
                      : remaining.inSeconds;
                  final policy = Map<String, dynamic>.from(w['policy'] ?? {});
                  final deadline = DateTime.tryParse(
                    w['activate_before']?.toString() ?? '',
                  );
                  final expired =
                      end == null &&
                      deadline != null &&
                      now != null &&
                      !deadline.isAfter(now.add(elapsed.elapsed));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.strings.zeroTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (deadline != null)
                        Text(context.strings.zeroDeadline(deadline.toLocal().toString())),
                      if (policy['services'] != null)
                        Text(
                          context.strings.zeroServices((policy['services'] as List).join(', ')),
                        ),
                      if (expired)
                        Text(context.strings.zeroExpired)
                      else if (end == null)
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => activateReward(w['id']),
                          child: Text(
                            context.strings.zeroActivate,
                          ),
                        )
                      else
                        Text(
                          seconds == 0
                              ? context.strings.zeroAcceptedPreserved
                              : context.strings.zeroRemaining('${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'),
                        ),
                      Text(context.strings.zeroSaved(w['spent'].toString())),
                      Text(
                        policy['max_trips'] == null
                            ? context.strings.zeroNoTripCap
                            : context.strings.zeroTripCap(policy['max_trips'].toString()),
                      ),
                      Text(
                        policy['max_cost'] == null
                            ? context.strings.zeroNoCostCap
                            : context.strings.zeroCostCap(policy['max_cost'].toString()),
                      ),
                      Text(
                        context.strings.zeroIndependent,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        TextButton(onPressed: load, child: Text(context.strings.zeroRefresh)),
      ],
    );
  }
}
