import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef DraftRead = Future<String?> Function(String key);
typedef DraftWrite = Future<void> Function(String key, String value);
typedef DraftDelete = Future<void> Function(String key);

/// Short-lived device drafts, encrypted by the platform, never financial truth.
class SecureDraftStore {
  SecureDraftStore(
    this.owner, {
    DraftRead? read,
    DraftWrite? write,
    DraftDelete? remove,
    DateTime Function()? clock,
  }) : _read = read ?? ((key) => _storage.read(key: key)),
       _write =
           write ?? ((key, value) => _storage.write(key: key, value: value)),
       _delete = remove ?? ((key) => _storage.delete(key: key)),
       _clock = clock ?? DateTime.now;
  static const _storage = FlutterSecureStorage();
  final String owner;
  final DraftRead _read;
  final DraftWrite _write;
  final DraftDelete _delete;
  final DateTime Function() _clock;
  // Screens may be recreated while the previous screen is still saving.
  // Serialize by account/feature across instances so an old save cannot win
  // against the next screen's confirmed-booking clear.
  static final Map<String, Future<void>> _queues = {};
  String key(String feature) =>
      'veto.draft.v1.${base64Url.encode(utf8.encode(owner))}.${base64Url.encode(utf8.encode(feature))}';
  Future<Map<String, dynamic>?> load(String feature) async {
    await (_queues[key(feature)] ?? Future<void>.value()).catchError(
      (Object _) {},
    );
    final text = await _read(key(feature));
    if (text == null) return null;
    try {
      final json = jsonDecode(text) as Map;
      if (json['version'] != 1 ||
          json['owner'] != owner ||
          json['feature'] != feature ||
          json['expires_at'] is! int ||
          DateTime.fromMillisecondsSinceEpoch(
            json['expires_at'] as int,
          ).isBefore(_clock()))
        return null;
      return Map<String, dynamic>.from(json['data'] as Map);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save(
    String feature,
    Map<String, dynamic> data, {
    Duration lifetime = const Duration(days: 7),
  }) {
    final encoded = jsonEncode({
      'version': 1,
      'owner': owner,
      'feature': feature,
      'expires_at': _clock().add(lifetime).millisecondsSinceEpoch,
      'data': data,
    });
    if (encoded.length > 32768)
      return Future.error(const FormatException('draft_too_large'));
    final operation = (_queues[key(feature)] ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) => _write(key(feature), encoded));
    _track(feature, operation);
    return operation;
  }

  Future<void> clear(String feature) {
    final operation = (_queues[key(feature)] ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) => _delete(key(feature)));
    _track(feature, operation);
    return operation;
  }

  void _track(String feature, Future<void> operation) {
    final storageKey = key(feature);
    _queues[storageKey] = operation;
    void release() {
      if (identical(_queues[storageKey], operation)) _queues.remove(storageKey);
    }

    operation.then(
      (_) => release(),
      onError: (Object _, StackTrace __) => release(),
    );
  }
}
