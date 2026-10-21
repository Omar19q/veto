import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/growth/growth_screens.dart';
import 'package:vetosanya/services/growth_service.dart';

void main() {
  testWidgets('An unavailable welcome can be dismissed without a referral decision', (tester) async {
    final calls=<String>[];
    final service=GrowthService(rpc:(name,args) async {
      calls.add(name);throw StateError('synthetic offline');
    });
    final l=lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(MaterialApp(locale:const Locale('en'),
      localizationsDelegates:AppLocalizations.localizationsDelegates,
      supportedLocales:AppLocalizations.supportedLocales,
      home:Builder(builder:(context)=>Scaffold(body:TextButton(
        onPressed:()=>showModalBottomSheet<void>(context:context,
          isScrollControlled:true,builder:(_)=>GrowthGiftSheet(service:service,canUseCode:false)),
        child:const Text('Open welcome'))))));
    await tester.tap(find.text('Open welcome'));await tester.pumpAndSettle();
    await tester.tap(find.text(l.growtha3238c1d));await tester.pumpAndSettle();
    expect(find.byType(GrowthGiftSheet),findsNothing);
    expect(calls.contains('growth_bind_referral_v1'),isFalse);
    expect(tester.takeException(),isNull);
  });
}
