import '../../../l10n/strings.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

bool isLiveCaptainOffer(Map<String, dynamic> offer, {DateTime? now}) {
  if (offer['offer_status'] != 'sent') return false;
  final expiry = DateTime.tryParse(offer['expires_at']?.toString() ?? '');
  return expiry == null || expiry.isAfter(now ?? DateTime.now());
}

enum CaptainPresence {
  offline,
  connecting,
  ready,
  busy,
  disconnected,
  unavailable,
}

bool isConfirmedCaptainGpsFresh(DateTime? fix, {DateTime? now}) {
  if (fix == null) return false;
  final age = (now ?? DateTime.now()).difference(fix);
  return age >= const Duration(seconds: -5) &&
      age <= const Duration(seconds: 90);
}

CaptainPresence resolveCaptainPresence({
  required bool online,
  required bool changing,
  required bool disconnected,
  required bool busy,
  required bool unavailable,
}) {
  if (changing) return CaptainPresence.connecting;
  if (disconnected) return CaptainPresence.disconnected;
  if (busy) return CaptainPresence.busy;
  if (unavailable) return CaptainPresence.unavailable;
  return online ? CaptainPresence.ready : CaptainPresence.offline;
}

class CaptainPresenceCard extends StatelessWidget {
  final CaptainPresence state;
  final bool online;
  final bool locationFresh;
  final String? reason;
  final VoidCallback onToggle;
  const CaptainPresenceCard({
    super.key,
    required this.state,
    required this.online,
    required this.onToggle,
    this.reason,
    this.locationFresh = true,
  });
  static String label(CaptainPresence state) => switch (state) {
    CaptainPresence.offline => 'غير متصل',
    CaptainPresence.connecting => 'جارٍ تحديث الاتصال وتحديد الموقع',
    CaptainPresence.ready => 'متصل وجاهز لاستقبال الرحلات',
    CaptainPresence.busy => 'مشغول برحلة',
    CaptainPresence.disconnected => 'انقطع الاتصال',
    CaptainPresence.unavailable => 'الحساب غير متاح',
  };
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final changing = state == CaptainPresence.connecting;
    final ready = state == CaptainPresence.ready && locationFresh;
    final description =
        reason ??
        (state == CaptainPresence.ready && !locationFresh
            ? context.strings.captain20d90f0e
            : switch (state) {
                CaptainPresence.offline => context.strings.presencec81ed735,
                CaptainPresence.connecting => context.strings.presencee267108e,
                CaptainPresence.ready => context.strings.presence6d021561,
                CaptainPresence.busy => context.strings.presence2dbd1bcf,
                CaptainPresence.disconnected =>
                  context.strings.presence2038f1aa,
                CaptainPresence.unavailable => context.strings.presence94d187fa,
              });
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: dark
              ? const LinearGradient(
                  colors: [Color(0xFF252336), Color(0xFF111723)],
                )
              : LinearGradient(
                  colors: [colors.surfaceContainerHigh, colors.surface],
                ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: (dark ? AppTheme.gold : colors.primary).withAlpha(100),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  ready
                      ? Icons.radar_rounded
                      : state == CaptainPresence.disconnected
                      ? Icons.wifi_off_rounded
                      : Icons.power_settings_new_rounded,
                  color: (dark ? AppTheme.gold : colors.primary),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state == CaptainPresence.ready && !locationFresh
                        ? context.strings.captainGpsNeedsUpdate
                        : switch (state) {
                            CaptainPresence.offline =>
                              context.strings.presencecbc96ded,
                            CaptainPresence.connecting =>
                              context.strings.presencee6302b21,
                            CaptainPresence.ready =>
                              context.strings.presencea781f074,
                            CaptainPresence.busy =>
                              context.strings.presence0aeaba38,
                            CaptainPresence.disconnected =>
                              context.strings.presence05691d14,
                            CaptainPresence.unavailable =>
                              context.strings.presencee28d58d1,
                          },
                    style: TextStyle(
                      color: (dark ? AppTheme.textPrimary : colors.onSurface),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: TextStyle(
                color: (dark
                    ? AppTheme.textSecondary
                    : colors.onSurfaceVariant),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: changing ? null : onToggle,
              style: FilledButton.styleFrom(
                backgroundColor: (dark ? AppTheme.gold : colors.primary),
                foregroundColor: (dark ? AppTheme.primary : colors.onPrimary),
                minimumSize: const Size.fromHeight(52),
              ),
              icon: changing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.power_settings_new_rounded),
              label: Text(
                changing
                    ? context.strings.presence7b43f77f
                    : online
                    ? context.strings.presence7b3b2ab3
                    : context.strings.presence52edad40,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A local deadline display; expiry never creates a polling request.
class CaptainOfferDeadline extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback onExpired;
  const CaptainOfferDeadline({
    super.key,
    required this.expiresAt,
    required this.onExpired,
  });
  @override
  State<CaptainOfferDeadline> createState() => _CaptainOfferDeadlineState();
}

class _CaptainOfferDeadlineState extends State<CaptainOfferDeadline> {
  Timer? _timer;
  bool _expired = false;
  int get _seconds =>
      (widget.expiresAt.difference(DateTime.now()).inMilliseconds / 1000)
          .ceil()
          .clamp(0, 86400);
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_seconds == 0 && !_expired) {
        _expired = true;
        _timer?.cancel();
        widget.onExpired();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      _seconds == 0
          ? context.strings.presenceecaefa5c
          : context.strings.captainOfferSeconds(_seconds),
      style: TextStyle(
        color: (Theme.of(context).brightness == Brightness.dark
            ? AppTheme.gold
            : Theme.of(context).colorScheme.primary),
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
