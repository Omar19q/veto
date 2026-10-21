import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class CaptainApplicationV16 {
  static const documentLabels = <String, String>{
    'portrait': 'الصورة الشخصية',
    'id_front': 'البطاقة • أمام',
    'id_back': 'البطاقة • خلف',
    'license_front': 'رخصة القيادة • أمام',
    'license_back': 'رخصة القيادة • خلف',
    'vehicle_front': 'رخصة المركبة • أمام',
    'vehicle_back': 'رخصة المركبة • خلف',
    'vehicle_photo': 'صورة المركبة من الخارج',
  };
  /// Decode date of birth from a valid Egyptian national ID (without sending
  /// the ID to a third-party date service). Invalid dates return null.
  static DateTime? birthDateFromNationalId(String id) {
    if (!RegExp(r'^[23][0-9]{13}$').hasMatch(id)) return null;
    final base = id.startsWith('3') ? 2000 : 1900;
    final year = base + int.parse(id.substring(1, 3));
    final month = int.parse(id.substring(3, 5));
    final day = int.parse(id.substring(5, 7));
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  static bool isAdult(DateTime birth, DateTime today) {
    final eighteenthBirthday = DateTime(birth.year + 18, birth.month, birth.day);
    return !eighteenthBirthday.isAfter(DateTime(today.year, today.month, today.day));
  }

  static List<String> missingDocuments(Iterable<String> presentKeys) {
    final present = presentKeys.toSet();
    return documentLabels.keys.where((k) => !present.contains(k)).toList();
  }

  static const statuses = {
    'pending': 'قيد المراجعة',
    'needs_info': 'مطلوب استكمال',
    'approved': 'مقبول',
    'rejected': 'مرفوض',
  };
  CaptainApplicationV16({SupabaseClient? client})
      : client = client ?? SupabaseService.instance.client;
  final SupabaseClient client;
  static String? imageType(Uint8List b) {
    if (b.length > 8388608 || b.length < 12) return null;
    if (b[0] == 255 && b[1] == 216 && b[2] == 255) return 'image/jpeg';
    if (b[0] == 137 &&
        b[1] == 80 &&
        b[2] == 78 &&
        b[3] == 71 &&
        b[4] == 13 &&
        b[5] == 10 &&
        b[6] == 26 &&
        b[7] == 10) {
      return 'image/png';
    }
    if (String.fromCharCodes(b.take(4)) == 'RIFF' &&
        String.fromCharCodes(b.skip(8).take(4)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  Future<void> login(String phone, String code) async {
    final response = await client.functions.invoke(
      'captain-application-login',
      body: {'phone': phone, 'code': code},
    );
    final data = response.data as Map;
    if (data['success'] != true) {
      throw StateError(data['error']?.toString() ?? 'verification_invalid');
    }
    await client.auth.verifyOTP(
      email: data['email'] as String,
      token: data['token'] as String,
      type: OtpType.magiclink,
    );
    await SupabaseService.instance.activateSessionV25();
  }

  Future<Map<String, dynamic>?> identity() async {
    final id = client.auth.currentUser?.id;
    if (id == null) return null;
    return client
        .from('v16_captain_identities')
        .select()
        .eq('user_id', id)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> mine() async {
    final id = client.auth.currentUser?.id;
    if (id == null) return null;
    return client
        .from('v16_captain_applications')
        .select()
        .eq('user_id', id)
        .maybeSingle();
  }

  Future<String> upload(String kind, Uint8List bytes) async {
    final mime = imageType(bytes);
    if (mime == null) throw StateError('invalid_image');
    final path =
        '${client.auth.currentUser!.id}/$kind/${DateTime.now().microsecondsSinceEpoch}.${mime.split('/').last}';
    await client.storage
        .from('v16-captain-documents')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );
    return path;
  }

  Future<String> preview(String path) =>
      client.storage.from('v16-captain-documents').createSignedUrl(path, 60);
  Future<void> submit(Map<String, dynamic> data) async {
    await client.rpc(
      'v16_submit_captain_application',
      params: {'p_data': data},
    );
  }

  // V19: receiving an application from an already logged-in customer does
  // not verify the entered phone or grant any captain privileges.
  Future<Map<String, dynamic>?> intakeMine() async {
    final id = client.auth.currentUser?.id;
    if (id == null) return null;
    return client
        .from('v19_captain_intake')
        .select()
        .eq('applicant_user_id', id)
        .maybeSingle();
  }

  Future<String> uploadIntake(String kind, Uint8List bytes) async {
    final mime = imageType(bytes);
    if (mime == null || !documentLabels.containsKey(kind)) {
      throw StateError('invalid_image');
    }
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('customer_session_required');
    final path =
        '$userId/$kind/${DateTime.now().microsecondsSinceEpoch}.${mime.split('/').last}';
    await client.storage.from('v19-captain-intake').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime, upsert: false),
    );
    return path;
  }

  Future<void> submitIntake(Map<String, dynamic> data) async {
    if (client.auth.currentUser == null) {
      throw StateError('customer_session_required');
    }
    await client.rpc('v19_submit_captain_intake', params: {'p_data': data});
  }

  Future<List<Map<String, dynamic>>> listIntakes({int page = 0, int pageSize = 50}) async =>
      List<Map<String, dynamic>>.from(
        await client.from('v19_captain_intake').select()
            .order('created_at', ascending: false)
            .range(page * pageSize,(page + 1) * pageSize - 1),
      );

  Future<String> previewIntake(String path) =>
      client.storage.from('v19-captain-intake').createSignedUrl(path, 60);

  Future<void> reviewIntake(Map<String, dynamic> a, String action, String reason) async {
    await client.rpc('v19_review_captain_intake', params: {
      'p_id': a['id'],
      'p_action': action,
      'p_reason': reason,
      'p_revision': a['revision'],
    });
  }

  Future<List<Map<String, dynamic>>> list({int page = 0, int pageSize = 50}) async =>
      List<Map<String, dynamic>>.from(
        await client
            .from('v16_captain_applications')
            .select()
            .order('updated_at', ascending: false)
            .range(page * pageSize,(page + 1) * pageSize - 1),
      );
  Future<void> review(
    Map<String, dynamic> a,
    String action,
    String reason,
  ) async {
    await client.rpc(
      'v16_review_captain_application',
      params: {
        'p_id': a['id'],
        'p_action': action,
        'p_reason': reason,
        'p_user_id': a['user_id'],
        'p_revision': a['revision'],
      },
    );
  }
}
