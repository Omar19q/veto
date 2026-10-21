import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/services/ride_categories.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/widgets/ride_category_card.dart';

const categories=[
 {'id':'veto_economy','base_service':'car_ride','name_ar':'فيتو اقتصادي','name_en':'VETO Economy','description_ar':'مشوارك اليومي بسعر مناسب','description_en':'Your everyday ride','accent':'#FFC247','enabled':true},
 {'id':'veto_comfort','base_service':'car_ride','name_ar':'فيتو راحة','name_en':'VETO Comfort','description_ar':'عربيات أحدث وراحة أكتر','description_en':'More room, more comfort','accent':'#7BAED6','enabled':true},
 {'id':'veto_premium','base_service':'car_ride','name_ar':'فيتو بريميوم','name_en':'VETO Premium','description_ar':'مشوار أرقى وعربيات مميزة','description_en':'An elevated ride','accent':'#D7B878','enabled':true},
 {'id':'veto_ladies','base_service':'car_ride','name_ar':'فيتو سيدات','name_en':'VETO Ladies','description_ar':'مشوارك مع سائقة معتمدة','description_en':'Ride with an approved woman driver','accent':'#9A86B8','enabled':false},
];
void main(){
 setUpAll(()async{for(final font in [('IBMPlexSansArabic','assets/fonts/IBMPlexSansArabic-Regular.ttf'),('Inter','assets/fonts/Inter-Variable.ttf'),('MaterialIcons','fonts/MaterialIcons-Regular.otf')]){await(FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();}});
 for(final width in [320.0,360.0,390.0,430.0])for(final lang in ['ar','en'])for(final mode in Brightness.values)for(final scale in [1.0,2.0]){
  testWidgets('Category list $width $lang $mode scale=$scale',(tester)async{
   tester.view.physicalSize=Size(width,640);tester.view.devicePixelRatio=1;
   addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
   var selected=0;final key=GlobalKey();
   await tester.pumpWidget(MaterialApp(locale:Locale(lang),supportedLocales:AppLocalizations.supportedLocales,localizationsDelegates:AppLocalizations.localizationsDelegates,
    theme:AppTheme.productTheme(mode,lang),builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(scale)),child:child!),
    home:RepaintBoundary(key:key,child:Scaffold(appBar:AppBar(title:Text(lang=='ar'?'اختار مشوارك':'Choose your ride')),
    body:ListView(padding:const EdgeInsets.all(12),children:[for(var i=0;i<categories.length;i++)Padding(padding:const EdgeInsets.only(bottom:8),child:RideCategoryCard(category:RideCategory(categories[i]),selected:i==0,fare:i==0?43:null,onTap:i==3?null:()=>selected++))]),
    bottomNavigationBar:SafeArea(child:Padding(padding:const EdgeInsets.all(12),child:FilledButton(onPressed:(){},child:Text(lang=='ar'?'أكد واطلب مشوارك':'Confirm and request'))))))));
   await tester.pumpAndSettle();expect(tester.takeException(),isNull);
   await tester.tap(find.byType(RideCategoryCard).first);expect(selected,1);
   final action=find.byType(FilledButton);expect(tester.getRect(action).bottom,lessThanOrEqualTo(640));
   await tester.scrollUntilVisible(find.byType(RideCategoryCard).last,100);await tester.pumpAndSettle();expect(tester.takeException(),isNull);
   if(width==390 && scale==1){await tester.scrollUntilVisible(find.byType(RideCategoryCard).first,-100);await tester.pumpAndSettle();await tester.runAsync(()async{
     final render=key.currentContext!.findRenderObject()! as RenderRepaintBoundary;final picture=await render.toImage(pixelRatio:2);final bytes=await picture.toByteData(format:ui.ImageByteFormat.png);final f=File('verification/previews/categories_${lang}_${mode.name}.png');await f.parent.create(recursive:true);await f.writeAsBytes(bytes!.buffer.asUint8List());picture.dispose();
   });}
   await tester.pumpWidget(const SizedBox.shrink());
  });
 }
}
