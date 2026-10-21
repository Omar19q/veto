import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'app_sound_service.dart';
import 'market_tracking_backend.dart';

class CaptainMarketBackend extends MarketTrackingBackend {
  @override
  List<RealtimeChannel> subscribe(String id, void Function() changed) => [
    SupabaseService.instance.client
        .channel('captain_market_$id')
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
  ];
  Future<void> transition(String id, String status) => SupabaseService.instance
      .transitionMarketOrder(orderId: id, status: status);
  Future<void> cancel(String id) =>
      SupabaseService.instance.cancelCaptainMarketOrder(orderId: id);
}
