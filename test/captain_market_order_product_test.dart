import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/services/captain_market_backend.dart';
import 'package:vetosanya/presentation/captain_dashboard_screen/captain_market_order_screen.dart';

class CaptainMarketStub extends CaptainMarketBackend {
  String uid = 'synthetic-a';
  final changes = StreamController<String?>.broadcast(sync: true);
  String status = 'on_the_way';
  bool missingCash = false;
  Completer<Map<String, dynamic>>? delayed;
  final transitions = <String>[];
  int cancellations = 0;
  @override
  String? get accountId => uid;
  @override
  Stream<String?> get accountChanges => changes.stream;
  @override
  List<RealtimeChannel> subscribe(String id, void Function() changed) => [];
  @override
  Future<Map<String, dynamic>> getContext(String id) async {
    if (delayed != null) return delayed!.future;
    return value();
  }

  Map<String, dynamic> value() => {
    'order': {
      'order_status': status,
      'store_order_number': 3,
      'cash_amount': missingCash ? null : '55.00',
      'store_cash_due': 50,
      'wallet_amount': 0,
      'delivery_fee': '5.00',
      'captain_earning': '3.00',
      'captain_delivery_share_percent': 60,
    },
    'store': {'name': 'اسم المتجر الأصلي'},
    'customer': {},
    'items': [],
  };
  @override
  Future<void> transition(String id, String status) async {
    transitions.add(status);
  }

  @override
  Future<void> cancel(String id) async {
    cancellations++;
  }

  void switchTo(String id) {
    uid = id;
    changes.add(id);
  }
}

Widget app(CaptainMarketStub backend, String language, bool dark) =>
    MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: CaptainMarketOrderScreen(
        orderId: 'synthetic-order',
        backend: backend,
      ),
    );
void main() {
  for (final language in ['ar', 'en']) {
    for (final dark in [true, false]) {
      testWidgets(
        'Captain market $language dark=$dark server cash/net/commission at320',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final backend = CaptainMarketStub();
          addTearDown(backend.changes.close);
          final l = lookupAppLocalizations(Locale(language));
          await tester.pumpWidget(app(backend, language, dark));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text(l.moneyValue('55.00')),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text(l.moneyValue('55.00')), findsOneWidget);
          expect(find.text(l.moneyValue('3.00')), findsOneWidget);
          expect(find.text(l.moneyValue('2.00')), findsOneWidget);
          expect(backend.transitions, isEmpty);
          expect(backend.cancellations, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets('Incomplete cash invoice does not claim paid or allow delivery', (
    tester,
  ) async {
    final backend = CaptainMarketStub()..missingCash = true;
    addTearDown(backend.changes.close);
    await tester.pumpWidget(app(backend, 'en', true));
    await tester.pumpAndSettle();
    final action = find.text('Review invoice and confirm delivery');
    await tester.scrollUntilVisible(
      action,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The invoice is incomplete. Refresh the order before confirming delivery.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('The order is paid. Do not collect money from the customer.'),
      findsNothing,
    );
    expect(backend.transitions, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Account change closes delivery confirmation and prevents transition',
    (tester) async {
      final backend = CaptainMarketStub();
      addTearDown(backend.changes.close);
      await tester.pumpWidget(app(backend, 'en', false));
      await tester.pumpAndSettle();
      final action = find.text('Review invoice and confirm delivery');
      await tester.scrollUntilVisible(
        action,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(action);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AlertDialog), findsOneWidget);
      backend.switchTo('synthetic-b');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(backend.transitions, isEmpty);
      expect(find.text('اسم المتجر الأصلي'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Old captain context response cannot reveal prior-account job', (
    tester,
  ) async {
    final backend = CaptainMarketStub()
      ..delayed = Completer<Map<String, dynamic>>();
    addTearDown(backend.changes.close);
    await tester.pumpWidget(app(backend, 'en', true));
    await tester.pump();
    backend.switchTo('synthetic-b');
    backend.delayed!.complete(backend.value());
    await tester.pumpAndSettle();
    expect(find.text('اسم المتجر الأصلي'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
