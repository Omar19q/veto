import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetosanya/services/pending_address_draft.dart';

void main() {
  const request = {'p_request_key':'00000000-0000-4000-8000-000000000001',
    'p_city':'Synthetic inactive city','p_kind':'building','p_lat':30.0,'p_lng':31.0,
    'p_number':'9','p_area':'Synthetic area','p_address':'Synthetic description'};
  setUp(() { SharedPreferences.setMockInitialValues({}); });
  test('Persisted retry receipt reloads the original payload and key without leaking to another account', () async {
    await PendingAddressDraft.save('synthetic-a', request);
    expect(await PendingAddressDraft.load('synthetic-a'), request);
    expect(await PendingAddressDraft.load('synthetic-b'), isNull);
    expect(await PendingAddressDraft.load('synthetic-a', correction:'other'), isNull);
    await PendingAddressDraft.clear('synthetic-a');
    expect(await PendingAddressDraft.load('synthetic-a'), isNull);
  });
  test('Correction receipts are separate and clearing one cannot erase another', () async {
    await PendingAddressDraft.save('synthetic-a', request, correction:'first');
    await PendingAddressDraft.save('synthetic-a', {...request,'p_number':'10'}, correction:'second');
    await PendingAddressDraft.clear('synthetic-a', correction:'first');
    expect((await PendingAddressDraft.load('synthetic-a', correction:'second'))?['p_number'], '10');
  });
  test('Corrupt storage and empty accounts fail explicitly instead of issuing a new key', () async {
    SharedPreferences.setMockInitialValues({'product.address.pending.a.new':'{"version":1,"payload":{}}'});
    await expectLater(PendingAddressDraft.load('a'), throwsStateError);
    await expectLater(PendingAddressDraft.load(''), throwsStateError);
  });
  test('Auth tokens and phone fields cannot enter the retry receipt', () async {
    await expectLater(PendingAddressDraft.save('synthetic', {...request,'phone':'synthetic'}), throwsStateError);
    await expectLater(PendingAddressDraft.save('synthetic', {...request,'access_token':'synthetic'}), throwsStateError);
    expect(await PendingAddressDraft.load('synthetic'), isNull);
  });
}
