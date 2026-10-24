import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// V62 customer/captain app introduction. Visual brand is independent of the
/// financial Growth feature switch; no marketing RPC or wallet operation runs.
/// The intro plays once per app process, not after every router transition.
class GrowthStartup extends StatefulWidget {
  const GrowthStartup({super.key, required this.child});
  final Widget child;

  @visibleForTesting
  static void resetForTesting() {
    _GrowthStartupState._alreadyShownInProcess = false;
  }

  @override
  State<GrowthStartup> createState() => _GrowthStartupState();
}

class _GrowthStartupState extends State<GrowthStartup>
    with SingleTickerProviderStateMixin {
  static bool _alreadyShownInProcess = false;
  late final AnimationController _motion;
  AudioPlayer? _sound;
  Timer? _closeTimer;
  Timer? _removeTimer;
  bool _visible = false;
  bool _closing = false;
  bool _audioEnabled = true;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
    if (!_alreadyShownInProcess) {
      _alreadyShownInProcess = true;
      _showIntroduction();
    }
  }

  Future<void> _showIntroduction() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      _audioEnabled = preferences.getBool('growth_startup_sound') ?? true;
    } catch (error) {
      debugPrint('Intro settings unavailable: ${error.runtimeType}');
    }
    if (!mounted) return;
    final reduced = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    setState(() => _visible = true);
    if (!reduced) _motion.forward();
    if (!mounted) return;
    _closeTimer = Timer(Duration(milliseconds: reduced ? 200 : 1400), () {
      if (!mounted) return;
      setState(() => _closing = true);
      _removeTimer = Timer(Duration(milliseconds: reduced ? 0 : 250), () {
        if (mounted) setState(() => _visible = false);
      });
    });
  }

  Future<void> _toggleSound() async {
    final next = !_audioEnabled;
    setState(() => _audioEnabled = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('growth_startup_sound', next);
      if (!next) await _sound?.stop();
    } catch (error) {
      debugPrint('Intro mute setting not saved: ${error.runtimeType}');
    }
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _removeTimer?.cancel();
    _motion.dispose();
    final player = _sound;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF071728) : const Color(0xFFF8FAFC);
    final brandGold = isDark ? const Color(0xFFFFC534) : const Color(0xFFD97706);
    final titleColor = isDark ? Colors.white : const Color(0xFF0B0F1A);
    final subtitleColor = isDark ? const Color(0xFFB8C8D3) : const Color(0xFF64748B);
    final barColor = isDark ? const Color(0xFFFFC534) : const Color(0xFFE5A800);

    return Stack(fit: StackFit.expand, children: [
      widget.child,
      if (_visible)
        Positioned.fill(
          child: AnimatedOpacity(
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
            opacity: _closing ? 0 : 1,
            child: Material(
              color: bgColor,
              child: SafeArea(child: Stack(children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _motion,
                      builder: (context, _) {
                        final t = reduceMotion ? 1.0 : _motion.value;
                        return LayoutBuilder(builder: (context, layout) => Stack(children: [
                          ...List.generate(6, (i) => Positioned(
                            top: layout.maxHeight * (.22 + i * .095),
                            left: -80 + (layout.maxWidth + 120) * (t * (1 + i * .025)),
                            child: Container(
                              width: 125 + i * 14,
                              height: 2,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFFFFC534).withAlpha(35 + i * 12)
                                    : const Color(0xFFCBD5E1).withAlpha(80 + i * 20),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )),
                        ]));
                      },
                    ),
                  ),
                ),
                Center(child: AnimatedBuilder(
                  animation: _motion,
                  builder: (context, _) {
                    final t = reduceMotion ? 1.0 : Curves.easeOutCubic.transform(_motion.value);
                    return Opacity(
                      opacity: t.clamp(0.0, 1.0).toDouble(),
                      child: Transform.translate(
                        offset: Offset((1 - t) * 50, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              label: 'فيتو ثانية، أسرع في مشوارك وأوفر في فلوسك',
                              child: SvgPicture.asset(
                                'assets/images/veto_sanya_logo_mark.svg',
                                width: 118, height: 118,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text('VETO SANYA',
                              style: TextStyle(fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.2,
                                color: brandGold)),
                            const SizedBox(height: 9),
                            Text('ثانية توفّرلك وقت وفلوس',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: titleColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 21)),
                            const SizedBox(height: 8),
                            Text('مشاوير أسرع  •  تكلفة أوضح  •  راحة أكتر',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: subtitleColor,
                                fontSize: 12)),
                            const SizedBox(height: 26),
                            Container(width: 125, height: 3,
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(12))),
                          ],
                        ),
                      ),
                    );
                  },
                )),
              ])),
            ),
          ),
        ),
    ]);
  }
}
