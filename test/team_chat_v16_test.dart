import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/team_chat_service_v16.dart';

void main() {
  test('Retry preserves UUID and immutable message payload', () {
    final pending = TeamPendingMessageV16('اختبار إعادة المحاولة');
    final key = pending.key;
    pending.sending = true;
    pending.sending = false;
    pending.failed = true;
    pending.sending = true;
    expect(pending.key, key);
    expect(pending.body, 'اختبار إعادة المحاولة');
    expect(
      key,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });
  test('Distinct message attempts have distinct idempotency keys', () {
    final keys = List.generate(1000, (_) => TeamChatServiceV16.newClientKey());
    expect(keys.toSet(), hasLength(1000));
  });
}
