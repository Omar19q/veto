import 'package:flutter/material.dart';
import '../l10n/strings.dart';

/// Presentation shell only. The caller retains all booking and account logic.
class CustomerMapHome extends StatefulWidget {
  const CustomerMapHome({
    super.key,
    required this.map,
    required this.slivers,
    required this.city,
    required this.onCity,
    this.onPickup,
    required this.onLocate,
    required this.onAccount,
    required this.onNotifications,
    this.locating = false,
    this.unreadCount = 0,
  });
  final Widget map;
  final List<Widget> slivers;
  final String city;
  final VoidCallback onCity, onLocate, onAccount, onNotifications;
  final VoidCallback? onPickup;
  final bool locating;
  final int unreadCount;
  @override
  State<CustomerMapHome> createState() => _CustomerMapHomeState();
}

class _CustomerMapHomeState extends State<CustomerMapHome> {
  final _sheet = DraggableScrollableController();
  bool _expanded = false;
  double? _extent;
  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_sheet.isAttached) return;
    final expand = _sheet.size < .8;
    _sheet.animateTo(
      expand ? .94 : .34,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.strings, c = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, bounds) {
        final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
        final initial = bounds.maxHeight < 560 || largeText ? .70 : .34;
        return Stack(
          fit: StackFit.expand,
          children: [
            // The map occupies its own viewport: sheet content cannot hide the pin
            // or attribution, and gestures remain available above the sheet.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: bounds.maxHeight * (1 - (_extent ?? initial)) + 20,
              child: widget.map,
            ),
            PositionedDirectional(
              top: 8,
              start: 12,
              end: 12,
              child: SafeArea(
                bottom: false,
                child: Material(
                  elevation: 2,
                  color: c.surface,
                  borderRadius: BorderRadius.circular(22),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l.account478c486f,
                        onPressed: widget.onAccount,
                        icon: const Icon(Icons.menu_rounded),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: widget.onPickup ?? widget.onCity,
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'VETO SANYA',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                Text(
                                  widget.city,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l.refresh,
                        onPressed: widget.locating ? null : widget.onLocate,
                        icon: widget.locating
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded),
                      ),
                      IconButton(
                        tooltip: l.notifications,
                        onPressed: widget.onNotifications,
                        icon: Badge(
                          isLabelVisible: widget.unreadCount > 0,
                          child: const Icon(Icons.notifications_none_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (n) {
                final expanded = n.extent > .8;
                if (_extent != n.extent)
                  setState(() {
                    _expanded = expanded;
                    _extent = n.extent;
                  });
                return false;
              },
              child: DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: initial,
                minChildSize: .30,
                maxChildSize: .94,
                snap: true,
                snapSizes: const [.30, .34, .70, .94],
                builder: (context, scroll) => Material(
                  color: c.surface,
                  elevation: 8,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CustomScrollView(
                    controller: scroll,
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 30,
                          child: TextButton.icon(
                            onPressed: _toggle,
                            icon: Icon(
                              _expanded ? Icons.expand_more : Icons.expand_less,
                            ),
                            label: Text(
                              _expanded ? l.collapseBooking : l.expandBooking,
                            ),
                          ),
                        ),
                      ),
                      ...widget.slivers,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
