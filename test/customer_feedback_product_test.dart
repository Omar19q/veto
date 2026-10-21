import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/services/customer_feedback_backend.dart';
import 'package:vetosanya/presentation/feedback/feedback_screen.dart';

class FeedbackStub extends CustomerFeedbackBackend{
 String uid='synthetic-a';final changes=StreamController<String?>.broadcast(sync:true);
 Completer<Map<String,dynamic>>? pending;
 final requests=<Map<String,String>>[];
 @override String? get accountId=>uid;
 @override Stream<String?> get accountChanges=>changes.stream;
 @override Future<Map<String,dynamic>> submit({required String type,required String message})async{requests.add({'uid':uid,'type':type,'message':message});if(pending!=null)return pending!.future;throw StateError('synthetic-unconfirmed');}
 void switchTo(String id){uid=id;changes.add(id);}
}
Widget app(FeedbackStub backend,String language,bool dark)=>MaterialApp(locale:Locale(language),localizationsDelegates:AppLocalizations.localizationsDelegates,supportedLocales:AppLocalizations.supportedLocales,theme:AppTheme.lightTheme,darkTheme:AppTheme.darkTheme,themeMode:dark?ThemeMode.dark:ThemeMode.light,home:FeedbackScreen(backend:backend));
void main(){
 for(final language in ['ar','en']){
  for(final dark in [true,false]){
   testWidgets('Feedback $language dark=$dark keeps canonical complaint and draft at320',(tester)async{
    tester.view.physicalSize=const Size(320,800);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final backend=FeedbackStub();addTearDown(backend.changes.close);final l=lookupAppLocalizations(Locale(language));
    await tester.pumpWidget(app(backend,language,dark));await tester.pumpAndSettle();
    await tester.tap(find.text(l.feedbackComplaint));await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),'نص العميل الأصلي');
    await tester.ensureVisible(find.text(l.feedbackSend));await tester.pumpAndSettle();await tester.tap(find.text(l.feedbackSend));await tester.pumpAndSettle();
    expect(backend.requests,[{'uid':'synthetic-a','type':'complaint','message':'نص العميل الأصلي'}]);
    expect(find.text(l.feedbackUnconfirmed),findsOneWidget);expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,'نص العميل الأصلي');
    expect(tester.takeException(),isNull);
   });
  }
 }
 testWidgets('Account change clears old feedback and ignores its acknowledgement',(tester)async{
  final backend=FeedbackStub()..pending=Completer<Map<String,dynamic>>();addTearDown(backend.changes.close);
  await tester.pumpWidget(app(backend,'en',true));await tester.pumpAndSettle();final l=lookupAppLocalizations(const Locale('en'));
  await tester.enterText(find.byType(TextField),'Private previous-account text');await tester.tap(find.text(l.feedbackSend));await tester.pump();
  backend.switchTo('synthetic-b');await tester.pump();backend.pending!.complete({'success':true});await tester.pumpAndSettle();
  expect(find.text('Private previous-account text'),findsNothing);expect(find.text(l.feedbackSent),findsNothing);
  expect(find.text(l.feedbackAccountChanged),findsOneWidget);expect(backend.requests.length,1);expect(tester.takeException(),isNull);
 });
 testWidgets('Too-short feedback never reaches backend',(tester)async{
  final backend=FeedbackStub();addTearDown(backend.changes.close);
  await tester.pumpWidget(app(backend,'en',false));await tester.pumpAndSettle();final l=lookupAppLocalizations(const Locale('en'));
  await tester.enterText(find.byType(TextField),'x');await tester.tap(find.text(l.feedbackSend));await tester.pumpAndSettle();
  expect(find.text(l.feedbackClearMessage),findsOneWidget);expect(backend.requests,isEmpty);expect(tester.takeException(),isNull);
 });
}
