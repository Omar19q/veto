import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/account_scoped_read_pool.dart';

void main() {
  test('Simultaneous address reads share a request but settled data is not cached', () async {
    final pool = AccountScopedReadPool<String>();
    final pending = Completer<String>(); var calls=0;
    Future<String> read() => pool.read(key:'addresses',owner:'one',currentOwner:()=> 'one',
      load:(){calls++;return calls==1?pending.future:Future.value('fresh');});
    final a=read(),b=read(); expect(calls,1);
    pending.complete('first');expect(await a,'first');expect(await b,'first');
    expect(await read(),'fresh');expect(calls,2);
  });
  test('Account change rejects a late response and isolates the new read', () async {
    final pool=AccountScopedReadPool<String>();String owner='old';
    final pending=Completer<String>();
    final old=pool.read(key:'addresses',owner:'old',currentOwner:()=>owner,load:()=>pending.future);
    final rejection=expectLater(old,throwsStateError);
    owner='new';
    expect(await pool.read(key:'addresses',owner:'new',currentOwner:()=>owner,load:()async=>'new-only'),'new-only');
    pending.complete('old-private');await rejection;
  });
  test('A failure is evicted and a deliberate retry can fetch again', () async {
    final pool=AccountScopedReadPool<String>();var calls=0;
    Future<String> read()=>pool.read(key:'addresses',owner:'one',currentOwner:()=> 'one',load:(){calls++;if(calls==1)throw StateError('offline');return Future.value('recovered');});
    await expectLater(read(),throwsStateError);
    expect(await read(),'recovered');expect(calls,2);
  });
}
