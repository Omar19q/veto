import 'package:flutter_test/flutter_test.dart';
import '../lib/presentation/captain_dashboard_screen/captain_ban_screen.dart';

void main() {
  test('expired ban countdown never displays a negative time', () {
    expect(formatBanCountdown(const Duration(seconds: -2)), '00:00:00');
  });
  test('ban countdown shows full duration rather than wrapping at midnight', () {
    expect(formatBanCountdown(const Duration(days: 1, minutes: 3, seconds: 2)), '24:03:02');
  });
  test('ban countdown pads minutes and seconds independently', () {
    expect(formatBanCountdown(const Duration(minutes: 15)), '00:15:00');
  });
}
