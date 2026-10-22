import 'captain_profile_card_v11.dart';
import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';

class CaptainProfileSheetV10 extends StatefulWidget {
  final String tripId;
  const CaptainProfileSheetV10({super.key, required this.tripId});

  @override
  State<CaptainProfileSheetV10> createState() => _CaptainProfileSheetV10State();
}

class _CaptainProfileSheetV10State extends State<CaptainProfileSheetV10> {
  late Future<dynamic> data;

  @override
  void initState() {
    super.initState();
    data = _load();
  }

  Future<dynamic> _load() => SupabaseService.instance.client
      .rpc('captain_profile_v13', params: {'p_trip_id': widget.tripId})
      .timeout(const Duration(seconds: 10));

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final primaryAccent = isDark ? const Color(0xFFFFC400) : colorScheme.primary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .88,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(12, 8, 12, bottom + 14),
          child: FutureBuilder<dynamic>(
            future: data,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: 260,
                  child: Center(
                    child: CircularProgressIndicator(color: primaryAccent),
                  ),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return SizedBox(
                  height: 250,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_off_rounded,
                          color: primaryAccent,
                          size: 38,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'بيانات الكابتن ما اتحملتش',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => setState(() => data = _load()),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text(
                            'إعادة المحاولة',
                            style: TextStyle(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final profile = Map<String, dynamic>.from(snapshot.data as Map);
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: CaptainProfileCardV11(profile: profile),
              );
            },
          ),
        ),
      ),
    );
  }
}
