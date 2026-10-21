import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/product_geocoding_service.dart';
import 'package:vetosanya/services/booking_address_seed.dart';

void main() {
  test('Geoapify route preview converts lon/lat geometry without becoming a financial quote', () async {
    final service=ProductGeocodingService(invoke:(body)async{
      expect(body['operation'],'route');
      expect(body['points'],[[29.98,31.11],[30.01,31.12]]);
      return {'distance_km':3.2,'duration_minutes':7,'geometry':{'type':'MultiLineString','coordinates':[[[31.11,29.98],[31.12,30.01]]]},'financial_quote':false};
    });
    final route=await service.route(29.98,31.11,30.01,31.12,language:'en');
    expect(route.points,[[29.98,31.11],[30.01,31.12]]);
  });
  test('Invalid route provider geometry is rejected rather than displayed as a real route', () async {
    final service=ProductGeocodingService(invoke:(_)async=>{'distance_km':3,'duration_minutes':5,'geometry':{'type':'LineString','coordinates':[[31,29],[31,double.nan]]}});
    await expectLater(service.route(29,31,30,32,language:'ar'),throwsStateError);
    await expectLater(service.route(double.nan,31,30,32,language:'ar'),throwsArgumentError);
  });
  test(
    'No address invention when reverse result empty; language-separated cache',
    () async {
      var calls = 0;
      final service = ProductGeocodingService(
        invoke: (body) async {
          calls++;
          return {'results': []};
        },
      );
      expect(await service.reverse(29.98, 31.11, language: 'ar'), isNull);
      expect(await service.reverse(29.98, 31.11, language: 'ar'), isNull);
      expect(calls, 1);
      await service.reverse(29.98, 31.11, language: 'en');
      expect(calls, 2);
    },
  );
  test(
    'Reverse preserves supplied street name and rejects invalid provider coordinates',
    () async {
      final service = ProductGeocodingService(
        invoke: (body) async => {
          'results': [
            {'latitude': 100, 'longitude': 31, 'address': 'invalid'},
            {
              'latitude': 29.98,
              'longitude': 31.11,
              'address': 'شارع ورد من المصدر',
            },
          ],
        },
      );
      expect(
        (await service.reverse(29.98, 31.11, language: 'en'))?.address,
        'شارع ورد من المصدر',
      );
      await expectLater(
        service.reverse(double.nan, 31, language: 'en'),
        throwsArgumentError,
      );
    },
  );
  test(
    'Saved and recent shortcuts retain actual coordinate columns and reject malformed data',
    () {
      expect(
        BookingAddressSeed.saved({
          'label': 'Home',
          'latitude': double.infinity,
          'longitude': 31,
        }),
        isNull,
      );
      final saved = BookingAddressSeed.saved({
        'display_address': 'عنوان المستخدم',
        'latitude': '29.98',
        'longitude': '31.11',
        'area_letter': 'أ',
        'building_number': '12',
        'is_default': true,
      })!;
      expect(saved.label, 'عنوان المستخدم');
      expect(saved.defaultPickup, isTrue);
      expect(saved.buildingNumber, '12');
      final recent = BookingAddressSeed.recent({
        'destination_address': 'وجهة كما سُجلت',
        'destination_latitude': 30,
        'destination_longitude': 31.2,
      })!;
      expect(recent.latitude, 30);
      expect(recent.label, 'وجهة كما سُجلت');
    },
  );
}
