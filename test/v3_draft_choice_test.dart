import 'package:flutter_test/flutter_test.dart';
import '../lib/services/ride_categories.dart';

void main() {
  test(
    'Ladies choice restores independently of current catalogue availability',
    () {
      expect(restoredRideCategory('veto_ladies'), 'veto_ladies');
      expect(restoredRideCategory('veto_premium'), 'veto_premium');
    },
  );
  test('local draft accepts only recognized ride categories', () {
    for (final value in [null, 1, 'car', 'veto_market', 'unknown']) {
      expect(restoredRideCategory(value), isNull);
    }
  });
  test('preferences restore safely without financial or arbitrary fields', () {
    expect(
      restoredTripPromises([
        'quiet',
        'ac',
        'child',
        'baggage',
        'no_music',
        'child_seat',
        'quiet',
        'wallet',
        25,
      ]),
      {'quiet', 'ac', 'child', 'baggage', 'no_music', 'child_seat'},
    );
    expect(restoredTripPromises({'quiet': true}), isEmpty);
  });
}
