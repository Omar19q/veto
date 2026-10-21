import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/trip_chat_inbox.dart';
import '../l10n/strings.dart';

class TripChatButton extends StatelessWidget {
  final String tripId;
  final String? label;
  const TripChatButton({
    super.key,
    required this.tripId,
    this.label,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: TripChatInbox.instance,
    builder: (context, _) => OutlinedButton.icon(
      onPressed: () => context.push('/trip-chat?tripId=$tripId'),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.chat_bubble_rounded),
          if (TripChatInbox.instance.hasUnread(tripId))
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
      label: Text(label ?? context.strings.chatTitle),
    ),
  );
}
