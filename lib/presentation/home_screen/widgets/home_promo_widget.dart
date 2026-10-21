import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../l10n/strings.dart';
import '../../../routes/app_routes.dart';
import '../../../services/supabase_service.dart';

/// Approved, ordered admin content. Manual paging only: no distracting timer.
class HomePromoWidget extends StatefulWidget {
  const HomePromoWidget({super.key, this.onBookTap, this.loadBanners});
  final VoidCallback? onBookTap;
  final Future<List<Map<String, dynamic>>> Function()? loadBanners;
  @override
  State<HomePromoWidget> createState() => _HomePromoWidgetState();
}

class _HomePromoWidgetState extends State<HomePromoWidget> {
  final _pages = PageController();
  List<Map<String, dynamic>> _rows = [];
  dynamic _channel;
  int _page = 0, _revision = 0;
  @override
  void initState() {
    super.initState();
    _load();
    if (widget.loadBanners == null)
      _channel = SupabaseService.instance.subscribeToBanners((_) => _load());
  }

  @override
  void dispose() {
    _revision++;
    _pages.dispose();
    if (_channel != null)
      unawaited(SupabaseService.instance.client.removeChannel(_channel));
    super.dispose();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    try {
      final rows =
          await (widget.loadBanners?.call() ??
                  SupabaseService.instance.getActiveBanners())
              .timeout(const Duration(seconds: 8));
      if (!mounted || revision != _revision) return;
      setState(() {
        _rows = rows
            .where(
              (r) =>
                  r['is_active'] != false &&
                  '${r['title'] ?? ''}'.trim().isNotEmpty,
            )
            .toList();
        _page = 0;
      });
      if (_pages.hasClients) _pages.jumpToPage(0);
    } catch (_) {
      /* Promotional failure must never block or compete with booking. */
    }
  }

  static String? imageUrl(dynamic value) {
    final uri = Uri.tryParse(value?.toString() ?? '');
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri.toString()
        : null;
  }

  void _move(int delta) {
    final page = (_page + delta).clamp(0, _rows.length - 1);
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(
        page,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty) return const SizedBox.shrink();
    final l = context.strings, c = Theme.of(context).colorScheme;
    final height = MediaQuery.textScalerOf(context).scale(14) > 20
        ? 142.0
        : 92.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _pages,
            itemCount: _rows.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) {
              final row = _rows[index],
                  action = '${_rows[index]['action_type'] ?? 'none'}';
              final image = imageUrl(row['image_url']);
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${row['title']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if ('${row['subtitle'] ?? ''}'.isNotEmpty)
                              Text(
                                '${row['subtitle']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (const {
                              'trip',
                              'booking',
                              'market',
                            }.contains(action))
                              TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 26),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  if (action == 'market') {
                                    context.push(AppRoutes.vitoMarket);
                                  } else if (widget.onBookTap != null) {
                                    widget.onBookTap!();
                                  } else {
                                    context.push(AppRoutes.tripBookingScreen);
                                  }
                                },
                                child: Text(
                                  action == 'market' ? l.openMarket : l.bookNow,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (image != null) ...[
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: image,
                            width: 66,
                            height: 65,
                            fit: BoxFit.cover,
                            memCacheWidth: 240,
                            placeholder: (_, __) => Icon(
                              Icons.local_offer_outlined,
                              color: c.primary,
                            ),
                            errorWidget: (_, __, ___) => Icon(
                              Icons.local_offer_outlined,
                              color: c.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_rows.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: l.bannerPrevious,
                onPressed: _page == 0 ? null : () => _move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${l.bannerPosition} ${_page + 1} / ${_rows.length}'),
              IconButton(
                tooltip: l.bannerNext,
                onPressed: _page == _rows.length - 1 ? null : () => _move(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
  }
}
