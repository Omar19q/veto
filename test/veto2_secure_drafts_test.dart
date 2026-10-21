import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/secure_draft_store.dart';

void main() {
  test(
    'Recreated screen clear follows an in-flight save from the previous screen',
    () async {
      final values = <String, String>{};
      SecureDraftStore instance() => SecureDraftStore(
        'same-owner',
        read: (key) async => values[key],
        write: (key, value) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          values[key] = value;
        },
        remove: (key) async {
          values.remove(key);
        },
      );
      final previous = instance(), next = instance();
      await Future.wait([
        previous.save('booking', {'pickup': 'old'}),
        next.clear('booking'),
      ]);
      expect(await next.load('booking'), isNull);
    },
  );
  test(
    'Drafts isolate owners and features, expire and reject corrupt storage',
    () async {
      final values = <String, String>{};
      var now = DateTime(2026, 10, 19);
      SecureDraftStore store(String owner) => SecureDraftStore(
        owner,
        read: (key) async => values[key],
        write: (key, value) async {
          values[key] = value;
        },
        remove: (key) async {
          values.remove(key);
        },
        clock: () => now,
      );
      final a = store('a'), b = store('b');
      await a.save('booking', {
        'pickup': 'saved place',
      }, lifetime: const Duration(hours: 1));
      expect((await a.load('booking'))?['pickup'], 'saved place');
      expect(await b.load('booking'), isNull);
      expect(await a.load('captain'), isNull);
      now = now.add(const Duration(hours: 2));
      expect(await a.load('booking'), isNull);
      values[a.key('booking')] = 'corrupt';
      expect(await a.load('booking'), isNull);
    },
  );
  test('A clear cannot be overwritten by an older queued save', () async {
    final values = <String, String>{};
    final store = SecureDraftStore(
      'owner',
      read: (key) async => values[key],
      write: (key, value) async {
        values[key] = value;
      },
      remove: (key) async {
        values.remove(key);
      },
    );
    final save = store.save('cart', {'quantity': 2});
    final clear = store.clear('cart');
    await Future.wait([save, clear]);
    expect(await store.load('cart'), isNull);
    await expectLater(
      store.save('huge', {'data': 'x' * 40000}),
      throwsFormatException,
    );
  });
}
