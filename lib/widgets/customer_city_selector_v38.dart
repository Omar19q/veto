import '../l10n/strings.dart';
import 'package:flutter/material.dart';

import '../services/customer_city_scope_v38.dart';
import '../services/supabase_service.dart';
import '../services/zone_pricing_service.dart';

/// Uses already active pricing zones. Draft catalog entries are visible but
/// disabled. Selecting a city never changes coordinates or prices.
Future<void> showCustomerCitySelectorV38(
  BuildContext context, {
  required ValueChanged<String> onSelected,
}) async {
  List<PricingZone> live = const [];
  List<Map<String, dynamic>> draft = const [];
  try {
    live =
        (await ZonePricingService.instance.zones())
            .where((zone) => zone.active && !zone.global)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
  } catch (_) {
    /* Never substitute invented cities or service areas. */
  }
  try {
    final response = await SupabaseService.instance.client
        .rpc('v38_customer_city_choices')
        .timeout(const Duration(seconds: 6));
    if (response is List) {
      draft = response
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
  } catch (_) {
    /* V38 SQL may not be installed yet. */
  }
  if (!context.mounted) return;
  final activeNames = live.map((z) => z.name).toSet();
  final other = draft
      .where((d) => !activeNames.contains(d['name']?.toString()))
      .toList();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Directionality(
        textDirection: Directionality.of(context),
        child: SizedBox(
          height: (200.0 + (live.length + other.length) * 76).clamp(
            200.0,
            MediaQuery.sizeOf(sheet).height * .8,
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  context.strings.cityChoose,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
                ),
              ),
              Text(
                context.strings.cityActualPrice,
                style: TextStyle(fontSize: 12),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.my_location_rounded),
                      title: Text(context.strings.cityAutomaticLocation),
                      onTap: () {
                        CustomerCityScopeV38.resetToGps();
                        onSelected('');
                        Navigator.pop(sheet);
                      },
                    ),
                    if (live.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? 'مفيش قائمة مدن متاحة دلوقتي. اختار نقطة الركوب من الخريطة أو المفضلة؛ تغطية الرحلة والسعر بيتأكدوا من السيرفر.'
                              : 'No city list is available right now. Choose pickup on the map or from saved places; the server confirms coverage and fare.',
                        ),
                      ),
                    for (final city in live)
                      ListTile(
                        leading: const Icon(
                          Icons.location_city_outlined,
                          color: Colors.amber,
                        ),
                        title: Text(city.name),
                        subtitle: Text(context.strings.cityPickupNext),
                        onTap: () {
                          CustomerCityScopeV38.choose(city.name);
                          onSelected(city.name);
                          Navigator.pop(sheet);
                        },
                      ),
                    if (other.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          context.strings.cityComingSoon,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    for (final city in other)
                      ListTile(
                        enabled: false,
                        leading: const Icon(Icons.lock_outline_rounded),
                        title: Text(city['name']?.toString() ?? ''),
                        subtitle: Text(
                          context.strings.cityNotActive(
                            city['governorate']?.toString() ?? '',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
