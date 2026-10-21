import '../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class CaptainComboIntroduction {
  static Future<bool>? _pending;
  static Future<bool> ensure(BuildContext context, String captainId) {
    final existing = _pending;
    if (existing != null) return existing;
    final work = _show(context, captainId);
    _pending = work;
    return work.whenComplete(() => _pending = null);
  }

  static Future<bool> _show(BuildContext context, String captainId) async {
    final db = SupabaseService.instance.client;
    final prefs = await SharedPreferences.getInstance();
    final key = 'captain_combo_understood_v4_$captainId';
    // Server is authoritative across devices/reinstallation; prefs cache the acknowledgement.
    final acknowledged =
        await db.rpc('captain_combo_onboarding_status') == true;
    if (acknowledged) {
      await prefs.setBool(key, true);
      return true;
    }
    if (!context.mounted) return false;
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: const Color(0xFF111B2D),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          builder: (_) => CaptainComboSheet(
            onAcknowledge: () async {
              await db.rpc('acknowledge_captain_combo_onboarding');
              await prefs.setBool(key, true);
            },
          ),
        ) ??
        false;
  }
}

class CaptainComboSheet extends StatefulWidget {
  final Future<void> Function() onAcknowledge;
  const CaptainComboSheet({required this.onAcknowledge});
  @override
  State<CaptainComboSheet> createState() => CaptainComboSheetState();
}

class CaptainComboSheetState extends State<CaptainComboSheet> {
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: Directionality.of(context),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFDA7B), Color(0xFFE4A12B)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.gold.withAlpha(35),
                    blurRadius: 35,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: const Icon(
                Icons.shopping_bag_rounded,
                size: 60,
                color: Color(0xFF182238),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              context.strings.comboCaptainTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.strings.comboCaptainDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                
                fontSize: 14,
                color: Color(0xFFB5C1D5),
              ),
            ),
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                context.strings.comboCaptainSteps,
                style: TextStyle(
                  
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _Step('1️⃣', context.strings.comboCaptainBuy),
            _Step(
              '2️⃣',
              context.strings.comboCaptainDeliver,
            ),
            _Step(
              '3️⃣',
              context.strings.comboCaptainAgree,
            ),
            const SizedBox(height: 12),
            Text(
              context.strings.comboCaptainLimit,
              textAlign: TextAlign.center,
              style: TextStyle(
                
                color: AppTheme.gold,
                fontSize: 12,
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: const Color(0xFF111B2D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: busy
                    ? null
                    : () async {
                        setState(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          await widget.onAcknowledge();
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (_) {
                          if (mounted)
                            setState(() {
                              busy = false;
                              error =
                                  context.strings.comboCaptainSaveFailed;
                            });
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        context.strings.comboCaptainUnderstood,
                        style: TextStyle(
                          
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Step extends StatelessWidget {
  final String number, text;
  const _Step(this.number, this.text);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF1C293E),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(number, style: const TextStyle(fontSize: 21)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              
              color: Colors.white,
              height: 1.8,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}
