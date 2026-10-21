import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'app_sound_service.dart';

class MarketTrackingBackend {
  String? get accountId => SupabaseService.instance.currentUser?.id;
  Stream<String?> get accountChanges => SupabaseService
      .instance
      .client
      .auth
      .onAuthStateChange
      .map((e) => e.session?.user.id);
  Future<Map<String, dynamic>> getContext(String id) =>
      SupabaseService.instance.getMarketOrderContext(id);
  List<RealtimeChannel> subscribe(String id, void Function() changed) => [
    SupabaseService.instance.client
        .channel('market_tracking_$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'market_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: id,
          ),
          callback: (_) async {
            await AppSoundService.instance.playNotification();
            changed();
          },
        )
        .subscribe(),
    SupabaseService.instance.subscribeToMarketMessages(
      id,
      () => AppSoundService.instance.playChat(),
    ),
  ];
}
