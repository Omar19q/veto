import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/staff_access_v16.dart';

void main() {
  test('inactive identities lose permissions even with cached grants', () {
    const access = StaffAccessV16(
      active: false,
      permissions: {'finance.manage'},
    );
    expect(access.can('finance.manage'), false);
  });
  test('read and execute are independent', () {
    const access = StaffAccessV16(active: true, permissions: {'captains.view'});
    expect(access.can('captains.view'), true);
    expect(access.can('captains.manage'), false);
    expect(access.can('finance.view'), false);
  });
  test('role presets never grant staff management or owner status', () {
    for (final role in StaffAccessV16.roles) {
      expect(StaffAccessV16.preset(role).contains('staff.manage'), false);
    }
    expect(
      StaffAccessV16.preset('Read-only').every((p) => p.endsWith('.view')),
      true,
    );
    expect(StaffAccessV16.preset('Custom'), isEmpty);
  });
}
