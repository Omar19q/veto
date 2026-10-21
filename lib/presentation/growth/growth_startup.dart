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
    if (!reduced && _audioEnabled && !kIsWeb) {
      _sound = AudioPlayer();
      try {
        await _sound!.play(
          AssetSource('sounds/veto_intro_chime.wav'),
          volume: 0.24,
        );
      } catch (error) {
        debugPrint('Optional intro chime unavailable: ${error.runtimeType}');
      }
    }
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
    return Stack(fit: StackFit.expand, children: [
      widget.child,
      if (_visible)
        Positioned.fill(
          child: AnimatedOpacity(
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
            opacity: _closing ? 0 : 1,
            child: Material(
              color: const Color(0xFF071728),
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
                                color: const Color(0xFFFFC534).withAlpha(35 + i * 12),
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
                            const Text('VETO SANYA',
                              style: TextStyle(fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.2,
                                color: Color(0xFFFFC534))),
                            const SizedBox(height: 9),
                            const Text('ثانية توفّرلك وقت وفلوس',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 21)),
                            const SizedBox(height: 8),
                            const Text('مشاوير أسرع  •  تكلفة أوضح  •  راحة أكتر',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFFB8C8D3),
                                fontSize: 12)),
                            const SizedBox(height: 26),
                            Container(width: 125, height: 3,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC534),
                                borderRadius: BorderRadius.circular(12))),
                          ],
                        ),
                      ),
                    );
                  },
                )),
                Positioned(
                  top: 8, right: 10,
                  child: IconButton(
                    tooltip: _audioEnabled ? 'إيقاف صوت المقدمة' : 'تفعيل صوت المقدمة',
                    onPressed: _toggleSound,
                    icon: Icon(_audioEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      color: Colors.white70),
                  ),
                ),
              ])),
            ),
          ),
        ),
    ]);
  }
}
