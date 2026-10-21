import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/home_screen/widgets/product_home_panel.dart';
import 'package:vetosanya/presentation/home_screen/widgets/home_promo_widget.dart';
import 'package:vetosanya/presentation/home_screen/widgets/home_header_widget.dart';
import 'package:vetosanya/services/booking_address_seed.dart';

Widget app(Widget child,{String language='en',Brightness brightness=Brightness.light})=>MaterialApp(
  locale:Locale(language),supportedLocales:AppLocalizations.supportedLocales,
  localizationsDelegates:const [AppLocalizations.delegate,GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],
  theme:ThemeData(brightness:brightness),home:Scaffold(body:SingleChildScrollView(child:Padding(padding:const EdgeInsets.all(16),child:child))));
const home={'label':'منزلي الأصلي','display_address':'شارع اختباري — منزلي','latitude':29.98,'longitude':31.11,'is_default':true};
const work={'label':'Work','display_address':'عنوان عملي الأصلي','latitude':30.01,'longitude':31.12,'is_default':false,'is_outside_city':true};
void main(){
  testWidgets('Primary booking entry exposes one accessibility action', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
    var started = 0;
    await tester.pumpWidget(app(ProductHomePanel(customerId: 'synthetic',
      pickupCaption: 'Choose pickup', loadAddresses: (_) async => [],
      loadRecentTrips: (_) async => [], onMarket: () {},
      onStart: (_, __) => started++), language: 'en', brightness: Brightness.light));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Where to?'), findsOneWidget);
    await tester.tap(find.text('Where to?'));
    expect(started, 1);
    } finally { semantics.dispose(); }
  });
  for(final language in ['ar','en'])for(final brightness in [Brightness.light,Brightness.dark]){
    testWidgets('Saved-address booking $language/$brightness uses original coordinates without GPS or a map', (tester)async{
      tester.view.physicalSize=const Size(320,720);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      BookingAddressSelection? selected;
      await tester.pumpWidget(app(ProductHomePanel(customerId:'synthetic',pickupCaption:'Choose pickup',
        loadAddresses:(_)async=>[home,work],loadRecentTrips:(_)async=>[],onMarket:(){},onStart:(selection,service)=>selected=selection),language:language,brightness:brightness));
      await tester.pumpAndSettle();
      final l=lookupAppLocalizations(Locale(language));
      expect(find.text(l.whereTo),findsOneWidget);
      await tester.tap(find.text(l.whereTo));
      expect(selected?.pickup?.latitude,29.98);
      expect(selected?.pickup?.longitude,31.11);
      expect(selected?.destination,isNull,reason:'V31 defers saved destination selection to the booking flow');
      expect(selected?.attempt,isNotNull);
      expect(tester.takeException(),isNull);
    });
  }
  testWidgets('Account switch removes previous account addresses before replacement fetch resolves', (tester)async{
    final pending=Completer<List<Map<String,dynamic>>>();
    Widget panel(String id)=>app(ProductHomePanel(key:const ValueKey('panel'),customerId:id,pickupCaption:'Choose pickup',
      loadAddresses:(id)=>id=='a'?Future.value([home]):pending.future,loadRecentTrips:(_)async=>[],onMarket:(){},onStart:(_ , __){}));
    await tester.pumpWidget(panel('a'));await tester.pumpAndSettle();expect(find.text('شارع اختباري — منزلي'),findsWidgets);
    await tester.pumpWidget(panel('b'));await tester.pump();expect(find.text('شارع اختباري — منزلي'),findsNothing);
    pending.complete([]);await tester.pumpAndSettle();expect(tester.takeException(),isNull);
  });
  testWidgets('No server banner means no invented discount or VETO20 coupon', (tester)async{
    await tester.pumpWidget(app(HomePromoWidget(loadBanners:()async=>[])));
    await tester.pumpAndSettle();expect(find.textContaining('VETO20'),findsNothing);expect(find.byType(Card),findsNothing);
    await tester.pumpWidget(app(HomePromoWidget(key:const ValueKey('real'),loadBanners:()async=>[{'title':'Verified server offer','subtitle':'Actual terms','action_type':'none'}])));
    await tester.pumpAndSettle();expect(find.text('Verified server offer'),findsOneWidget);expect(find.text('Actual terms'),findsOneWidget);
    expect(find.text('Book now'),findsNothing);
  });
  testWidgets('Small home header keeps wallet and notifications visible', (tester)async{
    tester.view.physicalSize=const Size(320,720);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(HomeHeaderWidget(customerName:'اسم طويل للاختبار',locationCaption:'العنوان الأصلي محفوظ',walletBalance:12345.67,completedTrips:12,unreadCount:120,onNotificationTap:(){},onProfileTap:(){})));
    await tester.pumpAndSettle();expect(find.text('99+'),findsOneWidget);expect(find.text('12345.67 EGP'),findsOneWidget);expect(tester.takeException(),isNull);
  });
}
