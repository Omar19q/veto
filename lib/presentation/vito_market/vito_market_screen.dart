import '../../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';

class VitoMarketScreen extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function()? loadStores;
  const VitoMarketScreen({super.key, this.loadStores});

  @override
  State<VitoMarketScreen> createState() => _VitoMarketScreenState();
}

class _VitoMarketScreenState extends State<VitoMarketScreen> {
  List<Map<String, dynamic>> _supermarkets = [];
  bool _isLoading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    try {
      final items =
          await (widget.loadStores ??
              SupabaseService.instance.getSupermarkets)();
      if (mounted) {
        setState(() {
          _supermarkets = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _failed = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF0D1220)
              : Theme.of(context).colorScheme.surface,
          title: Text(
            context.strings.marketStoresTitle,
            style: TextStyle(
              
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () => context.pop(),
          ),
          elevation: 0,
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppTheme.gold))
            : _failed
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.strings.marketStoresFailed,
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: _load,
                      child: Text(context.strings.retry),
                    ),
                  ],
                ),
              )
            : _supermarkets.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.store_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 64,
                    ),
                    SizedBox(height: 16),
                    Text(
                      context.strings.marketStoresEmpty,
                      style: TextStyle(
                        
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: EdgeInsets.all(16),
                itemCount: _supermarkets.length,
                separatorBuilder: (_, __) => SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final s = _supermarkets[i];
                  final isOpen = s['is_open'] as bool? ?? false;
                  final deliveryMin = s['delivery_estimate_minutes'] as int?;
                  return GestureDetector(
                    onTap: isOpen
                        ? () => context.push(
                            AppRoutes.vitoMarketProducts,
                            extra: {'supermarket': s},
                          )
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Color(0xFF13182A)
                            : Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Color(0xFF2A3355)
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cover
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Color(0xFF1A2035)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              image: s['cover_url'] != null
                                  ? DecorationImage(
                                      image: NetworkImage(
                                        s['cover_url'] as String,
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: Stack(
                              children: [
                                if (s['cover_url'] == null)
                                  Center(
                                    child: Icon(
                                      Icons.store_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      size: 48,
                                    ),
                                  ),
                                if (s['logo_url'] != null)
                                  Positioned(
                                    right: 12,
                                    bottom: -18,
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      padding: EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF13182A),
                                        shape: BoxShape.circle,
                                      ),
                                      child: ClipOval(
                                        child: Image.network(
                                          s['logo_url'].toString(),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.store_rounded,
                                            color: AppTheme.gold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s['name'] as String? ?? '',
                                        style: TextStyle(
                                          
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (deliveryMin != null &&
                                              deliveryMin > 0) ...[
                                            Icon(
                                              Icons.access_time_rounded,
                                              size: 14,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              context.strings
                                                  .marketStoresMinutes(
                                                    '$deliveryMin',
                                                  ),
                                              style: TextStyle(
                                                
                                                fontSize: 12,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                          ],
                                          if (s['address'] != null) ...[
                                            Icon(
                                              Icons.location_on_rounded,
                                              size: 14,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                            SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                s['address'] as String,
                                                style: TextStyle(
                                                  
                                                  fontSize: 12,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (isOpen
                                                ? Color(0xFF4CAF50)
                                                : Color(0xFFEF5350))
                                            .withAlpha(31),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isOpen
                                        ? context.strings.marketStoresOpen
                                        : context.strings.marketStoresClosed,
                                    style: TextStyle(
                                      
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isOpen
                                          ? Color(0xFF4CAF50)
                                          : Color(0xFFEF5350),
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
                },
              ),
      ),
    );
  }
}
