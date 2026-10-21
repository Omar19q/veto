import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/presentation/captain_dashboard_screen/widgets/captain_reward_banner.dart';
void main(){
 for(final language in ['ar','en']){
  for(final dark in [true,false]){
   testWidgets('Legacy captain reward $language dark=$dark preserves manual payout and campaign text at320',(tester)async{
    tester.view.physicalSize=const Size(320,800);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final l=lookupAppLocalizations(Locale(language));
    await tester.pumpWidget(MaterialApp(locale:Locale(language),localizationsDelegates:AppLocalizations.localizationsDelegates,supportedLocales:AppLocalizations.supportedLocales,theme:AppTheme.lightTheme,darkTheme:AppTheme.darkTheme,themeMode:dark?ThemeMode.dark:ThemeMode.light,
     home:const Scaffold(body:CaptainRewardBanner(campaign:{'title':'اسم الحملة الأصلي','description':'الوصف المعتمد من الأدمن','target_trips':10,'progress':3,'reward_amount':'65.00','status':'pending'})),
    ));await tester.pumpAndSettle();
    expect(find.text('اسم الحملة الأصلي'),findsOneWidget);expect(find.text('الوصف المعتمد من الأدمن'),findsOneWidget);
    expect(find.text(l.legacyCaptainRewardProgress('3','10')),findsOneWidget);expect(find.text(l.moneyValue('65.00')),findsOneWidget);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox());
   });
  }
 }
 testWidgets('Unknown legacy reward amount is not displayed as a zero reward',(tester)async{
  final l=lookupAppLocalizations(const Locale('en'));
  await tester.pumpWidget(MaterialApp(locale:const Locale('en'),localizationsDelegates:AppLocalizations.localizationsDelegates,supportedLocales:AppLocalizations.supportedLocales,theme:AppTheme.darkTheme,
   home:const Scaffold(body:CaptainRewardBanner(campaign:{'title':'Synthetic campaign','target_trips':10,'progress':3,'reward_amount':'NaN'})),
  ));await tester.pumpAndSettle();expect(find.text(l.historyAmountUnavailable),findsOneWidget);expect(find.text(l.moneyValue('0.00')),findsNothing);expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox());
 });
}
