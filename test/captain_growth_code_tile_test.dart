import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/growth_service.dart';
import 'package:vetosanya/presentation/growth/captain_growth_code_tile.dart';
import 'package:vetosanya/l10n/app_localizations.dart';

Map<String,dynamic> profile(String code) => {'enabled':true,'code':code,
  'due':0,'paid':0,'promotional_available':0};
void main() {
  testWidgets('Capacity exhaustion shows a pending code rather than a fake badge', (tester) async {
    final service = GrowthService(rpc: (_, __) async => {'enabled':false,'reason':'captain_code_capacity_exhausted'});
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CaptainGrowthCodeTile(
      accountId: 'synthetic', service: service))));
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(l.captainCodePending), findsOneWidget);
    expect(find.text('1001'), findsNothing);
    expect(find.text('10000'), findsNothing);
  });
  testWidgets('Captain badge uses authenticated RPC and removes code on account change', (tester) async {
    final pending = Completer<dynamic>();
    var calls = 0;
    final service = GrowthService(rpc: (name, params) async {
      expect(name, 'growth_my_profile_v3'); expect(params['p_kind'], 'captain');
      calls++;
      if (calls == 1) return profile('1001');
      return await pending.future;
    });
    Widget app(String id) => MaterialApp(home: Scaffold(body: CaptainGrowthCodeTile(
      key: const ValueKey('tile'), accountId: id, service: service)));
    await tester.pumpWidget(app('synthetic-a')); await tester.pumpAndSettle();
    expect(find.text('1001'), findsOneWidget);
    await tester.pumpWidget(app('synthetic-b')); await tester.pump();
    expect(find.text('1001'), findsNothing);
    expect(calls, 2);
    await tester.runAsync(() async {
      pending.complete(profile('1002'));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.text('1002'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Unavailable server never displays invented badge code', (tester) async {
    final service = GrowthService(rpc: (_, __) async => throw StateError('offline'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CaptainGrowthCodeTile(
      accountId: 'synthetic', service: service))));
    await tester.pumpAndSettle();
    expect(find.text('1001'), findsNothing);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
}
