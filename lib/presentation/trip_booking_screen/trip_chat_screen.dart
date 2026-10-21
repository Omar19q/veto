import '../../l10n/strings.dart';
import 'widgets/localized_chat_failure.dart';
import 'package:vetosanya/widgets/captain_photo_v16.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/trip_chat_inbox.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import './widgets/trip_quick_replies.dart';

class TripChatScreen extends StatefulWidget {
  final String tripId;

  const TripChatScreen({super.key, required this.tripId});

  @override
  State<TripChatScreen> createState() => _TripChatScreenState();
}

class _TripChatScreenState extends State<TripChatScreen>
    with WidgetsBindingObserver {
  Color get _chatGold => Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : Theme.of(context).colorScheme.primary;
  Color get _chatPrimary => Theme.of(context).brightness == Brightness.dark ? AppTheme.primary : Theme.of(context).colorScheme.onPrimary;
  Color get _chatTextPrimary => Theme.of(context).brightness == Brightness.dark ? AppTheme.textPrimary : Theme.of(context).colorScheme.onSurface;
  Color get _chatTextSecondary => Theme.of(context).brightness == Brightness.dark ? AppTheme.textSecondary : Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _chatTextMuted => Theme.of(context).brightness == Brightness.dark ? AppTheme.textMuted : Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _chatSurface => Theme.of(context).brightness == Brightness.dark ? AppTheme.surface : Theme.of(context).colorScheme.surface;
  Color get _chatSurfaceVariant => Theme.of(context).brightness == Brightness.dark ? AppTheme.surfaceVariant : Theme.of(context).colorScheme.surfaceContainerHigh;
  Color get _chatBackgroundDark => Theme.of(context).brightness == Brightness.dark ? AppTheme.backgroundDark : Theme.of(context).colorScheme.surface;
  Color get _chatCardBorder => Theme.of(context).brightness == Brightness.dark ? AppTheme.cardBorder : Theme.of(context).colorScheme.outlineVariant;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _channel;
  bool _loadingRequest = false;
  bool _chatReady = false;
  String? _loadError;
  String? _pendingRequest;
  String? _pendingText;

  String? _myUserId;
  String? _otherName;
  String get _displayOtherName => _otherName ?? (_chatReady ? (_isCaptain ? context.strings.chatCustomer : context.strings.chatCaptain) : context.strings.chatTitle);
  String? _otherPhoto;
  bool _loading = true;
  bool _sending = false;
  bool _isCaptain = false;
  bool _hasOlder = true;
  bool _loadingOlder = false;
  void _onScroll() {
    if (_scrollController.hasClients && _scrollController.offset < 80) {
      unawaited(_loadOlder());
    }
  }

  Future<void> _loadOlder() async {
    if (_loading ||
        !_chatReady ||
        _loadingOlder ||
        !_hasOlder ||
        _messages.isEmpty)
      return;
    _loadingOlder = true;
    final first = _messages.first;
    final oldExtent = _scrollController.position.maxScrollExtent;
    final oldOffset = _scrollController.offset;
    try {
      final rows = await SupabaseService.instance.getTripChatMessages(
        widget.tripId,
        before: first['created_at'].toString(),
        beforeId: first['id'].toString(),
      );
      if (!mounted) return;
      setState(() {
        _mergeMessages(rows);
        _hasOlder = rows.length == 100;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(
            oldOffset + _scrollController.position.maxScrollExtent - oldExtent,
          );
        }
      });
    } catch (_) {
      /* Keep cursor for a later retry. */
    } finally {
      _loadingOlder = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_channel != null) {
      unawaited(SupabaseService.instance.client.removeChannel(_channel!));
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Recover chat messages that arrived while the app was suspended.
      if (_chatReady) {
        unawaited(_resync());
      } else {
        _load();
      }
    }
  }

  Future<void> _load() async {
    if (_loadingRequest) return;
    _loadingRequest = true;
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) throw Exception('not_authenticated');

      _myUserId = user.id;
      _isCaptain = false;

      final data = await SupabaseService.instance.getTripParticipantContext(
        widget.tripId,
      );

      if (!mounted) return;
      if (data == null) throw Exception('chat_not_ready');

      final customerRaw = data['customer'];
      final captainRaw = data['captain'];

      final customer = customerRaw is Map
          ? Map<String, dynamic>.from(customerRaw)
          : <String, dynamic>{};
      final captain = captainRaw is Map
          ? Map<String, dynamic>.from(captainRaw)
          : <String, dynamic>{};

      if (data['participant_role'] == 'customer') {
        _otherName = captain['full_name']?.toString();
        _otherPhoto =
            captain['profile_photo_url']?.toString() ??
            captain['profile_photo']?.toString();
      } else if (data['participant_role'] == 'captain') {
        _isCaptain = true;
        _otherName = customer['full_name']?.toString();
        _otherPhoto = customer['profile_photo_url']?.toString();
      } else {
        throw Exception('not_trip_participant');
      }

      _chatReady = data['chat_ready'] == true;
      if (!_chatReady) throw StateError('captain_not_assigned');
      _channel ??= SupabaseService.instance.subscribeToChatMessages(
        widget.tripId,
        (message) {
          if (!mounted) return;
          setState(() => _mergeMessages([message]));
          unawaited(TripChatInbox.instance.markVisibleRead());
          _scrollToBottom();
        },
        onReconnect: () => unawaited(_resync()),
      );
      final messages = await SupabaseService.instance.getTripChatMessages(
        widget.tripId,
      );
      if (!mounted) return;
      setState(() {
        _mergeMessages(messages);
        _hasOlder = messages.length == 100;
        _loading = false;
        _loadError = null;
      });
      unawaited(TripChatInbox.instance.markVisibleRead());
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      setState(
        () => _loadError = error.toString().contains('captain_not_assigned')
            ? context.strings.chatNotReady
            : error.toString().contains('not_trip_participant')
            ? context.strings.chatParticipantOnly
            : context.strings.chatLoadFailed,
      );
    } finally {
      _loadingRequest = false;
    }
  }

  void _mergeMessages(List<Map<String, dynamic>> rows) {
    final byId = {for (final m in _messages) m['id'].toString(): m};
    for (final m in rows) {
      byId[m['id'].toString()] = m;
    }
    _messages
      ..clear()
      ..addAll(byId.values);
    _messages.sort((a, b) {
      final time = a['created_at'].toString().compareTo(
        b['created_at'].toString(),
      );
      return time != 0
          ? time
          : a['id'].toString().compareTo(b['id'].toString());
    });
  }

  bool _resyncing = false;
  Future<void> _resync() async {
    if (_resyncing || !mounted) return;
    _resyncing = true;
    try {
      var cursor = _messages.isEmpty ? null : _messages.last;
      while (mounted) {
        final rows = await SupabaseService.instance.getTripChatMessages(
          widget.tripId,
          after: cursor?['created_at']?.toString(),
          afterId: cursor?['id']?.toString(),
        );
        if (!mounted) return;
        setState(() => _mergeMessages(rows));
        if (rows.length < 100 || cursor == null) break;
        cursor = rows.last;
      }
      unawaited(TripChatInbox.instance.markVisibleRead());
    } catch (_) {
      /* Explicit retry and reconnect recover the snapshot. */
    } finally {
      _resyncing = false;
    }
  }

  Future<void> _send() => _sendText(_controller.text, fromComposer: true);

  Future<void> _sendText(String rawText, {bool fromComposer = false}) async {
    final text = rawText.trim();

    if (text.isEmpty || _sending || !_chatReady) {
      return;
    }

    setState(() => _sending = true);

    try {
      if (_pendingText != text) {
        _pendingText = text;
        _pendingRequest = SupabaseService.newFinancialRequestId();
      }
      final message = await SupabaseService.instance.sendTripChatMessage(
        tripId: widget.tripId,
        message: text,
        requestId: _pendingRequest,
      );
      if (!mounted) return;
      if (fromComposer && _controller.text.trim() == text) _controller.clear();
      setState(() => _mergeMessages([message]));
      _pendingText = null;
      _pendingRequest = null;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedChatFailure(context, error),
            style: const TextStyle(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: _chatBackgroundDark,
        appBar: AppBar(
          backgroundColor: _chatSurface,
          elevation: 0,
          titleSpacing: 0,
          title: Row(
            children: [
              _photo(),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _displayOtherName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:  TextStyle(
                    
                    color: _chatTextPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: _loading
            ?  Center(
                child: CircularProgressIndicator(color: _chatGold),
              )
            : Column(
                children: [
                  Expanded(
                    child: _messages.isEmpty
                        ?  Center(
                            child: Text(
                              context.strings.chatEmpty,
                              style: TextStyle(
                                
                                color: _chatTextSecondary,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final mine =
                                  msg['sender_id']?.toString() == _myUserId;

                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 310,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 9),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? _chatGold
                                        : _chatSurface,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(17),
                                      topRight: const Radius.circular(17),
                                      bottomLeft: Radius.circular(
                                        mine ? 17 : 5,
                                      ),
                                      bottomRight: Radius.circular(
                                        mine ? 5 : 17,
                                      ),
                                    ),
                                    border: Border.all(
                                      color: mine
                                          ? _chatGold
                                          : _chatCardBorder,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mine ? context.strings.chatYou : _displayOtherName,
                                        style: TextStyle(
                                          
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: mine
                                              ? _chatPrimary.withAlpha(180)
                                              : _chatTextSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        msg['message']?.toString() ?? '',
                                        style: TextStyle(
                                          
                                          color: mine
                                              ? _chatPrimary
                                              : _chatTextPrimary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (_loadError != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            _loadError!,
                            style:  TextStyle(color: _chatTextPrimary),
                          ),
                          TextButton(
                            onPressed: _load,
                            child:  Text(context.strings.chatRetry),
                          ),
                        ],
                      ),
                    ),
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      color: _chatSurface,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TripQuickReplies(
                            isCaptain: _isCaptain,
                            enabled: !_sending && _chatReady,
                            onSend: (text) => _sendText(text),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  minLines: 1,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.newline,
                                  style:  TextStyle(
                                    
                                    color: _chatTextPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: context.strings.chatCompose,
                                    hintStyle:  TextStyle(
                                      
                                      color: _chatTextMuted,
                                    ),
                                    filled: true,
                                    fillColor: _chatSurfaceVariant,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 11,
                                    ),
                                  ),
                                  onSubmitted: (_) => _send(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: _sending ? null : _send,
                                style: IconButton.styleFrom(
                                  backgroundColor: _chatGold,
                                  foregroundColor: _chatPrimary,
                                  minimumSize: const Size(48, 48),
                                ),
                                icon: _sending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _photo() {
    if (_otherPhoto != null && _otherPhoto!.isNotEmpty) {
      return ClipOval(
        child: Image(image: captainPhotoV16(_otherPhoto!),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackAvatar(),
        ),
      );
    }
    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    return CircleAvatar(
      radius: 20,
      backgroundColor: _chatGold.withAlpha(35),
      child:  Icon(Icons.person_rounded, color: _chatGold),
    );
  }
}

