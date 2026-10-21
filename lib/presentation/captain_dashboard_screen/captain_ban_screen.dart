import '../../l10n/strings.dart';
import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';

String formatBanCountdown(Duration remaining) {
  final total = remaining.inSeconds.clamp(0, 9999999);
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

class CaptainBanScreen extends StatefulWidget {
  final DateTime bannedUntil;
  final DateTime serverNow;
  final String reason;
  final VoidCallback onRefresh;
  const CaptainBanScreen({
    super.key,
    required this.bannedUntil,
    required this.serverNow,
    required this.reason,
    required this.onRefresh,
  });
  @override
  State<CaptainBanScreen> createState() => _CaptainBanScreenState();
}

class _CaptainBanScreenState extends State<CaptainBanScreen> {
  final _elapsed = Stopwatch()..start();
  Timer? _timer;
  bool _sent = false, _sending = false, _expiryRequested = false;
  Duration get _remaining =>
      widget.bannedUntil.difference(widget.serverNow.add(_elapsed.elapsed));
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_remaining <= Duration.zero && !_expiryRequested) {
        _expiryRequested = true;
        widget.onRefresh();
      }
    });
  }

  @override
  void didUpdateWidget(covariant CaptainBanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _elapsed.reset();
    if (oldWidget.bannedUntil != widget.bannedUntil) {
      _sent = false;
      _expiryRequested = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsed.stop();
    super.dispose();
  }

  Future<void> _appeal() async {
    if (_sent || _sending) return;
    final text = TextEditingController(
      text: context.strings.banDefaultAppeal,
    );
    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.strings.banAppealTitle),
        content: TextField(
          controller: text,
          maxLength: 1000,
          maxLines: 4,
          decoration: InputDecoration(hintText: context.strings.banAppealHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.strings.banBack),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, text.text.trim()),
            child: Text(context.strings.banSendAppeal),
          ),
        ],
      ),
    );
    text.dispose();
    if (!mounted || message == null) return;
    if (message.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.banClearReason)),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await SupabaseService.instance.client.rpc(
        'submit_captain_ban_appeal',
        params: {'p_message': message},
      );
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.banSendFailed)),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: Directionality.of(context),
    child: Scaffold(
      backgroundColor: const Color(0xFF0B1828),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFCF60).withAlpha(24),
                      border: Border.all(
                        color: const Color(0xFFFFCF60).withAlpha(90),
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_clock_rounded,
                      color: Color(0xFFFFCF60),
                      size: 70,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    context.strings.banTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.strings.banReason(widget.reason),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      
                      height: 1.8,
                      color: Color(0xFFBFCCD8),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF172D42),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Text(
                          context.strings.banRemaining,
                          style: TextStyle(
                            
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            formatBanCountdown(_remaining),
                            style: const TextStyle(
                              fontFeatures: [FontFeature.tabularFigures()],
                              color: Color(0xFFFFCF60),
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (_remaining <= Duration.zero)
                          Text(
                            context.strings.banExpiryConfirming,
                            style: TextStyle(
                              color: Colors.white70,
                              
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.strings.banReturnOnline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      
                      color: Colors.white54,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: _sending || _sent ? null : _appeal,
                    icon: const Icon(Icons.support_agent_rounded),
                    label: Text(
                      _sent
                          ? context.strings.banAppealSent
                          : _sending
                          ? context.strings.banSending
                          : context.strings.banAppeal,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onRefresh,
                    child: Text(context.strings.banRefreshAccount),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
