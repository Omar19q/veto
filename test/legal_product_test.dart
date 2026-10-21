import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/presentation/legal/legal_center_screen.dart';
import 'package:vetosanya/presentation/legal/veto_legal_content.dart';
void main(){
 test('Legal translations preserve every page/section and existing contact channel',(){
  final english=VetoLegalContent.forLanguage('en'), arabic=VetoLegalContent.forLanguage('ar');
  expect(english.keys.toSet(),arabic.keys.toSet());
  for(final key in arabic.keys){
   expect((english[key]!['sections'] as List).length,(arabic[key]!['sections'] as List).length);
   expect(english[key]!['title'],isNot(arabic[key]!['title']));
   expect((english[key]!['sections'] as List).every((s)=>(s['heading'] as String).isNotEmpty && (s['body'] as String).isNotEmpty),isTrue);
  }
  expect(VetoLegalContent.contactPhone,'01031517830');
  expect((english['deletion']!['sections'] as List).last['body'],contains('do not automatically delete'));
 });
 for(final key in ['privacy','terms','deletion','safety']){
  for(final language in ['ar','en']){
   for(final dark in [true,false]){
    testWidgets('Legal $key $language dark=$dark readable at320 without backend',(tester)async{
     tester.view.physicalSize=const Size(320,568);tester.view.devicePixelRatio=1;
     addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
     await tester.pumpWidget(MaterialApp(locale:Locale(language),localizationsDelegates:AppLocalizations.localizationsDelegates,supportedLocales:AppLocalizations.supportedLocales,theme:AppTheme.lightTheme,darkTheme:AppTheme.darkTheme,themeMode:dark?ThemeMode.dark:ThemeMode.light,home:VetoLegalCenterScreen(pageKey:key)));
     await tester.pumpAndSettle();
     expect(find.text(VetoLegalContent.forLanguage(language)[key]!['title']),findsWidgets);
     final sections=VetoLegalContent.forLanguage(language)[key]!['sections'] as List;
     await tester.scrollUntilVisible(find.text(sections.last['heading']),200,scrollable:find.byType(Scrollable).first);
     expect(find.text(sections.last['heading']),findsOneWidget);
     expect(Directionality.of(tester.element(find.byType(VetoLegalCenterScreen))),language=='ar'?TextDirection.rtl:TextDirection.ltr);
     expect(tester.takeException(),isNull);
    });
   }
  }
 }
}
