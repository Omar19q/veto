import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class WaveDispatchStatus extends StatefulWidget {
  final String tripId;
  const WaveDispatchStatus({super.key, required this.tripId});
  @override
  State<WaveDispatchStatus> createState() => _WaveDispatchStatusState();
}

class _WaveDispatchStatusState extends State<WaveDispatchStatus> {
  TripRealtimeLease? lease;
  Map<String, dynamic> row = {};
  Timer? _tick;
  void watch() {
    lease?.unsubscribe();
    lease = SupabaseService.instance.subscribeToTripStatus(widget.tripId, (
      trip,
    ) {
      final dispatch = trip['dispatch'];
      if (mounted && dispatch is Map)
        setState(() => row = Map<String, dynamic>.from(dispatch));
    });
  }

  @override
  void initState() {
    super.initState();
    watch();
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && row['started_at'] != null) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant WaveDispatchStatus old) {
    super.didUpdateWidget(old);
    if (old.tripId != widget.tripId) watch();
  }

  @override
  void dispose() {
    lease?.unsubscribe();
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startedAt = DateTime.tryParse('${row['started_at'] ?? ''}')?.toUtc();
    final elapsed = startedAt == null
        ? null : DateTime.now().toUtc().difference(startedAt).inSeconds;
    // Do not use the 3-wave label: the backend expands through 6 radii.
    // The original dispatch start time is durable across app restarts.
    final radius = elapsed == null ? null
        : elapsed >= 60 ? '10'
        : elapsed >= 50 ? '8'
        : elapsed >= 40 ? '6'
        : elapsed >= 30 ? '4'
        : elapsed >= 20 ? '2.5' : '1';
    final label = row['status'] == 'expired'
        ? 'مدة البحث انتهت، تقدر تعيد الطلب'
        : row['status'] == 'stopped'
        ? 'انتهى البحث'
        : radius == null ? 'بندور على كابتن قريب'
        : 'بندور على كابتن قريب • حتى $radius كم';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          
          color: AppTheme.gold,
          fontSize: 11,
        ),
      ),
    );
  }
}
