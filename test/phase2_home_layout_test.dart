import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/home_screen/widgets/product_home_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('small-width home has four tappable services without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate],
      home: Scaffold(body: SingleChildScrollView(child: ProductHomePanel(
        customerId: null, pickupCaption: 'عنوان الانطلاق',
        onStart: (_, service) => selected = service, onMarket: () => selected = 'market',
      ))),
    ));
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(l.car), findsOneWidget);
    expect(find.text(l.motorcycle), findsOneWidget);
    expect(find.text(l.delivery), findsOneWidget);
    expect(find.text(l.market), findsOneWidget);
    await tester.tap(find.text(l.car));
    expect(selected, 'car');
    expect(tester.takeException(), isNull);
  });
}
