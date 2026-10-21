import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/trip_booking_screen/widgets/localized_booking_failure.dart';

void main() {
  for (final language in ['ar', 'en']) {
    testWidgets('Booking uncertainty and coverage remain explicit in $language',
        (tester) async {
      final l = lookupAppLocalizations(Locale(language));
      final cases = <Object, String>{
        TimeoutException('secret diagnostic'): l.bookingCreateUnconfirmed,
        const PostgrestException(message: 'city_not_active', code: 'P0001'):
            l.bookingCoverageUnavailable,
        const PostgrestException(message: 'private diagnostic', code: '42501'):
            l.bookingSessionUnavailable,
        const PostgrestException(message: 'private diagnostic', code: 'P0001'):
            l.bookingCreateRejected,
        StateError('promo_expired'): l.bookingPromoExpired,
      };
      for (final entry in cases.entries) {
        await tester.pumpWidget(MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate],
          home: Builder(builder: (context) => Scaffold(body: ListView(children: [
            Text(localizedBookingFailure(context, entry.key)),
            Text(localizedBookingFailure(context, entry.key, alreadyCreated: true)),
          ]))),
        ));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text(l.bookingCreatedDistributionFailed), findsOneWidget);
        expect(find.textContaining('private diagnostic'), findsNothing);
        expect(find.textContaining('secret diagnostic'), findsNothing);
      }
    });
  }
}
