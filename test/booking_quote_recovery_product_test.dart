import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/services/booking_address_seed.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/presentation/trip_booking_screen/trip_booking_screen.dart';

class LocalQuoteHttp extends http.BaseClient {
  int quoteCalls = 0;
  final user = {
    'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'aud': 'authenticated', 'role': 'authenticated',
    'app_metadata': {'role': 'customer'}, 'user_metadata': <String,dynamic>{},
    'created_at': '2026-10-14T00:00:00Z',
  };
  @override Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.host != '127.0.0.1') throw StateError('Nonlocal test endpoint refused');
    Object? body = [];
    var status = 200;
    if (request.url.path.endsWith('/token')) {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}')).replaceAll('=', '');
      final payload = base64Url.encode(utf8.encode(jsonEncode({
        'sub':user['id'],'exp':DateTime.now().millisecondsSinceEpoch~/1000+3600,
      }))).replaceAll('=', '');
      body = {'access_token':'$header.$payload.synthetic-signature',
        'refresh_token':'synthetic-local-refresh','token_type':'bearer','expires_in':3600,'user':user};
    } else if (request.url.path.endsWith('/user')) {
      body=user;
    } else if (request.url.path.endsWith('/customers')) {
      body=[{'id':'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'user_id':user['id'],'wallet_balance':200,'is_active':true}];
    } else if (request.url.path.endsWith('/route-price-quote')) {
      quoteCalls++;
      if (quoteCalls==1) { status=429;body={'error':'quote_rate_limit'}; }
      else {body={'id':'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        'base_fare':100,'distance_km':1.4,'duration_minutes':3,
        'expires_at':DateTime.now().toUtc().add(const Duration(minutes:2)).toIso8601String()};}
    }
    return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))),status,
      headers:{'content-type':'application/json'});
  }
}

void main(){
  Future<void> settleUntil(WidgetTester tester, bool Function() ready) async {
    // Supabase encodes/decodes in a real isolate, outside the widget fake clock.
    for (var i=0;i<100 && !ready();i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds:10)));
      await tester.pump(const Duration(milliseconds:50));
    }
    await tester.pumpAndSettle();
  }
  final api=LocalQuoteHttp();
  setUpAll(()async{
    SharedPreferences.setMockInitialValues({'veto_first_trip_guide_v18_aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa':true});
    await Supabase.initialize(url:'http://127.0.0.1:54321',anonKey:'synthetic-local-key',
      httpClient:api,authOptions:const FlutterAuthClientOptions(autoRefreshToken:false,persistSession:false));
    await Supabase.instance.client.auth.signInWithPassword(email:'synthetic@example.invalid',password:'synthetic-local-only');
  });
  tearDownAll(()async{await Supabase.instance.dispose();api.close();});
  for(final language in ['ar','en']){
    for(final brightness in Brightness.values){
      testWidgets('Quote failure retains saved destination and one explicit retry restores fare $language/$brightness',(tester)async{
        api.quoteCalls=0;
        tester.view.physicalSize=const Size(320,720);tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
        final l=lookupAppLocalizations(Locale(language));
        await tester.pumpWidget(MaterialApp(locale:Locale(language),
          localizationsDelegates:AppLocalizations.localizationsDelegates,
          supportedLocales:AppLocalizations.supportedLocales,
          theme:AppTheme.productTheme(brightness,language),
          home:const TripBookingScreen(initialAddresses:BookingAddressSelection(
            pickup:BookingAddressSeed(label:'SYNTHETIC Home',latitude:29.974,longitude:31.101),
            destination:BookingAddressSeed(label:'SYNTHETIC Work',latitude:29.978,longitude:31.108),
          )),
        ));
        await settleUntil(tester,()=>find.text(language=='ar'?'تأكيد مكان الركوب':'Confirm pickup').evaluate().isNotEmpty);
        await tester.ensureVisible(find.text(language=='ar'?'تأكيد مكان الركوب':'Confirm pickup'));
        await tester.tap(find.text(language=='ar'?'تأكيد مكان الركوب':'Confirm pickup'));
        await settleUntil(tester,()=>find.text(l.quoteRateLimited).evaluate().isNotEmpty);
        if (find.text(l.quoteRateLimited).evaluate().isEmpty) {
          debugPrint('Local quote diagnostic: calls=${api.quoteCalls}, signedIn=${Supabase.instance.client.auth.currentUser != null}, texts=${tester.widgetList<Text>(find.byType(Text)).map((t)=>t.data).toList()}');
        }
        expect(find.text(l.quoteRateLimited),findsOneWidget);
        expect(find.text('SYNTHETIC Work'),findsWidgets);
        expect(api.quoteCalls,1);
        await tester.tap(find.widgetWithText(TextButton,l.retry));
        await settleUntil(tester,()=>find.text(l.uia39f7a83).evaluate().isNotEmpty);
        expect(find.text(l.quoteRateLimited),findsNothing);
        expect(find.text(l.uia39f7a83),findsOneWidget);
        expect(tester.getRect(find.text(l.uia39f7a83)).bottom, greaterThan(540),
          reason:'The fare sheet must use the screen height, not the small map header height');
        expect(api.quoteCalls,2,reason:'No background quotes for services the customer did not request');
        expect(tester.takeException(),isNull);
        await tester.pumpWidget(const SizedBox.shrink());await tester.pump();
      });
    }
  }
}
