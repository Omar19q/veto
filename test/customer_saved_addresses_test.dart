import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/addresses/customer_saved_addresses.dart';

Widget _wrap(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    themeMode: mode,
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    home: child,
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:54321',
      anonKey: 'synthetic-local-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        persistSession: false,
      ),
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  testWidgets('CustomerSavedAddresses empty state renders add buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const CustomerSavedAddresses(
          initialRows: [],
          autoLoad: false,
          customerId: 'cust_123',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify AppBar add button exists
    expect(find.byKey(const Key('add_address_appbar_button')), findsOneWidget);

    // Verify FloatingActionButton exists
    expect(find.byKey(const Key('add_address_fab')), findsOneWidget);
    expect(find.text('إضافة عنوان جديد'), findsWidgets);

    // Verify empty state container button exists
    expect(
      find.byKey(const Key('add_address_empty_state_button')),
      findsOneWidget,
    );
  });

  testWidgets('Tapping add button opens the Add Address sheet', (tester) async {
    Map<String, dynamic>? savedPayload;

    await tester.pumpWidget(
      _wrap(
        CustomerSavedAddresses(
          initialRows: const [],
          autoLoad: false,
          customerId: 'cust_123',
          onSaveAddress: (data) async {
            savedPayload = data;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap FAB
    await tester.tap(find.byKey(const Key('add_address_fab')));
    await tester.pumpAndSettle();

    // Verify sheet opened
    expect(find.text('إضافة عنوان جديد'), findsWidgets);
    expect(find.text('المنزل'), findsWidgets);
    expect(find.text('العمل'), findsWidgets);
    expect(find.text('أخرى'), findsWidgets);
    expect(find.text('حدائق الأهرام'), findsOneWidget);
    expect(find.text('عنوان آخر'), findsOneWidget);
    expect(find.text('رقم العمارة *'), findsOneWidget);
    expect(find.byKey(const Key('save_address_submit_button')), findsOneWidget);

    // Enter building number
    await tester.enterText(
      find.widgetWithText(TextFormField, 'رقم العمارة *'),
      '145',
    );
    await tester.pumpAndSettle();

    // Scroll save button into view and submit
    await tester.ensureVisible(find.byKey(const Key('save_address_submit_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_address_submit_button')));
    await tester.pumpAndSettle();

    // Verify save payload
    expect(savedPayload, isNotNull);
    expect(savedPayload!['label'], 'المنزل');
    expect(savedPayload!['area_letter'], 'أ');
    expect(savedPayload!['building_number'], '145');
    expect(
      savedPayload!['display_address'],
      contains('حدائق الأهرام - منطقة أ - عمارة 145'),
    );
  });

  testWidgets('CustomerSavedAddresses renders address list correctly', (
    tester,
  ) async {
    final rows = [
      {
        'id': 'addr_1',
        'label': 'البيت',
        'display_address': 'حدائق الأهرام - منطقة ج - عمارة 42',
        'is_default': true,
      },
      {
        'id': 'addr_2',
        'label': 'المكتب',
        'display_address': 'الدقي - شارع التحرير',
        'is_default': false,
      },
    ];

    await tester.pumpWidget(
      _wrap(
        CustomerSavedAddresses(
          initialRows: rows,
          autoLoad: false,
          customerId: 'cust_123',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('البيت'), findsOneWidget);
    expect(find.text('المكتب'), findsOneWidget);
    expect(find.text('افتراضي'), findsOneWidget);
    expect(find.byKey(const Key('add_address_fab')), findsOneWidget);
    expect(find.byKey(const Key('add_address_appbar_button')), findsOneWidget);
  });
}
