import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/trip_booking_screen/widgets/localized_cancellation_failure.dart';

void main() {
  for (final language in ['ar','en']) {
    testWidgets('Cancellation errors retain cause and uncertainty in $language', (tester) async {
      final l = lookupAppLocalizations(Locale(language));
      final cases = <Object,String>{
        StateError('PGRST202'): l.cancelServiceUnavailable,
        StateError('financial_conflict'): l.cancelFinancialGuard,
        StateError('captain_assigned_refresh'): l.cancelAcceptanceRace,
        StateError('42501'): l.cancelSessionUnavailable,
        TimeoutException('synthetic'): l.cancelUnconfirmed,
      };
      for (final entry in cases.entries) {
        await tester.pumpWidget(MaterialApp(locale:Locale(language),
          supportedLocales:AppLocalizations.supportedLocales,
          localizationsDelegates:const [AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate],
          home:Builder(builder:(context)=>Text(localizedCancellationFailure(context,entry.key)))));
        await tester.pumpAndSettle();
        expect(find.text(entry.value),findsOneWidget);
      }
    });
  }
}
