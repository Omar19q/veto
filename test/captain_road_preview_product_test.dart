import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/services/osrm_routing_service.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/presentation/captain_dashboard_screen/widgets/captain_route_preview_v45.dart';

void main(){
 for(final language in ['ar','en']){
  for(final available in [false,true]){
   testWidgets('Captain preview $language: road=$available, never invent a line between endpoints',(tester)async{
    tester.view.physicalSize=const Size(320,720);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final l=lookupAppLocalizations(Locale(language));
    await tester.pumpWidget(MaterialApp(locale:Locale(language),
      localizationsDelegates:AppLocalizations.localizationsDelegates,
      supportedLocales:AppLocalizations.supportedLocales,
      theme:AppTheme.productTheme(Brightness.dark,language),
      home:Scaffold(body:CaptainRoutePreviewV45(tripId:'synthetic',
       loadSnapshot:(id)async=>{'pickup_lat':29.974,'pickup_lng':31.101,
        'destination_lat':29.978,'destination_lng':31.108,'distance_km':1.4},
       loadRoad:(start,end)async=>available?const RouteResult(distanceKm:1.4,durationMinutes:3,
        routePoints:[[29.974,31.101],[29.975,31.106],[29.978,31.108]]):null,
      )),
    ));
    await tester.tap(find.text(l.captainRoadPreview));
    await tester.pumpAndSettle();
    final lines=find.byWidgetPredicate((widget)=>widget is PolylineLayer);
    expect(lines,available?findsOneWidget:findsNothing);
    if(available){
     final line=tester.widget<PolylineLayer>(lines).polylines.single;
     expect(line.points.length,3);
     expect(line.points[1].longitude,31.106);
    }
    expect(find.text(l.captainRoadExplanation),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());await tester.pump();
   });
  }
 }
}
