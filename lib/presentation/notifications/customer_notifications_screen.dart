import 'dart:async';
import '../../l10n/strings.dart';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class CustomerNotificationsScreen extends StatefulWidget {
  const CustomerNotificationsScreen({super.key});
  @override
  State<CustomerNotificationsScreen> createState() =>
      _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState
    extends State<CustomerNotificationsScreen> {
  bool _loading = true;
  bool _error = false;
  int _loadRevision = 0;
  StreamSubscription? _authSubscription;
  String? _accountId;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _accountId = SupabaseService.instance.currentUser?.id;
    _authSubscription = SupabaseService.instance.client.auth.onAuthStateChange
        .listen((_) {
          final next = SupabaseService.instance.currentUser?.id;
          if (!mounted || next == _accountId) return;
          _accountId = next;
          unawaited(_load());
        });
    unawaited(_load());
  }

  @override
  void dispose() {
    _loadRevision++;
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final revision = ++_loadRevision;
    final user = SupabaseService.instance.currentUser;
    if (mounted)
      setState(() {
        _loading = true;
        _items = [];
        _error = false;
      });
    try {
      if (user == null) {
        throw StateError('authentication_required');
      }
      final rows = await SupabaseService.instance.getNotifications(user.id);
      if (mounted &&
          revision == _loadRevision &&
          SupabaseService.instance.currentUser?.id == user.id) {
        setState(() {
          _items = rows;
          _error = false;
        });
      }
    } catch (e) {
      if (mounted && revision == _loadRevision) setState(() => _error = true);
    } finally {
      if (mounted && revision == _loadRevision)
        setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    final accountId = SupabaseService.instance.currentUser?.id;
    if (accountId == null || !_items.contains(item) || item['is_read'] == true)
      return;
    try {
      await SupabaseService.instance.markNotificationRead(
        item['id'].toString(),
      );
      if (mounted &&
          SupabaseService.instance.currentUser?.id == accountId &&
          _items.contains(item)) {
        setState(() => item['is_read'] = true);
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.notificationReadFailed)),
        );
    }
  }

  Future<void> _markAllRead() async {
    final uid = SupabaseService.instance.currentUser?.id;
    if (uid == null) return;
    try {
      await SupabaseService.instance.markAllNotificationsRead(uid);
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.notificationUpdateFailed)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            context.strings.notificationTitle,
            style: TextStyle(
              
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            if (_items.any((n) => n['is_read'] != true))
              TextButton(
                onPressed: _markAllRead,
                child: Text(
                  context.strings.notificationReadAll,
                  style: TextStyle( color: AppTheme.gold),
                ),
              ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.gold),
              )
            : _error
            ? Center(
                child: TextButton(
                  onPressed: _load,
                  child: Text(
                    context.strings.notificationLoadFailed,
                    style: const TextStyle(
                      
                      color: AppTheme.gold,
                    ),
                  ),
                ),
              )
            : _items.isEmpty
            ? Center(
                child: Text(
                  context.strings.notificationEmpty,
                  style: TextStyle(
                    
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final n = _items[index];
                    return InkWell(
                      onTap: () => _markRead(n),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: n['is_read'] == true
                              ? Theme.of(context).colorScheme.surface
                              : AppTheme.gold.withAlpha(18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: n['is_read'] == true
                                ? Theme.of(context).dividerColor
                                : AppTheme.gold.withAlpha(70),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_rounded,
                              color: n['is_read'] == true
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant
                                  : AppTheme.gold,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n['title']?.toString() ?? '',
                                    style: TextStyle(
                                      
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n['body']?.toString() ?? '',
                                    style: TextStyle(
                                      
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
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
      ),
    );
  }
}
