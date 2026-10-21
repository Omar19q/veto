import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../services/supabase_service.dart';
import '../../../l10n/strings.dart';

class ExtraRequestsField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final Widget? illustration;
  const ExtraRequestsField({
    super.key,
    required this.controller,
    this.onChanged,
    this.illustration,
  });
  @override
  State<ExtraRequestsField> createState() => _ExtraRequestsFieldState();
}

class _ExtraRequestsFieldState extends State<ExtraRequestsField> {
  final _target = GlobalKey();
  final _focus = FocusNode();
  late final ShowcaseView _showcase;
  late final String _scope;
  String? _preferenceKey;
  bool _expanded = false;
  bool _opening = false;
  static final Set<String> _presenting = {};

  @override
  void initState() {
    super.initState();
    _expanded = widget.controller.text.trim().isNotEmpty;
    _scope = 'extra_requests_${identityHashCode(this)}';
    _showcase = ShowcaseView.register(
      scope: _scope,
      onFinish: () => unawaited(_rememberTooltip()),
      onDismiss: (_) => unawaited(_rememberTooltip()),
    );
    // The optional shopping introduction must never block ordinary booking.
    // It remains available when the customer explicitly opens this feature.
  }

  Future<void> _rememberTooltip() async {
    final key = _preferenceKey;
    if (key != null) {
      await (await SharedPreferences.getInstance()).setBool(
        '${key}_tooltip',
        true,
      );
    }
  }

  Future<void> _introduce() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;
    final key = 'extra_requests_onboarding_v2_$userId';
    _preferenceKey = key;
    if (!_presenting.add(key)) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted || SupabaseService.instance.currentUser?.id != userId) return;
      final previouslySeenOnAccount = SupabaseService.instance.client.auth
              .currentUser?.userMetadata?['veto_extra_tip_seen_v34'] == true;
      if (previouslySeenOnAccount) {
        await preferences.setBool('${key}_dialog', true);
        await preferences.setBool('${key}_tooltip', true);
        return;
      }
      // Upgrade legacy device-only acknowledgement to an account marker.
      if (preferences.getBool('${key}_dialog') == true) {
        try {
          await SupabaseService.instance.client.auth.updateUser(
            UserAttributes(data: {'veto_extra_tip_seen_v34': true}),
          );
        } catch (_) { /* Already acknowledged on this device. */ }
      }
      if (preferences.getBool('${key}_dialog') != true) {
        if (!mounted || SupabaseService.instance.currentUser?.id != userId) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 140,
                        child:
                            widget.illustration ??
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xff18b9a5),
                                    Color(0xff16273a),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shopping_bag_rounded,
                                    color: Colors.amber,
                                    size: 52,
                                  ),
                                  SizedBox(width: 12),
                                  Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 12),
                                  Icon(
                                    Icons.directions_car_rounded,
                                    color: Colors.white,
                                    size: 64,
                                  ),
                                ],
                              ),
                            ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        context.strings.extraIntroTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 21,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.strings.extraIntroBody,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(context.strings.extraIntroContinue),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ),
        );
        if (!mounted || SupabaseService.instance.currentUser?.id != userId) return;
        await preferences.setBool('${key}_dialog', true);
        await preferences.setBool('${key}_tooltip', true);
        try {
          await SupabaseService.instance.client.auth.updateUser(
            UserAttributes(data: {'veto_extra_tip_seen_v34': true}),
          );
        } catch (_) { /* Local once-only marker remains active. */ }
      }
      if (!mounted || preferences.getBool('${key}_tooltip') == true) return;
      final targetContext = _target.currentContext;
      if (targetContext == null || !targetContext.mounted) return;
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 400),
        alignment: 0.4,
      );
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _target.currentContext != null)
          _showcase.startShowCase([_target]);
      });
    } finally {
      _presenting.remove(key);
    }
  }

  Future<void> _open() async {
    if (_opening) return;
    final owner = SupabaseService.instance.currentUser?.id;
    setState(() => _opening = true);
    _showcase.dismiss();
    try {
      await _introduce();
      if (!mounted || SupabaseService.instance.currentUser?.id != owner) return;
      setState(() => _expanded = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    _showcase.unregister();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Showcase(
        key: _target,
        scope: _scope,
        title: context.strings.extraFeatureTitle,
        description: context.strings.extraFeatureTip,
        child: OutlinedButton.icon(
          onPressed: _opening ? null : _open,
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: Text(context.strings.extraFeatureTitle),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 250),
        child: !_expanded
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 4,
                  textDirection: Directionality.of(context),
                  onChanged: widget.onChanged,
                  decoration: InputDecoration(
                    labelText: context.strings.extraFeatureLabel,
                    hintText: context.strings.extraFeatureHint,
                    helperText: context.strings.extraFeatureHelper,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
      ),
    ],
  );
}
