import '../../../l10n/strings.dart';
import 'package:flutter/material.dart';


/// Ready-to-send phrases; sender identity/permissions stay in the existing RPC.
class TripQuickReplies extends StatelessWidget {
  final bool isCaptain;
  final bool enabled;
  final ValueChanged<String> onSend;

  const TripQuickReplies({
    super.key,
    required this.isCaptain,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.strings;
    final replies = isCaptain ? [l.replyCaptainEnRoute, l.replyCaptainArrived,
      l.replyCaptainMeeting, l.replyCaptainLandmark, l.replyCaptainUpdate] :
      [l.replyCustomerWaiting, l.replyCustomerEta, l.replyCustomerGate,
       l.replyCustomerCall, l.replyCustomerReady];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Padding(
          padding: EdgeInsets.only(bottom: 5),
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, color: Theme.of(context).colorScheme.primary, size: 16),
              SizedBox(width: 4),
              Text(l.chatQuickReplies, style: TextStyle(
                 fontSize: 11, fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: replies.map((reply) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 7),
              child: ActionChip(
                onPressed: enabled ? () => onSend(reply) : null,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                side: BorderSide(color: Theme.of(context).colorScheme.primary.withAlpha(110)),
                label: Text(reply, style:  TextStyle(
                   color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 11, fontWeight: FontWeight.w600,
                )),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}
