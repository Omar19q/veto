import 'dart:async';
import 'package:flutter/widgets.dart';
import 'supabase_service.dart';

/// Shared lazy-loading mechanics; existing list widgets keep their appearance.
class AdminDirectoryPagerV15 extends ChangeNotifier {
  final String kind;
  final scroll = ScrollController();
  List<Map<String, dynamic>> rows = [];
  bool loading = true, _fetching = false, _hasMore = true, _disposed = false;
  int _revision = 0;
  int _nextOffset = 0;
  String _query = '';
  Object? error;
  Timer? _search;
  AdminDirectoryPagerV15(this.kind) {
    scroll.addListener(() {
      if (scroll.hasClients && scroll.position.extentAfter < 300)
        unawaited(more());
    });
  }
  void search(String value) {
    _query = value;
    _search?.cancel();
    _search = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(refresh()),
    );
  }

  Future<void> refresh() async {
    _revision++;
    _hasMore = true;
    loading = true;
    rows = [];
    _nextOffset = 0;
    await more();
  }

  Future<void> more() async {
    if (_disposed || !_hasMore) return;
    if (_fetching) return;
    final revision = _revision;
    _fetching = true;
    try {
      final raw = await SupabaseService.instance.client
          .rpc(
            'admin_directory_page_scale_v15',
            params: {
              'p_kind': kind,
              'p_offset': _nextOffset,
              'p_query': _query,
              'p_limit': 100,
            },
          )
          .timeout(const Duration(seconds: 15));
      if (_disposed || revision != _revision) return;
      final page = List<Map<String, dynamic>>.from(raw as List);
      _nextOffset += page.length;
      final ids = rows.map((r) => r['id']).toSet();
      rows.addAll(page.where((r) => !ids.contains(r['id'])));
      _hasMore = page.length == 100;
      error = null;
    } catch (e) {
      if (revision == _revision) error = e;
    } finally {
      _fetching = false;
      if (!_disposed) {
        if (revision != _revision) {
          unawaited(more());
        } else {
          loading = false;
          notifyListeners();
        }
      }
    }
  }

  Future<void> resync() async {
    if (_disposed || _fetching || rows.isEmpty) return;
    _fetching = true;
    final revision = _revision;
    try {
      final raw = await SupabaseService.instance.client
          .rpc(
            'admin_directory_page_scale_v15',
            params: {
              'p_kind': kind,
              'p_offset': 0,
              'p_query': _query,
              'p_limit': 100,
            },
          )
          .timeout(const Duration(seconds: 15));
      if (_disposed || revision != _revision) return;
      final page = List<Map<String, dynamic>>.from(raw as List);
      final latest = {for (final r in page) r['id']: r};
      rows = [for (final r in rows) latest.remove(r['id']) ?? r];
      rows.insertAll(0, latest.values);
      notifyListeners();
    } catch (_) {
      /* Retain the visible rows. */
    } finally {
      _fetching = false;
      if (!_disposed && revision != _revision) unawaited(more());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _search?.cancel();
    scroll.dispose();
    super.dispose();
  }
}
