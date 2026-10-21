import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/presentation/captain_dashboard_screen/captain_debt_invoice_v17.dart';

void main() {
  for (final language in ['ar','en']) {
    for (final brightness in Brightness.values) {
      testWidgets('Read-only debt invoice is localized and fits 320px $language/$brightness', (tester) async {
        tester.view.physicalSize=const Size(320,640);
        tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final l=lookupAppLocalizations(Locale(language));
        await tester.pumpWidget(MaterialApp(locale:Locale(language),
          localizationsDelegates:AppLocalizations.localizationsDelegates,
          supportedLocales:AppLocalizations.supportedLocales,
          theme:AppTheme.productTheme(brightness,language),
          home:CaptainDebtInvoiceV17(loadInvoice:()async=>{
            'success':true,'amount_due':'100.00','invoice_number':'SYNTHETIC-REF','status':'pending',
          },loadSupportPhone:()async=>''),
        ));
        await tester.pumpAndSettle();
        expect(find.text(l.debtInvoiceAmount('100.00')),findsOneWidget);
        expect(find.text(l.debtInvoicePending),findsOneWidget);
        expect(find.text(l.debtInvoicePaid),findsNothing);
        expect(Directionality.of(tester.element(find.byType(CaptainDebtInvoiceV17))),
          language=='ar'?TextDirection.rtl:TextDirection.ltr);
        expect(tester.takeException(),isNull);
      });
    }
  }
  for(final amount in [null,'NaN','Infinity',-1]){
    testWidgets('Missing or invalid server debt amount never appears paid: $amount',(tester)async{
      final l=lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(MaterialApp(locale:const Locale('en'),
        localizationsDelegates:AppLocalizations.localizationsDelegates,
        supportedLocales:AppLocalizations.supportedLocales,
        home:CaptainDebtInvoiceV17(loadInvoice:()async=>{
          'success':true,'amount_due':amount,'status':'pending',
        },loadSupportPhone:()async=>''),
      ));
      await tester.pumpAndSettle();
      expect(find.text(l.debtInvoiceLoadFailed),findsOneWidget);
      expect(find.text(l.debtInvoicePaid),findsNothing);
      expect(tester.takeException(),isNull);
    });
  }
}
