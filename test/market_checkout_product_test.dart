import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/services/market_checkout_backend.dart';
import 'package:vetosanya/presentation/vito_market/vito_market_checkout_screen.dart';

class CheckoutStub extends MarketCheckoutBackend {
  String user = 'synthetic-a';
  final changes = StreamController<String?>.broadcast(sync: true);
  Completer<double>? oldFee;
  Completer<Map<String, dynamic>>? firstReceipt;
  final requests = <Map<String, dynamic>>[];
  @override
  String? get accountId => user;
  @override
  Stream<String?> get accountChanges => changes.stream;
  @override
  Future<Map<String, dynamic>?> getCustomerByUserId(String id) async => {
    'id': id,
    'wallet_balance': 123.0,
  };
  @override
  Future<List<Map<String, dynamic>>> getCustomerAddresses(String id) async => [
    {
      'id': 'address-$id',
      'label': 'Home $id',
      'display_address': 'Saved $id',
      'area_letter': id == 'synthetic-a' ? 'أ' : 'ب',
      'latitude': 29.99,
      'longitude': 31.1,
      'is_default': true,
    },
  ];
  @override
  Future<double> getVitoMarketDeliveryFee(String? area) async =>
      area == 'أ' && oldFee != null
      ? await oldFee!.future
      : area == 'ب'
      ? 7
      : 5;
  @override
  Future<Map<String, dynamic>> createMarketOrderAtomic({
    required String customerId,
    required String supermarketId,
    required String deliveryAddress,
    String? areaLetter,
    double? latitude,
    double? longitude,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    String? promoCode,
    String? idempotencyKey,
  }) async {
    requests.add({
      'customer': customerId,
      'address': deliveryAddress,
      'key': idempotencyKey,
      'items': items,
      'payment': paymentMethod,
    });
    if (requests.length == 1 && firstReceipt != null)
      return await firstReceipt!.future;
    throw StateError('synthetic_uncertain_response');
  }

  void switchTo(String id) {
    user = id;
    changes.add(id);
  }
}

Widget app(CheckoutStub backend, {String language = 'en', bool dark = false}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: VitoMarketCheckoutScreen(
        backend: backend,
        supermarket: const {'id': 'synthetic-store', 'name': 'Synthetic store'},
        cart: const {
          'synthetic-product': {
            'product': {
              'id': 'synthetic-product',
              'name': 'Synthetic groceries',
              'price': 100,
            },
            'quantity': 1,
          },
        },
      ),
    );
void main() {
  for (final language in ['ar', 'en'])
    for (final dark in [true, false]) {
      testWidgets(
        'Market checkout $language dark=$dark uses current saved address at 320px',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final backend = CheckoutStub();
          addTearDown(backend.changes.close);
          await tester.pumpWidget(app(backend, language: language, dark: dark));
          await tester.pumpAndSettle();
          expect(find.text('Saved synthetic-a'), findsOneWidget);
          final l = lookupAppLocalizations(Locale(language));
          expect(find.text(l.moneyValue('105.00')), findsOneWidget);
          if (language == 'en') expect(find.text('تأكيد الطلب'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  testWidgets(
    'Delayed delivery fee for previous account cannot replace new-account quote',
    (tester) async {
      final backend = CheckoutStub()..oldFee = Completer<double>();
      addTearDown(backend.changes.close);
      await tester.pumpWidget(app(backend));
      await tester.pump();
      await tester.pump();
      backend.switchTo('synthetic-b');
      await tester.pumpAndSettle();
      expect(find.text('Saved synthetic-a'), findsNothing);
      expect(find.text('Saved synthetic-b'), findsOneWidget);
      backend.oldFee!.complete(99);
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l.moneyValue('107.00')), findsOneWidget);
      expect(find.text(l.moneyValue('199.00')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Same-account retry retains key; old-account acknowledgement cannot navigate new account',
    (tester) async {
      final backend = CheckoutStub()
        ..firstReceipt = Completer<Map<String, dynamic>>();
      addTearDown(backend.changes.close);
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(ElevatedButton, 'Confirm order');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pump();
      expect(backend.requests.length, 1);
      final oldKey = backend.requests.single['key'];
      backend.switchTo('synthetic-b');
      await tester.pumpAndSettle();
      backend.firstReceipt!.complete({'order_id': 'previous-account-receipt'});
      await tester.pumpAndSettle();
      expect(find.text('Saved synthetic-b'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(backend.requests.length, 2);
      final newKey = backend.requests.last['key'];
      expect(newKey, isNot(oldKey));
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(backend.requests.last['key'], newKey);
      expect(backend.requests.last['customer'], 'synthetic-b');
      expect(backend.requests.last['address'], 'Saved synthetic-b');
      expect(backend.requests.last['items'], [
        {'product_id': 'synthetic-product', 'quantity': 1},
      ]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Switching account closes the previous saved-address picker', (
    tester,
  ) async {
    final backend = CheckoutStub();
    addTearDown(backend.changes.close);
    await tester.pumpWidget(app(backend));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(find.text('Home synthetic-a'), findsWidgets);
    backend.switchTo('synthetic-b');
    await tester.pumpAndSettle();
    expect(find.text('Home synthetic-a'), findsNothing);
    expect(find.text('Saved synthetic-a'), findsNothing);
    expect(find.text('Saved synthetic-b'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Account change safely dismisses address editor during route transition', (tester) async {
    final backend = CheckoutStub();
    addTearDown(backend.changes.close);
    await tester.pumpWidget(app(backend));
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.marketCheckout8d30f720));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), 'Synthetic label');
    backend.switchTo('synthetic-b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Saved synthetic-b'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
