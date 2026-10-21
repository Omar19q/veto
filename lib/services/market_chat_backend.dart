import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class MarketChatBackend {
  String? get accountId => SupabaseService.instance.currentUser?.id;
  Stream<String?> get accountChanges => SupabaseService
      .instance
      .client
      .auth
      .onAuthStateChange
      .map((e) => e.session?.user.id);
  Future<List<Map<String, dynamic>>> getMessages(String id) =>
      SupabaseService.instance.getMarketMessages(id);
  Future<void> markRead(String id) =>
      SupabaseService.instance.markMarketChatNotificationsRead(id);
  Future<void> send(String id, String message) =>
      SupabaseService.instance.sendMarketMessage(id, message);
  RealtimeChannel? subscribe(String id, Future<void> Function() changed) =>
      SupabaseService.instance.subscribeToMarketMessages(id, changed);
}
