import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/customer/customer_more_screen.dart';

Widget _wrapScreen(Widget child) {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
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

  testWidgets(
    'CustomerMoreScreen renders all sections, options, and logout bottom sheet',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapScreen(const CustomerMoreScreen()));
      await tester.pumpAndSettle();

      // Top title and Profile Card
      expect(find.text('المزيد'), findsOneWidget);
      expect(find.text('حساب نشط وموثق'), findsOneWidget);

      // Section headers
      expect(find.text('الحساب والمشاوير'), findsOneWidget);
      expect(find.text('الخدمات والعروض'), findsOneWidget);

      // Verify removed buttons do not exist
      expect(find.text('إطاراتي ومكافآتي'), findsNothing);
      expect(find.text('اقتراحات عناويني'), findsNothing);
      expect(find.textContaining('اشتغل كابتن'), findsNothing);

      // Scroll to view subsequent sections
      await tester.scrollUntilVisible(
        find.text('تسجيل الخروج'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('الدعم والأمان'), findsOneWidget);
      expect(find.text('الإعدادات والمعلومات'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
      expect(find.text('VETO SANYA • الإصدار 2.0.0'), findsOneWidget);

      // Tap logout button to open modern bottom sheet
      await tester.ensureVisible(find.byIcon(Icons.logout_rounded));
      await tester.tap(find.byIcon(Icons.logout_rounded));
      await tester.pumpAndSettle();

      // Verify bottom sheet title and confirmation options
      expect(
        find.text('هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟'),
        findsOneWidget,
      );
      expect(find.text('تأكيد الخروج'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);

      // Tap cancel to close bottom sheet
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      // Bottom sheet is dismissed
      expect(
        find.text('هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟'),
        findsNothing,
      );
      expect(find.text('المزيد'), findsOneWidget);
    },
  );
}
