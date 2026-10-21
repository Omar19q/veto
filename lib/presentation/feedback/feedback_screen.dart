import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';
import '../../services/customer_feedback_backend.dart';
import '../../l10n/strings.dart';
import '../../theme/app_theme.dart';

class FeedbackScreen extends StatefulWidget {
  final String initialType;
  final CustomerFeedbackBackend? backend;

  const FeedbackScreen({
    super.key,
    this.initialType = 'suggestion',
    this.backend,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  late String _type;
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;
  late final CustomerFeedbackBackend _backend =
      widget.backend ?? CustomerFeedbackBackend();
  StreamSubscription<String?>? _auth;
  String? _uid;
  int _accountEpoch = 0;
  bool get _owns => mounted && _uid != null && _backend.accountId == _uid;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType == 'complaint' ? 'complaint' : 'suggestion';
    _uid = _backend.accountId;
    _auth = _backend.accountChanges.listen((uid) {
      if (!mounted || uid == _uid) return;
      _accountEpoch++;
      _controller.clear();
      setState(() => _sending = false);
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_owns) return;
    final epoch = _accountEpoch;
    bool ownsRequest() => _owns && epoch == _accountEpoch;
    final message = _controller.text.trim();

    if (message.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.feedbackClearMessage,
            style: TextStyle(),
          ),
        ),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final result = await _backend.submit(type: _type, message: message);

      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'feedback_failed');
      }

      if (!ownsRequest()) return;

      _controller.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.feedbackSent,
            style: TextStyle(),
          ),
        ),
      );

      context.pop();
    } catch (e) {
      if (!ownsRequest()) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.feedbackUnconfirmed,
            style: TextStyle(),
          ),
        ),
      );
    } finally {
      if (ownsRequest()) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isComplaint = _type == 'complaint';

    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            isComplaint
                ? context.strings.feedbackComplaint
                : context.strings.feedbackSuggestion,
            style: TextStyle(
              
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.all(18),
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.strings.feedbackType,
                    style: TextStyle(
                      
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeChoice(
                          label: context.strings.feedbackSuggestion,
                          icon: Icons.lightbulb_outline_rounded,
                          selected: _type == 'suggestion',
                          onTap: () {
                            if (_sending || !_owns) return;
                            setState(() => _type = 'suggestion');
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _TypeChoice(
                          label: context.strings.feedbackComplaint,
                          icon: Icons.report_problem_outlined,
                          selected: _type == 'complaint',
                          onTap: () {
                            if (_sending || !_owns) return;
                            setState(() => _type = 'complaint');
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (!_owns) Text(context.strings.feedbackAccountChanged),
                  TextField(
                    controller: _controller,
                    enabled: _owns && !_sending,
                    maxLines: 8,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: isComplaint
                          ? context.strings.feedbackComplaintHint
                          : context.strings.feedbackSuggestionHint,
                      hintStyle: TextStyle(
                        
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                        borderSide: BorderSide(color: AppTheme.gold),
                      ),
                    ),
                  ),
                  SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _sending || !_owns ? null : _send,
                      icon: _sending
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.send_rounded),
                      label: Text(
                        _sending
                            ? context.strings.feedbackSending
                            : context.strings.feedbackSend,
                        style: TextStyle(
                          
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChoice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 160),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.gold.withAlpha(30)
              : Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppTheme.gold
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected
                  ? AppTheme.gold
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppTheme.gold
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
