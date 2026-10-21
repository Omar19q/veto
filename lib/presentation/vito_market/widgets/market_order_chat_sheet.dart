import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/app_sound_service.dart';
import '../../../services/market_support_service.dart';
import 'dart:async';
import '../../../services/market_chat_backend.dart';
import '../../../l10n/strings.dart';
import '../../../theme/app_theme.dart';

class MarketOrderChatSheet extends StatefulWidget {
  const MarketOrderChatSheet({
    super.key,
    required this.orderId,
    required this.actorLabel,
    this.storeOrderNumber,
    this.backend,
  });

  final MarketChatBackend? backend;
  final String orderId;
  final String actorLabel;
  final dynamic storeOrderNumber;

  @override
  State<MarketOrderChatSheet> createState() => _MarketOrderChatSheetState();
}

class _MarketOrderChatSheetState extends State<MarketOrderChatSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _channel;
  bool _sending = false;
  bool _loading = true, _failed = false, _readFailed = false;
  late final MarketChatBackend _backend = widget.backend ?? MarketChatBackend();
  StreamSubscription<String?>? _auth;
  String? _uid;
  int _readRevision = 0;
  bool get _owns => mounted && _uid != null && _backend.accountId == _uid;

  @override
  void initState() {
    super.initState();
    _uid = _backend.accountId;
    _load();
    if (_uid != null) {
      _markRead();
      _channel = _backend.subscribe(widget.orderId, () async {
        if (!_owns) return;
        await AppSoundService.instance.playChat();
        if (!_owns) return;
        await _load();
        await _markRead();
      });
    }
    _auth = _backend.accountChanges.listen((uid) {
      if (!mounted || uid == _uid) return;
      _readRevision++;
      _channel?.unsubscribe();
      _channel = null;
      _input.clear();
      setState(() {
        _messages = [];
        _loading = false;
        _sending = false;
        _failed = true;
      });
    });
  }

  Future<void> _markRead() async {
    if (!_owns) return;
    try {
      await _backend.markRead(widget.orderId);
      if (_owns) setState(() => _readFailed = false);
    } catch (_) {
      if (_owns) setState(() => _readFailed = true);
    }
  }

  @override
  void dispose() {
    _auth?.cancel();
    _channel?.unsubscribe();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_owns) {
      if (mounted)
        setState(() {
          _messages = [];
          _loading = false;
          _failed = true;
        });
      return;
    }
    final revision = ++_readRevision;
    try {
      final value = await _backend.getMessages(widget.orderId);
      if (!_owns || revision != _readRevision) return;
      setState(() {
        _messages = value;
        _loading = false;
        _failed = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_owns && _scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {
      if (_owns && revision == _readRevision)
        setState(() {
          _loading = false;
          _failed = true;
          _messages = [];
        });
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || !_owns) return;
    setState(() => _sending = true);
    try {
      await _backend.send(widget.orderId, text);
      if (!_owns) return;
      if (_input.text.trim() == text) _input.clear();
      await _load();
    } catch (_) {
      if (_owns) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.marketChatSendFailed)),
        );
      }
    } finally {
      if (_owns) setState(() => _sending = false);
    }
  }

  Future<void> _support() async {
    final opened = await MarketSupportService.openWhatsApp(
      orderId: widget.orderId,
      storeOrderNumber: widget.storeOrderNumber,
      actorLabel: widget.actorLabel,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.marketChatSupportFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: Directionality.of(context),
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Icon(Icons.forum_rounded, color: AppTheme.gold),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.strings.marketChatTitle,
                      style: TextStyle(
                        
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: !_owns ? null : _support,
                    icon: Icon(Icons.support_agent_rounded),
                    tooltip: context.strings.marketChatSupport,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.whatsapp,
                    ),
                  ),
                ],
              ),
            ),
            if (_readFailed) Text(context.strings.marketChatReadFailed),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(color: AppTheme.gold),
                    )
                  : _failed
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.strings.marketChatLoadFailed,
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: _owns ? _load : null,
                            child: Text(context.strings.retry),
                          ),
                        ],
                      ),
                    )
                  : _messages.isEmpty
                  ? Center(
                      child: Text(
                        context.strings.marketChatEmpty,
                        style: TextStyle(
                          
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (_, index) => _bubble(_messages[index]),
                    ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF111827)
                    : Theme.of(context).colorScheme.surfaceContainer,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: _owns,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      style: TextStyle(
                        
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: context.strings.marketChatInput,
                        hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                        counterText: '',
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? Color(0xFF202B3F)
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending || !_owns ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: AppTheme.primary,
                    ),
                    icon: _sending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _bubble(Map<String, dynamic> message) {
    final mine = message['sender_user_id'] == _uid;
    final role = message['sender_role']?.toString() ?? '';
    final colors = _roleColors(role, mine);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .78,
        ),
        margin: EdgeInsets.only(bottom: 9),
        padding: EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: colors.$1,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: Border.all(color: colors.$3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mine ? context.strings.marketChatYou : _roleLabel(role),
              style: TextStyle(
                
                color: colors.$2.withValues(alpha: .82),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2),
            SelectableText(
              message['message_text']?.toString() ?? '',
              style: TextStyle(
                
                color: colors.$2,
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color, Color) _roleColors(String role, bool mine) {
    if (mine) {
      return (Color(0xFFFFC107), Color(0xFF101827), Color(0xFFFFD54F));
    }
    return switch (role) {
      'captain' => (Color(0xFF123C36), Colors.white, Color(0xFF2DD4BF)),
      'merchant' => (Color(0xFF3B2D16), Colors.white, Color(0xFFF59E0B)),
      'admin' => (Color(0xFF35245C), Colors.white, Color(0xFFA78BFA)),
      _ => (Color(0xFF1E3A5F), Colors.white, Color(0xFF60A5FA)),
    };
  }

  String _roleLabel(String role) => switch (role) {
    'captain' => context.strings.marketChatCaptain,
    'merchant' => context.strings.marketChatStore,
    'admin' => context.strings.marketChatAdmin,
    'customer' => context.strings.marketChatCustomer,
    _ => context.strings.marketChatParticipant,
  };
}
