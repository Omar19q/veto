import '../../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../services/supabase_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  static String preferenceKey(String userId) => 'visual_onboarding_v3_$userId';
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;
  bool _saving = false;
  String? _error;
  static const _content = [
    ('ride', 'اطلب مشوارك بسهولة', 'حدد مكانك ووجهتك، ومشوارك يبدأ بخطوة.'),
    (
      'captain',
      'اختر الكابتن المناسب',
      'اختار نوع المركبة المناسب؛ أول كابتن يقبل طلبك يتولى مشوارك.',
    ),
    ('tracking', 'تتبع رحلتك', 'شوف الكابتن على الخريطة ووقت الوصول التقديري.'),
    (
      'wallet',
      'ادفع كاش أو محفظة',
      'اختار طريقة الدفع، وباقي الكاش ممكن يرجع لمحفظتك.',
    ),
  ];

  static const _contentEn = [
    ('ride', 'Book in seconds', 'Pick your location and destination in a few taps.'),
    ('captain', 'The right ride for you', 'Choose car, motorcycle or parcel delivery.'),
    ('tracking', 'Track your captain', 'See where your captain is and the estimated arrival.'),
    ('wallet', 'Pay your way', 'Choose cash or wallet and see the fare before booking.'),
  ];

  Future<void> _finish() async {
    if (_saving) return;
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) {
      context.go('/sign-up-login-screen');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(OnboardingScreen.preferenceKey(userId), true)) {
        throw StateError('preference_not_saved');
      }
      // One-time onboarding across devices for this authenticated account.
      try {
        await SupabaseService.instance.client.auth.updateUser(
          UserAttributes(data: {'veto_visual_onboarding_seen_v34': true}),
        );
      } catch (_) { /* The local preference remains valid offline. */ }
      if (mounted) context.go('/home-screen');
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'تعذر حفظ اختيارك. جرّب تاني.';
        });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final english = context.strings.localeName.startsWith('en');
    final pages = english ? _contentEn : _content;
    final colors = Theme.of(context).colorScheme;
    return Directionality(
    textDirection: english ? TextDirection.ltr : TextDirection.rtl,
    child: Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'VETO',
                    style: TextStyle(
                      color: Color(0xFFFFCF60),
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : _finish,
                    child: Text(english ? 'Skip' : 'تخطي'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: pages.length,
                onPageChanged: (page) => setState(() => _index = page),
                itemBuilder: (_, i) {
                  final page = pages[i];
                  return LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedScale(
                                scale: _index == i ? 1 : 0.92,
                                duration: MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero : const Duration(milliseconds: 450),
                                child: SvgPicture.asset(
                                  'assets/onboarding/${page.$1}.svg',
                                  height: (constraints.maxHeight * 0.59).clamp(
                                    150.0,
                                    340.0,
                                  ),
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 26),
                              Text(
                                page.$2,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                page.$3,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  
                                  height: 1.8,
                                  fontSize: 15,
                                  color: Color(0xFFA9C4CF),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SmoothPageIndicator(
              controller: _pages,
              count: pages.length,
              effect: const ExpandingDotsEffect(
                activeDotColor: Color(0xFFFFCF60),
                dotColor: Color(0xFF345065),
                dotHeight: 8,
                dotWidth: 8,
                spacing: 9,
              ),
              onDotClicked: (page) => _pages.animateToPage(
                page,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCF60),
                    foregroundColor: const Color(0xFF091827),
                  ),
                  onPressed: _saving
                      ? null
                      : () {
                          if (_index == pages.length - 1) {
                            _finish();
                          } else {
                            _pages.nextPage(
                              duration: const Duration(milliseconds: 380),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _index == pages.length - 1
                              ? (english ? 'Get started' : 'ابدأ الآن')
                              : (english ? 'Next' : 'التالي'),
                          style: const TextStyle(
                            
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
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
}
