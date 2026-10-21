import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/presentation/captain_dashboard_screen/widgets/captain_fare_preview_widget.dart';
import 'package:vetosanya/presentation/captain_dashboard_screen/widgets/captain_active_job_widget.dart';

void main(){
 for(final language in ['ar','en']){
  for(final dark in [true,false]){
   testWidgets('Captain fare and active ride $language dark=$dark at320',(tester)async{
    tester.view.physicalSize=const Size(320,800);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final l=lookupAppLocalizations(Locale(language));
    await tester.pumpWidget(MaterialApp(locale:Locale(language),localizationsDelegates:AppLocalizations.localizationsDelegates,supportedLocales:AppLocalizations.supportedLocales,theme:AppTheme.lightTheme,darkTheme:AppTheme.darkTheme,themeMode:dark?ThemeMode.dark:ThemeMode.light,
     home:Scaffold(body:SingleChildScrollView(child:Column(children:const[
      CaptainFarePreviewWidget(offer:{'trips':{'base_fare':'100.00','incentive_amount':10}}),
      CaptainActiveJobWidget(activeJob:{'id':'synthetic-trip','trip_status':'accepted','total_fare':'100','incentive_amount':'10','pickup_address':'مكان الانطلاق الأصلي','destination_address':'Original destination'}),
     ]))),
    ));await tester.pumpAndSettle();
    expect(find.text(l.moneyValue('100.00')),findsOneWidget);expect(find.text(l.captainFareIncentive('10.00')),findsOneWidget);
    expect(find.text(l.moneyValue('100')),findsOneWidget);expect(find.text('مكان الانطلاق الأصلي'),findsOneWidget);
    expect(find.text('Original destination'),findsOneWidget);expect(tester.takeException(),isNull);
   });
  }
 }
 testWidgets('Unknown captain price remains unavailable instead of zero',(tester)async{
  final l=lookupAppLocalizations(const Locale('en'));
  await tester.pumpWidget(MaterialApp(locale:const Locale('en'),localizationsDelegates:AppLocalizations.localizationsDelegates,supportedLocales:AppLocalizations.supportedLocales,theme:AppTheme.darkTheme,
   home:const Scaffold(body:Column(children:[CaptainFarePreviewWidget(offer:{'trips':{'base_fare':'NaN'}}),CaptainActiveJobWidget(activeJob:{'id':'synthetic','trip_status':'accepted','base_fare':null})])),
  ));await tester.pumpAndSettle();expect(find.text(l.captainFareUpdating),findsOneWidget);expect(find.text(l.historyAmountUnavailable),findsOneWidget);expect(find.text(l.moneyValue('0')),findsNothing);expect(tester.takeException(),isNull);
 });
}
