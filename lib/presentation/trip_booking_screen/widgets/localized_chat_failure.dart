import 'package:flutter/widgets.dart';
import '../../../l10n/strings.dart';

String localizedChatFailure(BuildContext context, Object error) {
  final l = context.strings, raw = error.toString();
  if (raw.contains('chat_rate_limit')) return l.chatRateLimited;
  if (raw.contains('chat_request_conflict')) return l.chatRequestConflict;
  if (raw.contains('invalid_message')) return l.chatInvalidMessage;
  if (raw.contains('not_trip_participant')) return l.chatParticipantOnly;
  if (raw.contains('chat_not_ready')) return l.chatNotReady;
  if (raw.contains('authentication_required') || raw.contains('not_authenticated')) {
    return l.chatSessionUnavailable;
  }
  return l.chatSendUnconfirmed;
}
