import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Existing news contracts; does not change OneSignal, moderation or audiences.
class KarizmaBackend {
  String? get accountId => SupabaseService.instance.currentUser?.id;
  Stream<String?> get accountChanges => SupabaseService
      .instance
      .client
      .auth
      .onAuthStateChange
      .map((e) => e.session?.user.id);
  ValueListenable<int> get customerOpen =>
      SupabaseService.instance.karizmaCustomerOpen;
  Future<List<Map<String, dynamic>>> posts(String audience) =>
      SupabaseService.instance.getKarizmaPosts(audience);
  Future<void> markSeen(String audience, DateTime latest) async =>
      SupabaseService.instance.markKarizmaSeenV26(audience, latest);
  Future<void> react(String id, String audience, int value) async =>
      SupabaseService.instance.reactKarizmaV26(id, audience, value);
  Future<String?> nickname() =>
      SupabaseService.instance.getMyKarizmaNicknameV33();
  Future<void> saveNickname(String text) async =>
      SupabaseService.instance.saveMyKarizmaNicknameV33(text);
  Future<List<Map<String, dynamic>>> comments(String post, String audience) =>
      SupabaseService.instance.getKarizmaCommentsV33(post, audience);
  Future<void> addComment(
    String post,
    String audience,
    String text,
    bool nickname,
  ) async {
    await SupabaseService.instance.client.rpc(
      'v34_add_karizma_comment',
      params: {
        'p_post_id': post,
        'p_body': text,
        'p_audience': audience,
        'p_use_nickname': nickname,
      },
    );
  }
}
