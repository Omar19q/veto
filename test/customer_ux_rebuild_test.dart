import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/widgets/customer_map_home.dart';
import 'package:vetosanya/presentation/home_screen/widgets/product_home_panel.dart';
import 'package:vetosanya/presentation/trip_booking_screen/widgets/booking_fare_sheet_widget.dart';
import 'package:vetosanya/services/customer_payment_preference.dart';

Widget harness(Widget child, String lang, Brightness mode, double scale) => MaterialApp(
  locale: Locale(lang), supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: AppTheme.productTheme(mode, lang),
  builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
    textScaler: TextScaler.linear(scale)), child: child!),
  home: Scaffold(body: child));

BookingFareSheetWidget fare({VoidCallback? confirm,
  Future<Map<String,dynamic>> Function(String,double)? promo,
  double price=100, double discount=50,
  void Function(String,double,double)? payment}) => BookingFareSheetWidget(
  serviceId:'car',pickupLabel:'عنوان انطلاق تجريبي',destinationLabel:'Synthetic destination',
  distance:2,duration:8,fare:price,growthDiscount:discount,availableGrowthDiscount:discount,
  incentiveAmount:0,passengerCount:1,walletBalance:20,
  onPassengerCountChanged:(_){},onPackageWeightChanged:(_){},onCustomerNoteChanged:(_){},
  onPaymentMethodChanged:payment??(_,__,___){},onConfirm:confirm??(){},onApplyPromo:promo);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    for(final font in [
      ('IBMPlexSansArabic','assets/fonts/IBMPlexSansArabic-Regular.ttf'),
      ('Inter','assets/fonts/Inter-Variable.ttf'),
      ('MaterialIcons','fonts/MaterialIcons-Regular.otf')]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });
  for (final width in [320.0,360.0,390.0,430.0,600.0]) {
    for (final lang in ['ar','en']) {
      for (final mode in Brightness.values) {
        for (final scale in [1.0,2.0]) {
          testWidgets('Home and fare $width $lang $mode scale=$scale', (tester) async {
            tester.view.physicalSize=Size(width,844);tester.view.devicePixelRatio=1;
            addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
            var booked=0;
            final l=lookupAppLocalizations(Locale(lang));
            final boundary=GlobalKey();
            await tester.pumpWidget(harness(RepaintBoundary(key:boundary,
              child:CustomerMapHome(
                // A labelled test double, never a fabricated customer location.
                map:ColoredBox(color:mode==Brightness.dark?const Color(0xFF1E2540):const Color(0xFFEAECEF),
                  child:Center(child:Text(lang=='ar'?'خريطة تجريبية • بدون موقع فعلي':'Test map • no live location'))),
                city:lang=='ar'?'حدائق الأهرام':'Hadayek Al Ahram',onCity:(){},onLocate:(){},
                onAccount:(){},onNotifications:(){},
                slivers:[SliverPadding(padding:const EdgeInsets.symmetric(horizontal:16),
                  sliver:SliverToBoxAdapter(child:ProductHomePanel(customerId:null,
                    pickupCaption:lang=='ar'?'اختار نقطة الركوب':'Choose pickup',
                    onStart:(_,__)=>booked++,onMarket:(){})))])),lang,mode,scale));
            await tester.pumpAndSettle();
            expect(tester.takeException(),isNull);
            if(width==390&&scale==1) await capture(tester,boundary,'home_${lang}_${mode.name}');
            final expand=find.text(l.expandBooking);
            await tester.tap(expand);await tester.pumpAndSettle();
            expect(find.text(l.collapseBooking),findsOneWidget);
            await tester.ensureVisible(find.text(l.whereTo));
            await tester.tap(find.text(l.whereTo));expect(booked,1);
            await tester.pumpWidget(harness(RepaintBoundary(key:boundary,child:fare(
              confirm:()=>booked++)),lang,mode,scale));
            await tester.pumpAndSettle();
            expect(tester.takeException(),isNull);
            expect(find.byKey(const ValueKey('booking-total')),findsOneWidget);
            expect(find.text(l.moneyValue('50.00')),findsWidgets);
            final button=find.widgetWithText(ElevatedButton,l.uia39f7a83);
            expect(tester.getRect(button).bottom,lessThanOrEqualTo(844));
            await tester.tap(button);expect(booked,2);
            if(width==390&&scale==1) await capture(tester,boundary,'fare_${lang}_${mode.name}');
            await tester.pumpWidget(const SizedBox());
          });
        }
      }
    }
  }
  test('Payment choices are isolated by account and reject invented methods',() async {
    final store=CustomerPaymentPreference();
    await store.save('synthetic-a','wallet');
    expect(await store.load('synthetic-a'),'wallet');
    expect(await store.load('synthetic-b'),isNull);
    expect(()=>store.save('synthetic-a','instapay'),throwsArgumentError);
  });
  testWidgets('Pending promo cannot be confirmed; an edited code ignores late success',(tester) async {
    final pending=Completer<Map<String,dynamic>>();var confirmed=0;
    final l=lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(harness(fare(discount:0,confirm:()=>confirmed++,
      promo:(_,__)=>pending.future),'en',Brightness.light,1));
    await tester.pumpAndSettle();
    final field=find.byType(TextField).first;
    await tester.ensureVisible(field);await tester.enterText(field,'SYNTHETIC');
    final apply=find.widgetWithText(ElevatedButton,l.ui268974da);
    await tester.ensureVisible(apply);await tester.tap(apply);await tester.pump();
    final confirm=find.widgetWithText(ElevatedButton,l.uia39f7a83);
    expect(tester.widget<ElevatedButton>(confirm).onPressed,isNull);
    await tester.enterText(field,'EDITED');await tester.pump();
    pending.complete({'success':true,'discount':50});await tester.pump();
    expect(find.text(l.promoAppliedValue('50.00')),findsNothing);
    expect(find.text(l.moneyValue('100.00')),findsWidgets);
    expect(confirmed,0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Payment modal supports cash and recalculates existing wallet split',(tester) async {
    final l=lookupAppLocalizations(const Locale('en'));String? method;double? cash;
    await tester.pumpWidget(harness(fare(payment:(m,w,c){method=m;cash=c;}),
      'en',Brightness.light,1));await tester.pumpAndSettle();
    expect(method,'combined');expect(cash,30);
    final change=find.text(l.changePayment);await tester.ensureVisible(change);
    await tester.tap(change);await tester.pumpAndSettle();
    await tester.tap(find.text(l.ui1881ccb3));await tester.pumpAndSettle();
    expect(method,'cash');expect(cash,50);
    expect(find.text('InstaPay'),findsNothing);
    expect(tester.takeException(),isNull);
  });
}

Future<void> capture(WidgetTester tester,GlobalKey key,String name) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final render=key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final picture=await render.toImage(pixelRatio:2);
    final bytes=await picture.toByteData(format:ui.ImageByteFormat.png);
    final file=File('UX_REBUILD/screens/${name}_SYNTHETIC.png');
    await file.parent.create(recursive:true);await file.writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}

