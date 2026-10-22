import '../../services/secure_draft_store.dart';
import '../../services/accepted_trip_navigation_coordinator.dart';
import 'widgets/localized_cancellation_failure.dart';
import 'widgets/localized_booking_failure.dart';
import './widgets/product_searching_view.dart';
import 'package:latlong2/latlong.dart';
import './widgets/search_price_suggestion_v9.dart';
import 'dart:async';
import '../../services/ride_categories.dart';
import '../../widgets/ride_category_card.dart';
import 'dart:math' as math;
import '../../services/booking_address_seed.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/growth_service.dart';
import '../../services/booking_performance.dart';
import '../../services/product_geocoding_service.dart';
import '../../services/osrm_routing_service.dart';
import '../../l10n/strings.dart';
import '../growth/growth_booking_progress.dart';
import '../../services/customer_location_state.dart';
import '../../services/app_sound_service.dart';
import '../../services/zone_pricing_service.dart';
import '../../services/customer_city_scope_v38.dart';
import '../../widgets/v37_suggest_address_button.dart';

import './widgets/booking_captain_offers_widget.dart';
import './widgets/booking_destination_sheet_widget.dart';
import './widgets/booking_fare_sheet_widget.dart';
import './widgets/booking_map_widget.dart';
import './widgets/booking_pickup_sheet_widget.dart';
import './widgets/booking_service_sheet_widget.dart';

enum BookingStep { service, pickup, destination, fare, searching, offers }

class _Booking {
  String? service;

  String? area;
  String? building;

  String? destination;
  String? destArea;
  String? destBuilding;

  String? tripId;

  double? pickupLat;
  double? pickupLng;

  double? destLat;
  double? destLng;

  double? distance;
  double? duration;
  double? fare;

  double? weight;

  int incentive = 0;
  int passengers = 1;

  String payment = 'cash';

  double wallet = 0;
  double cash = 0;

  List<List<double>>? route;

  String customerNote = '';
  String extraRequests = '';
  double? extraExpectedAmount;
  Map<String, dynamic>? pricingQuote;
  bool outsideCity = false;
}

class TripBookingScreen extends StatefulWidget {
  final String? retryTripId;
  final String? initialService;
  final String? resumeTripId;
  final bool timeoutRetry;
  final BookingAddressSelection? initialAddresses;
  const TripBookingScreen({
    super.key,
    this.retryTripId,
    this.initialService,
    this.resumeTripId,
    this.timeoutRetry = false,
    this.initialAddresses,
  });

  @override
  State<TripBookingScreen> createState() => _TripBookingScreenState();
}

class _TripBookingScreenState extends State<TripBookingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _Booking b = _Booking();
  SecureDraftStore? _draftStore;
  String? _bookingAccountId;
  bool _bookingAccountInvalidated = false;
  StreamSubscription<AuthState>? _bookingAuthSubscription;
  bool get _ownsAccount =>
      mounted &&
      !_bookingAccountInvalidated &&
      _bookingAccountId != null &&
      SupabaseService.instance.currentUser?.id == _bookingAccountId;
  BookingAddressSeed? _seedDestination;
  late final BookingPerformanceAttempt _bookingAttempt;
  bool _routePreviewUnavailable = false;

  BookingStep step = BookingStep.service;
  // Only brand-new standard bookings use the destination-first V36 flow.
  // Retry and resume keep their financial and navigation semantics untouched.
  bool get _routeFirstV36 =>
      widget.retryTripId == null && widget.resumeTripId == null;
  // Price comparison also applies to rides opened from a home service tile.
  // Resume/retry deliberately keep their original booking contract.
  bool get _canCompareRideFares =>
      widget.retryTripId == null &&
      widget.resumeTripId == null &&
      const {'car', 'motorcycle', 'package'}.contains(b.service) &&
      b.pickupLat != null &&
      b.pickupLng != null &&
      b.destLat != null &&
      b.destLng != null;
  List<RideCategory> _categoriesV3 = [];
  List<Map<String, dynamic>> _promiseOptionsV3 = [];
  final Set<String> _promisesV3 = {};
  String? _categoryV3;
  String? get _effectiveCategoryV3 {
    // An explicit choice survives catalogue outages and category suspension.
    // The server must reject it, never silently downgrade a Ladies booking.
    if (_categoryV3 != null) return _categoryV3;
    final matching = _categoriesV3.where(
      (c) => c.enabled && c.legacyService == b.service && c.id != 'veto_market',
    );
    return matching.where((c) => c.id != 'veto_ladies').firstOrNull?.id;
  }

  Future<void> _loadCategoriesV3() async {
    try {
      final data = await RideCategories.instance.catalog();
      if (!mounted || !_ownsAccount) return;
      setState(() {
        _categoriesV3 = (data['categories'] as List? ?? [])
            .map((r) => RideCategory(Map<String, dynamic>.from(r)))
            .toList();
        _promiseOptionsV3 = (data['promises'] as List? ?? [])
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
      });
    } catch (_) {
      /* The existing service flow remains available on legacy deployments. */
    }
  }

  Future<void> _selectCategoryV3(RideCategory category) async {
    if (creating || locked || _switchingServiceV36 || !_ownsAccount) return;
    if (category.id == 'veto_ladies') {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(category.name(context)),
          content: Text(
            categoryCopy(
              context,
              'الخدمة للسيدات البالغات، ويمكن اصطحاب أطفال أقل من 12 سنة. لا تشمل نقل طفل بدون مرافقة.',
              'For adult women; children under 12 may accompany them. No unaccompanied child transport.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(categoryCopy(context, 'رجوع', 'Back')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(categoryCopy(context, 'موافقة', 'Agree')),
            ),
          ],
        ),
      );
      if (accepted != true || !_ownsAccount) return;
    }
    final rev = _routeRevisionV36;
    final generation = ++_serviceSwitchGeneration;
    setState(() => _switchingServiceV36 = true);
    try {
      final quote = await ZonePricingService.instance.quote(
        service: category.service,
        categoryId: category.id,
        fromLat: b.pickupLat!,
        fromLng: b.pickupLng!,
        toLat: b.destLat!,
        toLng: b.destLng!,
      );
      if (!_ownsAccount ||
          rev != _routeRevisionV36 ||
          generation != _serviceSwitchGeneration)
        return;
      await _readGrowthPreview(quote);
      if (!_ownsAccount ||
          rev != _routeRevisionV36 ||
          generation != _serviceSwitchGeneration)
        return;
      setState(() {
        _categoryV3 = category.id;
        _timeoutRetrySource =
            null; // Choosing a different category is a new request.
        b.service = category.legacyService;
        b.pricingQuote = quote;
        _quotesV36[category.id] = quote;
        b.fare = _toDouble(quote['base_fare']);
        b.distance = _toDouble(quote['distance_km']);
        b.duration = _toDouble(quote['duration_minutes']);
        b.incentive = 0;
        b.wallet = 0;
        b.cash = 0;
        promoCode = null;
        promoDiscount = 0;
        _useEarnedDiscount = true;
        if (category.service != 'car_ride') _promisesV3.clear();
      });
      unawaited(_saveBookingDraft());
    } catch (_) {
      if (_ownsAccount)
        _show(
          categoryCopy(
            context,
            'الفئة دي مش متاحة دلوقتي. حاول تاني.',
            'This category is unavailable. Try again.',
          ),
        );
    } finally {
      if (_ownsAccount && generation == _serviceSwitchGeneration)
        setState(() => _switchingServiceV36 = false);
    }
  }

  final Map<String, num> _estimatesV3 = {};
  final Map<String, bool> _availabilityV3 = {};
  final Set<String> _childSeatsV3 = {};
  Future<void> _openCategoriesV3() async {
    final quoteId = b.pricingQuote?['id'];
    if (quoteId != null) {
      try {
        final estimates = await SupabaseService.instance.client.rpc(
          'v3_category_estimates',
          params: {'p_quote': quoteId},
        );
        if (!_ownsAccount) return;
        _estimatesV3.clear();
        for (final item in (estimates as List)) {
          if (item is Map && item['estimated_fare'] is num) {
            _estimatesV3['${item['id']}'] = item['estimated_fare'];
            _availabilityV3['${item['id']}'] = item['available'] == true;
            if (item['child_seat_available'] == true)
              _childSeatsV3.add('${item['id']}');
            else
              _childSeatsV3.remove('${item['id']}');
          }
        }
      } catch (_) {
        if (_ownsAccount)
          _show(
            categoryCopy(
              context,
              'تعذر تحديث أسعار الفئات. اختار فئة لإعادة حساب السعر.',
              'Could not refresh category estimates. Choose a category to calculate its fare.',
            ),
          );
      }
    }
    if (!_ownsAccount) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, refresh) => SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .82,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        categoryCopy(
                          context,
                          'اختار المشوار اللي يناسبك',
                          'Choose your ride',
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheet),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final category in _categoriesV3.where(
                      (c) => c.id != 'veto_market',
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RideCategoryCard(
                          category: category,
                          selected:
                              b.pricingQuote?['pricing_snapshot']?['ride_category_id_v3'] ==
                              category.id,
                          status: category.enabled
                              ? category.id == 'veto_ladies' &&
                                        _availabilityV3[category.id] == false
                                    ? categoryCopy(
                                        context,
                                        'مفيش سائقة متاحة دلوقتي. تقدري تحاولي بعد شوية.',
                                        'No approved woman driver is available right now. Please try again later.',
                                      )
                                    : category.description(context)
                              : categoryCopy(
                                  context,
                                  'الفئة دي مش متاحة دلوقتي.',
                                  'Currently unavailable.',
                                ),
                          fare:
                              _estimatesV3[category.id] ??
                              _quotesV36[category.id]?['base_fare'] as num?,
                          loading:
                              _switchingServiceV36 &&
                              _effectiveCategoryV3 == category.id,
                          onTap: !category.enabled || _switchingServiceV36
                              ? null
                              : () async {
                                  refresh(() {});
                                  final pending = _selectCategoryV3(category);
                                  refresh(() {});
                                  await pending;
                                  if (sheet.mounted) refresh(() {});
                                },
                        ),
                      ),
                    if (b.service == 'car') ...[
                      Text(
                        categoryCopy(
                          context,
                          'وعد المشوار — مشوارك على مزاجك',
                          'Trip Promise — your ride, your way',
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        categoryCopy(
                          context,
                          'التفضيلات حسب تأكيد الكابتن، بدون زيادة تلقائية.',
                          'Preferences depend on captain confirmation, with no automatic surcharge.',
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final option in _promiseOptionsV3.where(
                            (p) =>
                                p['enabled'] == true &&
                                (p['equipment_required'] != true ||
                                    _childSeatsV3.contains(
                                      _effectiveCategoryV3,
                                    )),
                          ))
                            FilterChip(
                              label: Text(
                                '${option[categoryArabic(context) ? 'name_ar' : 'name_en']}',
                              ),
                              selected: _promisesV3.contains(option['id']),
                              onSelected: (v) {
                                setState(
                                  () => v
                                      ? _promisesV3.add('${option['id']}')
                                      : _promisesV3.remove(option['id']),
                                );
                                refresh(() {});
                                unawaited(_saveBookingDraft());
                              },
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _switchingServiceV36
                        ? null
                        : () => Navigator.pop(sheet),
                    child: Text(
                      categoryCopy(context, 'راجع مشوارك', 'Review your ride'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categorySummaryV3() {
    final id = b.pricingQuote?['pricing_snapshot']?['ride_category_id_v3'];
    final category = _categoriesV3.where((c) => c.id == id).firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListTile(
        dense: true,
        leading: category == null
            ? const Icon(Icons.directions_car)
            : Image.asset(
                category.asset,
                width: 58,
                height: 44,
                fit: BoxFit.contain,
                cacheWidth: 160,
              ),
        title: Text(
          category?.name(context) ??
              categoryCopy(
                context,
                'اختار المشوار اللي يناسبك',
                'Choose your ride',
              ),
        ),
        subtitle: _promisesV3.isEmpty
            ? null
            : Text(
                _promiseOptionsV3
                    .where((p) => _promisesV3.contains(p['id']))
                    .map(
                      (p) =>
                          '${p[categoryArabic(context) ? 'name_ar' : 'name_en']}',
                    )
                    .join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: _switchingServiceV36
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.expand_more),
        onTap: _switchingServiceV36 || creating ? null : _openCategoriesV3,
      ),
    );
  }

  bool _findingLocationV36 = false;
  bool _switchingServiceV36 = false;
  int _serviceSwitchGeneration = 0;
  int _routeRevisionV36 = 0;
  final Map<String, Map<String, dynamic>> _quotesV36 = {};
  double _growthDiscount = 0;
  bool _useEarnedDiscount = true;
  bool _growthQuoteReady = true;
  bool _growthBookingUi = false;
  bool _growthServiceChosen = false;
  bool _comparingServicePrices = false;
  bool _retryingDestinationQuote = false;
  Future<void> Function()? _retryDestinationQuote;
  Future<void> _loadGrowthPresentation() async {
    try {
      final flags = await GrowthService().flags();
      if (mounted && _ownsAccount)
        setState(() => _growthBookingUi = flags['booking_ui'] == true);
    } catch (_) {
      if (mounted && _ownsAccount)
        _show(context.strings.bookingFinalCopy1b070dab);
    }
  }

  Future<void> _readGrowthPreview(Map<String, dynamic> quote) async {
    final revision = _routeRevisionV36;
    final selectedService = b.service;
    _growthDiscount = 0;
    _growthQuoteReady = !GrowthService.buildEnabled;
    if (!GrowthService.buildEnabled) return;
    final result = await GrowthService().call('growth_quote_preview_v2', {
      'p_quote': quote['id'],
    });
    if (!mounted ||
        !_ownsAccount ||
        revision != _routeRevisionV36 ||
        b.service != selectedService)
      return;
    _growthDiscount = _toDouble(result['discount']);
    _growthQuoteReady = true;
  }

  late final AnimationController sheet;
  late final Animation<Offset> slide;

  String? customerId;
  String? promoCode;
  String? error;

  double walletBalance = 0;
  double promoDiscount = 0;
  int _promoValidationGeneration = 0;
  String previousDueReason = '';

  bool creating = false;
  bool locked = false;
  bool navigating = false;
  bool _restoringDraft = false;
  bool _firstTripGuideOpen = false;

  DateTime? searchStarted;
  String? _timeoutRetrySource;

  TripRealtimeLease? tripSub;
  String? _subscribedTripV10;
  bool _checkingTripStatus = false;
  bool _openingAfterSearch = false;
  final _acceptedNavigation = AcceptedTripNavigationCoordinator();
  bool _cancellingSearch = false;
  Timer? _searchRecoveryTimerV37;
  Map<String, dynamic>? _searchAmountsV37;

  void _mergeSearchAmountsV37(Map<String, dynamic> trip) {
    // Display values returned by the financial server. No client-side fare math.
    if (!mounted || !_ownsAccount || step != BookingStep.searching) return;
    if (b.tripId != trip['id']?.toString() && trip['id'] != null) return;
    setState(
      () => _searchAmountsV37 = {
        if (_searchAmountsV37 != null) ..._searchAmountsV37!,
        ...trip,
      },
    );
  }

  Widget _searchPriceCardV37() {
    final amounts = _searchAmountsV37;
    final actualTotal = amounts?['total_fare'];
    final cashAmount = amounts?['cash_amount'];
    final walletAmount = amounts?['wallet_amount'];
    final incentive = amounts?['incentive_amount'];
    String money(Object? value) {
      final number = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
      return number == null
          ? '—'
          : context.strings.moneyValue(number.toStringAsFixed(2));
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(7, 4, 7, 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                color: AppTheme.gold,
                size: 19,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.strings.bookingFinalCopy372b98ca,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                money(actualTotal),
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (amounts != null) ...[
            if (incentive != null &&
                (num.tryParse(incentive.toString()) ?? 0) > 0)
              _searchAmountRowV37(
                context.strings.bookingFinalCopybeed4dc9,
                money(incentive),
              ),
            if (walletAmount != null)
              _searchAmountRowV37(
                context.strings.bookingFinalCopy48c3380c,
                money(walletAmount),
              ),
            if (cashAmount != null)
              _searchAmountRowV37(
                context.strings.bookingFinalCopy2e243e7f,
                money(cashAmount),
              ),
          ] else
            Text(
              context.strings.bookingFinalCopy955b4b7b,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchAmountRowV37(String title, String value) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Timer? _priceSuggestionTimer;
  bool _restoringSearch = false;
  Map<String, dynamic>? _priceSuggestion;
  bool _decidingPrice = false;
  DateTime? _nextPriceCheck;

  final List<Map<String, dynamic>> offers = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _bookingAccountId = SupabaseService.instance.currentUser?.id;
    _bookingAuthSubscription = SupabaseService
        .instance
        .client
        .auth
        .onAuthStateChange
        .listen((event) {
          if (!mounted || event.session?.user.id == _bookingAccountId) return;
          _bookingAccountInvalidated = true;
          _priceSuggestionTimer?.cancel();
          _searchRecoveryTimerV37?.cancel();
          tripSub?.unsubscribe();
          _routeRevisionV36++;
          setState(() {
            navigating = true;
            locked = true;
            creating = false;
            customerId = null;
            promoCode = null;
            promoDiscount = 0;
            walletBalance = 0;
            previousDueReason = '';
            _seedDestination = null;
            _searchAmountsV37 = null;
            _priceSuggestion = null;
            _quotesV36.clear();
            offers.clear();
            b.tripId = null;
            b.area = null;
            b.building = null;
            b.destination = null;
            b.destArea = null;
            b.destBuilding = null;
            b.pickupLat = null;
            b.pickupLng = null;
            b.destLat = null;
            b.destLng = null;
            b.fare = null;
            b.pricingQuote = null;
            b.route = null;
            b.customerNote = '';
            b.extraRequests = '';
            b.extraExpectedAmount = null;
            b.wallet = 0;
            b.cash = 0;
            b.incentive = 0;
          });
          context.go(AppRoutes.homeScreen);
        });
    _bookingAttempt =
        widget.initialAddresses?.attempt ?? BookingPerformanceAttempt();
    unawaited(GrowthService().observe('booking_started'));
    if (GrowthService.buildEnabled) {
      unawaited(_loadGrowthPresentation());
      unawaited(_loadCategoriesV3());
    }
    WidgetsBinding.instance.addObserver(this);
    // Home shortcut only changes the initial screen; pricing, matching and RPCs stay untouched.
    if (widget.retryTripId == null &&
        const {
          'car',
          'motorcycle',
          'package',
        }.contains(widget.initialService)) {
      b.service = widget.initialService;
      step = BookingStep.pickup;
    }

    if (_routeFirstV36) {
      b.service ??= 'car';
      _growthServiceChosen = widget.initialService != null;
      step = BookingStep.pickup;
    }

    sheet = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: sheet, curve: Curves.easeOutCubic));

    sheet.forward();

    _seedDestination = widget.initialAddresses?.destination;
    _loadCustomer().then((_) async {
      if (!mounted ||
          !_ownsAccount ||
          widget.resumeTripId != null ||
          widget.retryTripId != null ||
          b.tripId != null)
        return;
      final owner = SupabaseService.instance.currentUser?.id;
      if (owner != null) _draftStore = SecureDraftStore(owner);
      final pickup = widget.initialAddresses?.pickup;
      if (pickup == null &&
          widget.initialAddresses?.destination == null &&
          widget.initialService == null) {
        if (await _restoreBookingDraft()) return;
      }
      if (!mounted || !_ownsAccount) return;
      if (pickup == null && _routeFirstV36) {
        unawaited(_useCurrentLocationV36(auto: true));
      }
      if (pickup != null) {
        // Seed the pin, but allow the passenger to confirm it before moving on.
        setState(() {
          b.area = pickup.areaLetter ?? pickup.label;
          b.building = pickup.buildingNumber ?? '';
          b.pickupLat = pickup.latitude;
          b.pickupLng = pickup.longitude;
        });
      }
    });
  }

  Future<void> _saveBookingDraft() async {
    if (_draftStore == null || b.tripId != null || !_ownsAccount) return;
    final data = {
      'city': CustomerCityScopeV38.name,
      'service': b.service,
      'ride_category_id_v3': _categoryV3,
      'trip_promises_v3': _promisesV3.toList(),
      'pickup_label': b.area,
      'pickup_building': b.building,
      'pickup_lat': b.pickupLat,
      'pickup_lng': b.pickupLng,
      'destination': b.destination,
      'destination_lat': b.destLat,
      'destination_lng': b.destLng,
      'destination_area': b.destArea,
      'destination_building': b.destBuilding,
      'note': b.customerNote,
    };
    try {
      await _draftStore!.save(
        'ride_booking',
        data,
        lifetime: const Duration(hours: 24),
      );
    } catch (_) {
      /* Never block or retry a financial operation for a local draft. */
    }
  }

  Future<bool> _restoreBookingDraft() async {
    if (b.tripId != null ||
        widget.resumeTripId != null ||
        widget.retryTripId != null)
      return false;
    try {
      final data = await _draftStore?.load('ride_booking');
      if (data == null ||
          !mounted ||
          !_ownsAccount ||
          b.tripId != null ||
          data['city'] != CustomerCityScopeV38.name)
        return false;
      final seed = BookingAddressSeed.saved({
        'latitude': data['pickup_lat'],
        'longitude': data['pickup_lng'],
        'display_address': data['pickup_label'],
      });
      if (seed == null) return false;
      if (const ['car', 'motorcycle', 'package'].contains(data['service']))
        b.service = data['service'] as String;
      _restoreCategoryChoiceV3(data);
      b.customerNote = data['note'] is String
          ? (data['note'] as String).substring(
              0,
              (data['note'] as String).length.clamp(0, 500),
            )
          : '';
      final destination = BookingAddressSeed.saved({
        'latitude': data['destination_lat'],
        'longitude': data['destination_lng'],
        'display_address': data['destination'],
        'area_letter': data['destination_area'],
        'building_number': data['destination_building'],
      });
      _seedDestination = destination;
      _pickup(
        seed.label,
        data['pickup_building']?.toString() ?? '',
        lat: seed.latitude,
        lng: seed.longitude,
      );
      // _destination requests a new trusted quote. No price, discount, wallet,
      // financial request ID or active trip is restored from local storage.
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final id = b.tripId;
      if (id != null && id.isNotEmpty && step == BookingStep.searching) {
        _subscribe(id);
        _refreshTripStatus();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      unawaited(_saveBookingDraft());
    }
  }

  Future<void> _refreshTripStatus({bool manual = false}) async {
    final id = b.tripId;
    if (!mounted ||
        !_ownsAccount ||
        id == null ||
        id.isEmpty ||
        navigating ||
        _checkingTripStatus ||
        step != BookingStep.searching)
      return;
    _checkingTripStatus = true;
    try {
      final trip = await SupabaseService.instance
          .getTripById(id)
          .timeout(const Duration(seconds: 15));
      if (!mounted ||
          !_ownsAccount ||
          b.tripId != id ||
          navigating ||
          step != BookingStep.searching)
        return;
      if (trip == null) {
        if (manual) throw StateError('trip_status_unavailable');
        return;
      }
      _mergeSearchAmountsV37(Map<String, dynamic>.from(trip));
      final status = trip['trip_status']?.toString() ?? '';
      final captainId = trip['captain_id']?.toString();
      if (const {
            'accepted',
            'arriving',
            'arrived',
            'started',
          }.contains(status) &&
          captainId != null &&
          captainId.isNotEmpty) {
        await _openAfterSearch(id);
      } else if (status == 'cancelled') {
        if (trip['cancellation_reason']?.toString() == 'search_timeout_10m') {
          navigating = true;
          if (mounted) context.go(AppRoutes.homeScreen);
        } else {
          _show(context.strings.bookingRequestCancelled);
          _backToFare();
        }
      } else if (status == 'completed') {
        navigating = true;
        if (mounted) context.go('${AppRoutes.liveTrip}?tripId=$id');
      } else {
        await _checkPriceSuggestion(id);
        if (manual) _show(context.strings.bookingStillSearching);
      }
    } catch (failure) {
      debugPrint('Ride status read failed: ${failure.runtimeType}');
      if (manual && mounted && _ownsAccount) {
        _show(context.strings.bookingStatusUnavailable);
        rethrow;
      }
    } finally {
      _checkingTripStatus = false;
    }
  }

  // ===========================================================================
  // CUSTOMER
  // ===========================================================================

  Future<void> _showFirstTripGuideOnce(String userId) async {
    if (widget.retryTripId != null ||
        widget.resumeTripId != null ||
        _firstTripGuideOpen)
      return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOnline =
          SupabaseService
              .instance
              .currentUser
              ?.userMetadata?['veto_booking_guide_seen_v34'] ==
          true;
      if (!mounted || !_ownsAccount) return;
      if (prefs.getBool('veto_first_trip_guide_v18_$userId') == true ||
          savedOnline)
        return;
      // Optional inline guidance does not block address entry or wait for a tap.
      setState(() => _firstTripGuideOpen = true);
    } catch (_) {
      if (mounted && _ownsAccount) _show(context.strings.preferencesLoadFailed);
    }
  }

  Future<void> _dismissBookingGuide() async {
    setState(() => _firstTripGuideOpen = false);
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool('veto_first_trip_guide_v18_${user.id}', true))
        throw StateError('guide_not_saved');
      await SupabaseService.instance.client.auth.updateUser(
        UserAttributes(data: {'veto_booking_guide_seen_v34': true}),
      );
    } catch (_) {
      if (mounted && _ownsAccount) _show(context.strings.preferenceSaveFailed);
    }
  }

  Future<void> _loadCustomer() async {
    try {
      final user = SupabaseService.instance.currentUser;

      if (user == null) return;
      _showFirstTripGuideOnce(user.id);

      final customer = await SupabaseService.instance.getCustomerByUserId(
        user.id,
      );

      if (!mounted || !_ownsAccount || customer == null) return;

      final id = customer['id']?.toString();
      final reason = id == null
          ? context.strings.uif51ac3a9
          : await SupabaseService.instance.getCustomerDebtReason(id);

      if (!mounted || !_ownsAccount) return;

      setState(() {
        customerId = id;
        walletBalance = _toDouble(customer['wallet_balance']);
        promoCode = null;
        promoDiscount = 0;
        previousDueReason = reason;
      });
      if (widget.resumeTripId != null && id != null) {
        await _resumeExistingTrip(widget.resumeTripId!, id);
      } else if (widget.retryTripId != null) {
        await _restoreCancelledTrip(widget.retryTripId!, id);
      }
    } catch (_) {
      // لا نوقف شاشة الحجز بسبب فشل تحميل المحفظة.
    }
  }

  /// Reopen the same active request: never create a second trip or wallet hold.
  void _restoreCategoryChoiceV3(Map<String, dynamic> data) {
    _categoryV3 = restoredRideCategory(data['ride_category_id_v3']);
    _promisesV3
      ..clear()
      ..addAll(restoredTripPromises(data['trip_promises_v3']));
  }

  Future<void> _resumeExistingTrip(String requestedId, String ownerId) async {
    if (_restoringSearch) return;
    _restoringSearch = true;
    try {
      final trip = await SupabaseService.instance.getActiveTrip(ownerId);
      if (!mounted || !_ownsAccount) return;
      if (trip == null || trip['id']?.toString() != requestedId) {
        context.go(AppRoutes.homeScreen);
        return;
      }
      final status = trip['trip_status']?.toString() ?? '';
      if (const {
            'accepted',
            'arriving',
            'arrived',
            'started',
          }.contains(status) &&
          trip['captain_id'] != null) {
        context.go('${AppRoutes.liveTrip}?tripId=$requestedId');
        return;
      }
      if (!const {'requested', 'offer_received'}.contains(status)) {
        context.go(AppRoutes.homeScreen);
        return;
      }
      double? numValue(dynamic value) => value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
      final originalService = trip['service_type']?.toString() ?? '';
      _restoreCategoryChoiceV3(trip);
      setState(() {
        b.tripId = requestedId;
        b.service = switch (originalService) {
          'motorcycle_ride' => 'motorcycle',
          'package' || 'package_delivery' => 'package',
          'vito_market' => 'market',
          _ => 'car',
        };
        b.area = (trip['pickup_area_letter']?.toString().isNotEmpty ?? false)
            ? trip['pickup_area_letter'].toString()
            : trip['pickup_address']?.toString();
        b.building = trip['pickup_building_number']?.toString();
        b.destination = trip['destination_address']?.toString();
        b.destArea = trip['destination_area_letter']?.toString();
        b.destBuilding = trip['destination_building_number']?.toString();
        b.extraRequests = trip['extra_requests']?.toString() ?? '';
        b.pickupLat = numValue(trip['pickup_latitude']);
        b.pickupLng = numValue(trip['pickup_longitude']);
        b.destLat = numValue(trip['destination_latitude']);
        b.destLng = numValue(trip['destination_longitude']);
        b.distance = numValue(trip['distance_km']);
        b.duration = numValue(trip['duration_minutes']);
        b.fare = numValue(trip['total_fare']);
        b.incentive = (numValue(trip['incentive_amount']) ?? 0).round();
        locked = true;
        error = null;
        step = BookingStep.searching;
        unawaited(_draftStore?.clear('ride_booking') ?? Future<void>.value());
        searchStarted =
            DateTime.tryParse(
              trip['created_at']?.toString() ?? '',
            )?.toLocal() ??
            DateTime.now();
      });
      _mergeSearchAmountsV37(Map<String, dynamic>.from(trip));
      _subscribe(requestedId);
      _startSearchRecoveryV37();
      _refreshTripStatus();
    } catch (_) {
      if (mounted && _ownsAccount) context.go(AppRoutes.homeScreen);
    } finally {
      _restoringSearch = false;
    }
  }

  /// A new booking draft, not a retry of the old trip's INSERT/financials.
  Future<void> _restoreCancelledTrip(
    String originalId,
    String? customer,
  ) async {
    if (_restoringDraft || customer == null) return;
    _restoringDraft = true;
    try {
      final api = SupabaseService.instance;
      final trip = await api.client
          .from('trips')
          .select()
          .eq('id', originalId)
          .eq('customer_id', customer)
          .maybeSingle();
      if (trip == null ||
          !const {
            'cancelled',
            'completed',
          }.contains(trip['trip_status']?.toString())) {
        throw StateError('retry_not_available');
      }
      // Supabase validates the one-hour window; device time is not authoritative.
      final canTimeoutRetry =
          widget.timeoutRetry &&
          trip['trip_status']?.toString() == 'cancelled' &&
          trip['cancellation_reason']?.toString() == 'search_timeout_10m';
      _timeoutRetrySource = canTimeoutRetry ? originalId : null;
      final active = await api.getActiveTrip(customer);
      if (active != null) throw StateError('active_trip_exists');
      double? number(dynamic x) =>
          x is num ? x.toDouble() : double.tryParse(x?.toString() ?? '');
      final fromLat = number(trip['pickup_latitude']);
      final fromLng = number(trip['pickup_longitude']);
      final toLat = number(trip['destination_latitude']);
      final toLng = number(trip['destination_longitude']);
      if (fromLat == null ||
          fromLng == null ||
          toLat == null ||
          toLng == null) {
        throw StateError('missing_coordinates');
      }
      // Rebooking is a fresh quote, not a replay of the old trip. The server
      // quote already routes via OSRM; do not make a second OSRM request here.
      if (!mounted || !_ownsAccount) return;
      final originalService = trip['service_type']?.toString() ?? '';
      final service = switch (originalService) {
        'motorcycle_ride' => 'motorcycle',
        'package' => 'package',
        'vito_market' => 'market',
        _ => 'car',
      };
      final sourceArea = trip['pickup_area_letter']?.toString();
      _restoreCategoryChoiceV3(trip);
      final pickupRaw = trip['pickup_address']?.toString() ?? '';
      setState(() {
        b.service = service;
        b.area = sourceArea != null && sourceArea.isNotEmpty
            ? sourceArea
            : pickupRaw;
        b.building = trip['pickup_building_number']?.toString();
        b.pickupLat = fromLat;
        b.pickupLng = fromLng;
        b.destination = trip['destination_address']?.toString() ?? '';
        b.destArea = trip['destination_area_letter']?.toString();
        b.destBuilding = trip['destination_building_number']?.toString();
        b.destLat = toLat;
        b.destLng = toLng;
        // Reuse only service and route endpoints. Everything chargeable starts
        // fresh, with the current server quote and no historical incentives.
        b.distance = null;
        b.duration = null;
        b.route = null;
        b.outsideCity = false;
        b.weight = null;
        b.passengers = 1;
        b.incentive = 0;
        b.customerNote = '';
        b.extraRequests = '';
        b.extraExpectedAmount = null;
        b.pricingQuote = null;
        b.fare = null;
        b.tripId = null;
        b.wallet = 0;
        b.cash = 0;
        b.payment = 'cash';
        promoCode = null;
        promoDiscount = 0;
        step = BookingStep.fare;
        error = null;
      });
      // Show confirmation immediately, but keep payment disabled until the
      // current price is returned by the trusted server quote.
      sheet.forward();
      final newFare = await _fare(0, b.destArea, b.destBuilding);
      if (!mounted || !_ownsAccount) return;
      setState(() => b.fare = newFare);
    } catch (e) {
      if (!mounted || !_ownsAccount) return;
      setState(() {
        step = BookingStep.service;
        error = context.strings.bookingFinalCopy4a2fae95;
      });
    } finally {
      _restoringDraft = false;
    }
  }

  // ---------------------------------------------------------------------------
  // V36: pickup is the customer's actual GPS pin. A nearby verified building
  // is an ADDRESS LABEL only, never a replacement for the GPS coordinates.
  // ---------------------------------------------------------------------------
  Future<void> _useCurrentLocationV36({bool auto = false}) async {
    if (_findingLocationV36 || !mounted) return;
    _findingLocationV36 = true;
    try {
      final position = await CustomerLocationState.locate();
      if (position == null) {
        if (!auto && mounted) _show(CustomerLocationState.state.value.message);
        return;
      }
      if (!mounted ||
          !_ownsAccount ||
          step != BookingStep.pickup ||
          (auto && b.pickupLat != null))
        return;
      // Only verified server zone labels, never a guessed Hadayek address.
      if (!mounted || !_ownsAccount || step != BookingStep.pickup) return;
      var area = context.strings.selectedLocation;
      // Reverse naming is bounded and optional. The original zone/building
      // validation remains authoritative for coverage and pricing.
      final reverse = ProductGeocodingService()
          .reverse(
            position.latitude,
            position.longitude,
            language: Localizations.localeOf(context).languageCode,
          )
          .timeout(const Duration(seconds: 2))
          .then((v) => v, onError: (_) => null);
      var gpsWithinHadayekV38 = false;
      try {
        final zone = await ZonePricingService.instance
            .resolveCity(position.latitude, position.longitude)
            .timeout(const Duration(seconds: 3));
        if (zone != null && zone.active && !zone.global) {
          area = zone.name;
          gpsWithinHadayekV38 = CustomerCityScopeV38.isHadayekName(zone.name);
          CustomerCityScopeV38.resolved(zone.name);
        }
      } catch (_) {
        /* GPS pin remains accurate without a city label. */
      }
      if (!mounted || !_ownsAccount || step != BookingStep.pickup) return;
      var building = '';
      final candidate = await reverse;
      if (!mounted || !_ownsAccount || step != BookingStep.pickup) return;
      if (!gpsWithinHadayekV38 && candidate != null) {
        // The coordinates are exact; the provider name remains a suggested
        // description which the rider may replace through the map picker.
        area = candidate.address;
      }
      // The read-only RPC searches ONLY verified Hadayek buildings within
      // 220 meters. It returns null elsewhere; no zone lookup or fake pin.
      if (gpsWithinHadayekV38)
        try {
          final nearest = await SupabaseService.instance.client
              .rpc(
                'v36_nearest_verified_building',
                params: {
                  'p_lat': position.latitude,
                  'p_lng': position.longitude,
                  'p_radius_m': 220,
                },
              )
              .timeout(const Duration(seconds: 3));
          if (nearest is Map) {
            final found = Map<String, dynamic>.from(nearest);
            if (found['area_letter'] != null &&
                found['building_number'] != null) {
              area = found['area_letter'].toString();
              CustomerCityScopeV38.resolved('حدائق الأهرام');
              building = found['building_number'].toString();
            }
          }
        } catch (_) {
          /* Still offer the exact GPS pin without V36 SQL. */
        }
      if (!mounted || !_ownsAccount || step != BookingStep.pickup) return;
      if (auto) {
        // GPS prefill only. Let the customer notice and confirm the pickup;
        // do not silently advance to a visually similar destination page.
        setState(() {
          b.area = area;
          b.building = building;
          b.pickupLat = position.latitude;
          b.pickupLng = position.longitude;
        });
      } else {
        _pickup(
          area,
          building,
          lat: position.latitude,
          lng: position.longitude,
        );
      }
    } catch (_) {
      if (!auto && mounted) _show(context.strings.uiea5f73b8);
    } finally {
      _findingLocationV36 = false;
    }
  }

  Future<void> _loadOtherQuotesV36(int revision) async {
    if (!_canCompareRideFares || _comparingServicePrices) return;
    setState(() => _comparingServicePrices = true);
    try {
      for (final entry in const <String, String>{
        'car': 'car_ride',
        'motorcycle': 'motorcycle_ride',
        'package': 'package',
      }.entries) {
        if (entry.key == b.service) continue;
        final cached = _quotesV36[entry.key];
        final expiry = DateTime.tryParse(
          cached?['expires_at']?.toString() ?? '',
        );
        if (expiry != null &&
            expiry.isAfter(
              DateTime.now().toUtc().add(const Duration(seconds: 10)),
            ))
          continue;
        if (!mounted ||
            !_ownsAccount ||
            revision != _routeRevisionV36 ||
            b.pickupLat == null ||
            b.destLat == null)
          return;
        try {
          final quote = await ZonePricingService.instance.quote(
            service: entry.value,
            fromLat: b.pickupLat!,
            fromLng: b.pickupLng!,
            toLat: b.destLat!,
            toLng: b.destLng!,
          );
          if (!mounted || !_ownsAccount || revision != _routeRevisionV36)
            return;
          setState(() => _quotesV36[entry.key] = quote);
        } catch (_) {
          // No invented estimate. The user may tap to retry that price.
        }
      }
    } finally {
      if (mounted && _ownsAccount)
        setState(() => _comparingServicePrices = false);
    }
  }

  Future<void> _selectQuotedServiceV36(String id) async {
    if (!_canCompareRideFares ||
        _switchingServiceV36 ||
        creating ||
        locked ||
        navigating ||
        b.service == id)
      return;
    if (b.pickupLat == null || b.destLat == null) return;
    final generation = ++_serviceSwitchGeneration;
    final revision = _routeRevisionV36;
    final fromLat = b.pickupLat,
        fromLng = b.pickupLng,
        toLat = b.destLat,
        toLng = b.destLng;
    bool current() =>
        mounted &&
        _ownsAccount &&
        generation == _serviceSwitchGeneration &&
        revision == _routeRevisionV36 &&
        b.pickupLat == fromLat &&
        b.pickupLng == fromLng &&
        b.destLat == toLat &&
        b.destLng == toLng;
    setState(() => _switchingServiceV36 = true);
    try {
      var quote = _quotesV36[id];
      final expires = DateTime.tryParse(quote?['expires_at']?.toString() ?? '');
      if (quote == null ||
          expires == null ||
          expires.isBefore(
            DateTime.now().toUtc().add(const Duration(seconds: 10)),
          )) {
        final serverType = switch (id) {
          'motorcycle' => 'motorcycle_ride',
          'package' => 'package',
          _ => 'car_ride',
        };
        quote = await ZonePricingService.instance.quote(
          service: serverType,
          fromLat: b.pickupLat!,
          fromLng: b.pickupLng!,
          toLat: b.destLat!,
          toLng: b.destLng!,
        );
      }
      if (!mounted || !_ownsAccount) return;
      if (!current()) return;
      final selectedQuote = quote;
      final price = _toDouble(selectedQuote['base_fare']);
      if (price <= 0) throw StateError('invalid_quote');
      await _readGrowthPreview(selectedQuote);
      if (!current()) return;
      unawaited(
        GrowthService().observe('fare_viewed', properties: {'service': id}),
      );
      if (!mounted || !_ownsAccount) return;
      setState(() {
        _quotesV36[id] = selectedQuote;
        b.service = id;
        _categoryV3 = null;
        _promisesV3.clear();
        _timeoutRetrySource = null;
        b.pricingQuote = selectedQuote;
        b.fare = price;
        b.distance = _toDouble(selectedQuote['distance_km']);
        b.duration = _toDouble(selectedQuote['duration_minutes']);
        b.incentive = 0;
        b.wallet = 0;
        b.cash = 0;
        promoCode = null;
        promoDiscount = 0;
        _useEarnedDiscount = true;
      });
    } catch (_) {
      if (mounted && _ownsAccount)
        _show(context.strings.bookingFinalCopy37a5d6fa);
    } finally {
      if (current()) setState(() => _switchingServiceV36 = false);
    }
  }

  Widget _servicesV36() => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(21)),
    ),
    padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'اختار خدمتك',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: context.strings.compareServicePrices,
              onPressed: _comparingServicePrices
                  ? null
                  : () => unawaited(_loadOtherQuotesV36(_routeRevisionV36)),
              icon: const Icon(Icons.compare_arrows_rounded),
            ),
          ],
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 68,
          child: Row(
            children: [
              for (final service in <(String, String, IconData)>[
                (
                  'car',
                  context.strings.bookingFinalCopy89aef3a3,
                  Icons.directions_car_filled_rounded,
                ),
                (
                  'motorcycle',
                  context.strings.bookingFinalCopy80a51d6a,
                  Icons.two_wheeler_rounded,
                ),
                (
                  'package',
                  context.strings.bookingFinalCopy113cb058,
                  Icons.inventory_2_rounded,
                ),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () =>
                          unawaited(_selectQuotedServiceV36(service.$1)),
                      child: Container(
                        decoration: BoxDecoration(
                          color: b.service == service.$1
                              ? AppTheme.gold.withAlpha(40)
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          border: Border.all(
                            color: b.service == service.$1
                                ? AppTheme.gold
                                : Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(service.$3, size: 18, color: AppTheme.gold),
                            Text(
                              service.$2,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _quotesV36[service.$1] == null
                                  ? (_comparingServicePrices
                                        ? 'جاري التسعير…'
                                        : 'اعرض السعر')
                                  : context.strings.moneyValue(
                                      _toDouble(
                                        _quotesV36[service.$1]!['base_fare'],
                                      ).toStringAsFixed(2),
                                    ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.gold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_switchingServiceV36) const LinearProgressIndicator(minHeight: 2),
      ],
    ),
  );

  // ===========================================================================
  // SERVICE
  // ===========================================================================

  String? get serviceLabel {
    switch (b.service) {
      case 'motorcycle':
        return context.strings.motorcycle;
      case 'package':
        return context.strings.delivery;
      case 'market':
        return context.strings.market;
      case 'car':
        return context.strings.car;
      default:
        return null;
    }
  }

  String get serviceType {
    switch (b.service) {
      case 'motorcycle':
        return 'motorcycle_ride';

      case 'package':
        return 'package';

      case 'market':
        return 'vito_market';

      case 'car':
      default:
        return 'car_ride';
    }
  }

  void _service(String value) {
    if (value.trim().isEmpty) return;

    setState(() {
      b.service = value;
      _categoryV3 = null;
      _promisesV3.clear();
      _timeoutRetrySource = null;
    });

    _next(BookingStep.pickup);
  }

  // ===========================================================================
  // NAVIGATION BETWEEN BOOKING STEPS
  // ===========================================================================

  void _next(BookingStep nextStep) {
    if (!mounted || !_ownsAccount) return;
    setState(() {
      step = nextStep;
    });
    unawaited(_saveBookingDraft());
    final event = switch (nextStep) {
      BookingStep.destination => 'pickup_selected',
      BookingStep.fare => 'destination_selected',
      _ => null,
    };
    if (event != null) unawaited(GrowthService().observe(event));

    if (MediaQuery.disableAnimationsOf(context)) {
      sheet.value = 1;
    } else {
      sheet.forward(from: 0);
    }
  }

  BookingStep? _previous() {
    switch (step) {
      case BookingStep.pickup:
        return _routeFirstV36 ? null : BookingStep.service;

      case BookingStep.destination:
        return BookingStep.pickup;

      case BookingStep.fare:
        return BookingStep.destination;

      default:
        return null;
    }
  }

  void _back() {
    if (step == BookingStep.searching) {
      context.go(AppRoutes.homeScreen);
      return;
    }

    final previous = _previous();

    if (previous == null) {
      context.pop();
      return;
    }

    _next(previous);
  }

  // ===========================================================================
  // PICKUP
  // ===========================================================================

  void _pickup(String area, String building, {double? lat, double? lng}) {
    _bookingAttempt.mark(BookingMilestone.pickupSelected);
    ++_routeRevisionV36;
    _timeoutRetrySource = null; // Edited route is a normal new request.
    _retryDestinationQuote = null;
    _serviceSwitchGeneration++;
    _switchingServiceV36 = false;
    setState(() {
      b.area = area;
      b.building = building;

      b.pickupLat = lat;
      b.pickupLng = lng;
    });

    _next(BookingStep.destination);
    final seeded = _seedDestination;
    if (seeded != null) {
      _seedDestination = null;
      unawaited(
        _destination(
          seeded.label,
          0,
          0,
          lat: seeded.latitude,
          lng: seeded.longitude,
          areaLetter: seeded.areaLetter,
          buildingNumber: seeded.buildingNumber,
          outsideCity: seeded.outsideCity,
        ),
      );
    }
  }

  String get pickupLabel {
    final area = b.area?.trim() ?? '';
    final building = b.building?.trim() ?? '';

    if (area.isEmpty && building.isEmpty) {
      return context.strings.ui4e3d1712;
    }

    const letters = <String>{
      'أ',
      'ب',
      'ج',
      'د',
      'هـ',
      'و',
      'ز',
      'ح',
      'ط',
      'ك',
      'ل',
      'م',
      'ن',
      'ع',
      'س',
      'ص',
    };
    if (!letters.contains(area)) return area;
    if (building.isEmpty) return 'منطقة $area';
    return 'منطقة $area - عمارة $building';
  }

  // ===========================================================================
  // DESTINATION
  // ===========================================================================

  Future<void> _destination(
    String label,
    double distance,
    double duration, {
    double? lat,
    double? lng,
    String? areaLetter,
    String? buildingNumber,
    double? fare,
    List<List<double>>? routePoints,
    bool outsideCity = false,
  }) async {
    if (label.trim().isEmpty) {
      _show(context.strings.ui396197d7);
      return;
    }
    _bookingAttempt.mark(BookingMilestone.destinationSelected);

    _timeoutRetrySource = null; // Only an unchanged previous route qualifies.
    final revision = ++_routeRevisionV36;
    _serviceSwitchGeneration++;
    _switchingServiceV36 = false;
    _quotesV36.clear();
    b.destLat = lat;
    b.destLng = lng;
    b.pricingQuote = null;
    b.destination = label;
    b.destArea = areaLetter;
    b.destBuilding = buildingNumber;
    b.outsideCity = outsideCity;
    _retryDestinationQuote = () => _destination(
      label,
      distance,
      duration,
      lat: lat,
      lng: lng,
      areaLetter: areaLetter,
      buildingNumber: buildingNumber,
      fare: fare,
      routePoints: routePoints,
      outsideCity: outsideCity,
    );
    setState(() {
      b.fare = null;
      b.distance = null;
      b.duration = null;
      error = null;
    });
    double calculatedFare;
    try {
      calculatedFare = await _fare(distance, areaLetter, buildingNumber);
    } catch (failure) {
      if (mounted &&
          _ownsAccount &&
          revision == _routeRevisionV36 &&
          !failure.toString().contains('stale_quote_ignored')) {
        setState(() => error = localizedQuoteFailure(context, failure));
      }
      return;
    }

    if (!mounted || !_ownsAccount || revision != _routeRevisionV36) return;

    setState(() {
      b.destination = label;

      b.distance = _toDouble(b.pricingQuote?['distance_km']);
      b.duration = _toDouble(b.pricingQuote?['duration_minutes']);

      b.fare = calculatedFare;
      error = null;
      _retryDestinationQuote = null;
      _growthServiceChosen =
          widget.initialAddresses?.destination != null ||
          widget.initialService != null;
      promoCode = null;
      promoDiscount = 0;

      b.destLat = lat;
      b.destLng = lng;

      b.destArea = areaLetter;
      b.destBuilding = buildingNumber;

      b.route = routePoints;
      _routePreviewUnavailable = false;
      b.outsideCity = outsideCity;

      // Reset payment details because the trip
      // details have changed.
      b.wallet = 0;
      b.cash = 0;
    });

    if (_canCompareRideFares && b.pricingQuote != null) {
      _quotesV36[b.service ?? 'car'] = b.pricingQuote!;
    }
    _useEarnedDiscount = true;
    _next(BookingStep.fare);
    // Fetch each alternative only once for the selected route. Missing quotes
    // remain unavailable rather than inventing a fare. Manual refresh remains.
    // Comparison quotes are requested by the passenger, not on every route edit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _ownsAccount && step == BookingStep.fare) {
        _bookingAttempt.mark(BookingMilestone.priceVisible);
      }
    });
    if (routePoints == null &&
        lat != null &&
        lng != null &&
        b.pickupLat != null &&
        b.pickupLng != null) {
      unawaited(
        _loadRoutePreview(
          _routeRevisionV36,
          b.pickupLat!,
          b.pickupLng!,
          lat,
          lng,
        ),
      );
    }
  }

  Future<void> _loadRoutePreview(
    int revision,
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) async {
    List<List<double>>? points;
    if (GrowthService.buildEnabled) {
      try {
        points = (await ProductGeocodingService().route(
          fromLat,
          fromLng,
          toLat,
          toLng,
          language: Localizations.localeOf(context).languageCode,
        )).points;
      } catch (_) {
        /* Optional preview; the financial quote already succeeded. */
      }
    }
    if (points == null) {
      try {
        points =
            (await RoutingService.instance
                    .getRouteWithGeometry(
                      fromLat: fromLat,
                      fromLng: fromLng,
                      toLat: toLat,
                      toLng: toLng,
                    )
                    .timeout(const Duration(seconds: 5)))
                ?.routePoints;
      } catch (_) {
        /* Surface preview unavailability below; never change fare. */
      }
    }
    if (!mounted ||
        !_ownsAccount ||
        revision != _routeRevisionV36 ||
        b.destLat != toLat ||
        b.destLng != toLng)
      return;
    setState(() {
      b.route = points;
      _routePreviewUnavailable = points == null || points.isEmpty;
    });
  }

  // ===========================================================================
  // FARE
  // ===========================================================================

  Future<double> _fare(
    double km,
    String? destinationArea,
    String? destinationBuilding,
  ) async {
    if (b.pickupLat == null ||
        b.pickupLng == null ||
        b.destLat == null ||
        b.destLng == null)
      throw StateError('booking_coordinates_required');
    final revision = _routeRevisionV36;
    final selectedService = serviceType;
    final fromLat = b.pickupLat!,
        fromLng = b.pickupLng!,
        toLat = b.destLat!,
        toLng = b.destLng!;
    bool current() =>
        mounted &&
        _ownsAccount &&
        revision == _routeRevisionV36 &&
        serviceType == selectedService &&
        b.pickupLat == fromLat &&
        b.pickupLng == fromLng &&
        b.destLat == toLat &&
        b.destLng == toLng;
    final quote = await ZonePricingService.instance.quote(
      service: serviceType,
      fromLat: b.pickupLat!,
      fromLng: b.pickupLng!,
      toLat: b.destLat!,
      toLng: b.destLng!,
      timeoutRetryTripId: _timeoutRetrySource,
      categoryId: _timeoutRetrySource == null
          ? _effectiveCategoryV3
          : _categoryV3,
    );
    if (!current()) throw StateError('stale_quote_ignored');
    b.pricingQuote = quote;
    final categoryId = quote['pricing_snapshot']?['ride_category_id_v3'];
    if (categoryId is String) {
      _categoryV3 = categoryId;
      _quotesV36[categoryId] = quote;
    }
    await _readGrowthPreview(quote);
    if (!current() || b.pricingQuote?['id'] != quote['id'])
      throw StateError('stale_quote_ignored');
    b.distance = _toDouble(quote['distance_km']);
    b.duration = _toDouble(quote['duration_minutes']);
    return _toDouble(quote['base_fare']);
  }

  Future<void> _retrySelectedDestinationQuote() async {
    final retry = _retryDestinationQuote;
    if (retry == null || _retryingDestinationQuote || !_ownsAccount) return;
    setState(() => _retryingDestinationQuote = true);
    try {
      await retry();
    } finally {
      if (mounted && _ownsAccount)
        setState(() => _retryingDestinationQuote = false);
    }
  }

  // ===========================================================================
  // CONFIRM TRIP
  // ===========================================================================

  Future<void> _confirm() async {
    if (!_ownsAccount) return;
    if (locked || creating || _switchingServiceV36 || customerId == null) {
      return;
    }

    final expiry = DateTime.tryParse('${b.pricingQuote?['expires_at']}');
    if (b.pricingQuote == null ||
        expiry == null ||
        expiry.isBefore(
          DateTime.now().toUtc().add(const Duration(seconds: 10)),
        )) {
      try {
        final nextFare = await _fare(
          b.distance ?? 0,
          b.destArea,
          b.destBuilding,
        );
        if (!mounted || !_ownsAccount) return;
        setState(() {
          b.fare = nextFare;
          promoCode = null;
          promoDiscount = 0;
        });
        _show(context.strings.bookingFinalCopyde62259f);
      } catch (_) {
        if (mounted && _ownsAccount)
          _show(context.strings.bookingFinalCopy9d4632b1);
      }
      return;
    }
    if (b.extraExpectedAmount != null &&
        (b.extraExpectedAmount! > 500 ||
            b.extraExpectedAmount! < 0 ||
            !b.extraExpectedAmount!.isFinite)) {
      _show(context.strings.bookingFinalCopyb60ed4c8);
      return;
    }

    if (b.fare == null || b.fare! <= 0) {
      _show(context.strings.uic32397f1);
      return;
    }

    if (b.pickupLat == null || b.pickupLng == null) {
      _show(context.strings.ui44a70a8d);
      return;
    }

    if (b.destLat == null || b.destLng == null) {
      _show(context.strings.ui2c00f52f);
      return;
    }

    /*
     * لا نسمح بإنشاء رحلتين نشطتين
     * لنفس العميل.
     */
    try {
      final existing = await SupabaseService.instance.getActiveTrip(
        customerId!,
      );

      if (!_ownsAccount) return;

      if (existing != null) {
        _show(context.strings.ui2beacbfd);
        return;
      }
    } catch (_) {
      if (_ownsAccount) _show(context.strings.ui70e7a8c0);
      return;
    }

    setState(() {
      locked = true;
      creating = true;
      error = null;

      offers.clear();

      navigating = false;

      searchStarted = DateTime.now();
    });

    final measurement = _bookingAttempt.confirm();
    try {
      String? deliveryPin;

      if (b.service == 'package') {
        deliveryPin = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000))
            .toString();
      }

      // العرض المحلي مطابق للمنطق المالي في DB: أجرة الرحلة + الحافز + المستحق السابق - الخصم.
      // القيم النهائية للمحفظة/الكاش/العمولة والتسوية لا يقررها Flutter.
      final baseFare = b.fare ?? 0;
      final previousDue = walletBalance < 0 ? -walletBalance : 0.0;
      final previewTotal = _positive(
        baseFare +
            b.incentive +
            previousDue -
            (promoCode == null && _useEarnedDiscount
                ? _growthDiscount
                : promoDiscount),
      );
      final payment = _calculatePaymentAmounts(
        method: b.payment,
        total: previewTotal,
        walletBalance: walletBalance,
      );

      b.wallet = payment.walletAmount;
      b.cash = payment.cashAmount;

      final trip = await SupabaseService.instance.createTrip(
        customerId: customerId!,
        serviceType: serviceType,
        categoryId:
            b.pricingQuote?['pricing_snapshot']?['ride_category_id_v3']
                as String?,
        tripPromises: _promisesV3.toList(),
        ladiesTermsAccepted: _categoryV3 == 'veto_ladies',

        pickupAddress: pickupLabel,

        destinationAddress: b.destination ?? '',

        pickupLat: b.pickupLat,

        pickupLng: b.pickupLng,

        destLat: b.destLat,

        destLng: b.destLng,

        pickupAreaLetter:
            const <String>{
              'أ',
              'ب',
              'ج',
              'د',
              'هـ',
              'و',
              'ز',
              'ح',
              'ط',
              'ك',
              'ل',
              'م',
              'ن',
              'ع',
              'س',
              'ص',
            }.contains(b.area)
            ? b.area
            : null,

        pickupBuildingNumber: b.building,

        destAreaLetter: b.destArea,

        destBuildingNumber: b.destBuilding,

        distanceKm: b.distance,

        durationMinutes: b.duration?.round(),

        baseFare: baseFare,

        incentiveAmount: b.incentive.toDouble(),

        totalFare: null,

        paymentMethod: payment.method,

        packageWeightKg: b.weight,

        deliveryPin: deliveryPin,

        promoCode: promoCode,

        promoDiscount: promoDiscount,
        expectedGrowthDiscount: promoCode == null && _useEarnedDiscount
            ? _growthDiscount
            : 0,
        skipEarnedGrowthDiscount:
            !_useEarnedDiscount && promoCode == null && _growthDiscount > 0,

        customerNote: b.customerNote,
        extraRequests: b.extraRequests,
        extraExpectedAmount: b.extraExpectedAmount,
        pricingQuoteId: b.pricingQuote?['id']?.toString(),

        customerPreviousDue: previousDue,

        isOutsideCity: b.outsideCity,
      );

      if (!_ownsAccount) return;
      final id = trip['id']?.toString();

      if (id == null || id.isEmpty) {
        throw Exception('trip_id_missing');
      }
      // End booking time at server acknowledgement, before dispatch or captain
      // acceptance. Never let analytics delay a trip or alter its settlement.
      unawaited(measurement.deliver('created', tripId: id));

      // Supabase is the financial source of truth. The preview above is only
      // for the customer review screen; after creation we keep the exact
      // wallet/cash split returned by the server to avoid stale or double
      // calculations when the wallet changed just before confirmation.
      b.wallet = _toDouble(trip['wallet_amount']);
      b.cash = _toDouble(trip['cash_amount']);
      final returnedPaymentMethod = trip['payment_method']?.toString();
      if (const {
        'cash',
        'wallet',
        'combined',
      }.contains(returnedPaymentMethod)) {
        b.payment = returnedPaymentMethod!;
      }
      promoDiscount = _toDouble(trip['promo_discount']);
      if (trip.containsKey('wallet_balance_after')) {
        walletBalance = _toDouble(trip['wallet_balance_after']);
      }

      if (!mounted || !_ownsAccount) return;

      /*
       * ندخل شاشة البحث أولًا.
       *
       * حتى لو الكابتن قبل فورًا،
       * لا نقفز مباشرة قبل ظهور الرادار.
       */
      setState(() {
        b.tripId = id;
        _priceSuggestion = null;
        _nextPriceCheck = null;

        step = BookingStep.searching;
        unawaited(_draftStore?.clear('ride_booking') ?? Future<void>.value());

        searchStarted ??= DateTime.now();

        creating = false;
      });

      sheet.forward();

      /*
       * الاشتراك قبل تشغيل matching
       * حتى لا نفقد تحديث accepted.
       */
      _subscribe(id);
      _mergeSearchAmountsV37(Map<String, dynamic>.from(trip));
      _startSearchRecoveryV37();

      /*
       * مزامنة السعر النهائي مع Supabase
       * إذا كانت الدالة موجودة.
       */
      // Quote snapshot is committed atomically with this trip.

      /*
       * إنشاء عروض الكباتن المؤهلين.
       *
       * المطابقة نفسها يجب أن تتم في RPC:
       * - active
       * - online
       * - available
       * - نوع المركبة مناسب
       * - ليس في رحلة نشطة
       * - الدين تحت الحد المسموح
       */
      await SupabaseService.instance.createTripOffersViaRpc(id);
      // A fast acceptance can arrive before Realtime finishes subscribing.
      await _refreshTripStatus();

      if (mounted && _ownsAccount) {
        setState(() {
          locked = false;
        });
      }
    } catch (exception) {
      debugPrint(
        'Booking request failed: ${exception.runtimeType}'
        '${exception is PostgrestException ? " (${exception.code})" : ""}',
      );
      unawaited(
        measurement.deliver(
          exception is PostgrestException ? 'rejected' : 'uncertain',
        ),
      );
      if (!mounted || !_ownsAccount) return;
      final alreadyCreated = b.tripId != null && b.tripId!.isNotEmpty;
      if (!alreadyCreated && exception.toString().contains('wallet')) {
        GrowthService().observe('wallet_payment_failed');
      }
      setState(() {
        creating = false;
        locked = false;
        error = _bookingPromoError(exception, alreadyCreated: alreadyCreated);
        // Never send the user back to Fare after a successful INSERT:
        // pressing Request again would create a second trip/wallet hold.
        step = alreadyCreated ? BookingStep.searching : BookingStep.fare;
      });
      sheet.forward();
    }
  }

  // ===========================================================================
  // REALTIME
  // ===========================================================================

  void _startSearchRecoveryV37() {
    // Realtime remains primary; this only catches missed transitions after
    // losing network coverage. Never re-create a trip or restart dispatch.
    _searchRecoveryTimerV37?.cancel();
    _searchRecoveryTimerV37 = Timer.periodic(const Duration(seconds: 18), (_) {
      if (mounted &&
          _ownsAccount &&
          step == BookingStep.searching &&
          b.tripId != null &&
          !_checkingTripStatus) {
        unawaited(_refreshTripStatus());
      }
    });
  }

  void _subscribe(String id) {
    if (_subscribedTripV10 == id && tripSub != null) return;
    _subscribedTripV10 = id;
    tripSub?.unsubscribe();

    tripSub = SupabaseService.instance.subscribeToTripStatus(id, (row) {
      if (!mounted || !_ownsAccount || b.tripId != id || navigating) {
        return;
      }

      _mergeSearchAmountsV37(row);
      if (row['incentive_amount'] != null && mounted)
        setState(() {
          b.incentive = _toDouble(row['incentive_amount']).round();
          b.fare = _toDouble(row['total_fare']);
          b.wallet = _toDouble(row['wallet_amount']);
          b.cash = _toDouble(row['cash_amount']);
        });
      if (row['offer'] is Map) {
        final offer = Map<String, dynamic>.from(row['offer'] as Map);
        if (offer['id'] != null && !offers.any((o) => o['id'] == offer['id']))
          setState(() => offers.add(offer));
      }
      final status = row['trip_status']?.toString() ?? '';

      final captain = row['captain_id']?.toString();

      /*
         * لا نفتح LiveTrip إلا عندما:
         *
         * status = accepted
         * AND captain_id موجود.
         */
      if (const {
            'accepted',
            'arriving',
            'arrived',
            'started',
          }.contains(status) &&
          captain != null &&
          captain.isNotEmpty) {
        _openAfterSearch(id);
        return;
      }

      if (status == 'cancelled') {
        if (row['cancellation_reason']?.toString() == 'search_timeout_10m') {
          navigating = true;
          context.go(AppRoutes.homeScreen);
        } else {
          _show(context.strings.bookingFinalCopyb9f67739);
          _backToFare();
        }
      }
    });
  }

  // ===========================================================================
  // OPEN LIVE TRIP AFTER SEARCH
  // ===========================================================================

  Future<void> _openAfterSearch(String id) async {
    if (navigating || _openingAfterSearch || _cancellingSearch) return;
    _openingAfterSearch = true;
    final uid = SupabaseService.instance.currentUser?.id;
    searchStarted ??= DateTime.now();
    try {
      await _acceptedNavigation.confirm(
        readTrip: () => SupabaseService.instance.getTripById(id),
        isCurrent: () =>
            mounted &&
            uid != null &&
            SupabaseService.instance.currentUser?.id == uid &&
            b.tripId == id &&
            !navigating &&
            !_cancellingSearch,
        onConfirmed: () {
          navigating = true;
          unawaited(AppSoundService.instance.playSuccess());
          context.go('${AppRoutes.liveTrip}?tripId=$id');
        },
      );
    } finally {
      _openingAfterSearch = false;
    }
  }

  // ===========================================================================
  // INCENTIVE
  // ===========================================================================

  String? _boostRequestV13;
  Future<void> _boostV10(int targetAmount) async {
    final id = b.tripId;
    if (id == null || _decidingPrice) return;

    final current = b.incentive.round();
    if (targetAmount <= current) {
      _show(context.strings.bookingCurrentIncentive('$current'));
      return;
    }

    _boostRequestV13 = SupabaseService.newFinancialRequestId();
    setState(() => _decidingPrice = true);
    try {
      final raw = await SupabaseService.instance
          .setTripIncentiveTargetV13(
            id,
            targetAmount,
            requestId: _boostRequestV13,
          )
          .timeout(const Duration(seconds: 12));
      final row = Map<String, dynamic>.from(raw['trip'] as Map);
      if (!mounted || !_ownsAccount || b.tripId != id) return;
      setState(() {
        b.incentive = (_toDouble(row['incentive_amount'])).round();
        b.fare = _toDouble(row['total_fare']);
        b.wallet = _toDouble(row['wallet_amount']);
        b.cash = _toDouble(row['cash_amount']);
        _priceSuggestion = null;
        _nextPriceCheck = null;
      });
      _boostRequestV13 = null;
      await _checkPriceSuggestion(id);
    } catch (_) {
      if (mounted && _ownsAccount) {
        _show(context.strings.bookingFinalCopyd6bf4f47);
      }
    } finally {
      if (mounted && _ownsAccount) setState(() => _decidingPrice = false);
    }
  }

  Future<void> _checkPriceSuggestion(String id) async {
    if (_priceSuggestion != null ||
        _decidingPrice ||
        (_nextPriceCheck != null && DateTime.now().isBefore(_nextPriceCheck!)))
      return;
    final data = await SupabaseService.instance.getSearchPriceSuggestionV9(id);
    if (!mounted ||
        !_ownsAccount ||
        b.tripId != id ||
        step != BookingStep.searching)
      return;
    if (data['eligible'] == true) {
      _priceSuggestionTimer?.cancel();
      _priceSuggestionTimer = null;
      if (_priceSuggestion?['id'] != data['id']) {
        setState(() => _priceSuggestion = data);
      }
    } else {
      final available = DateTime.tryParse(
        data['available_at']?.toString() ?? '',
      );
      final serverNow = DateTime.tryParse(data['server_now']?.toString() ?? '');
      final localAvailable = available != null && serverNow != null
          ? DateTime.now().add(available.difference(serverNow))
          : DateTime.now().add(const Duration(minutes: 1));
      _nextPriceCheck = localAvailable;
      _priceSuggestionTimer?.cancel();
      final delay = localAvailable.difference(DateTime.now());
      _priceSuggestionTimer = Timer(
        delay.isNegative
            ? const Duration(milliseconds: 250)
            : delay + const Duration(milliseconds: 350),
        () {
          if (!mounted ||
              !_ownsAccount ||
              b.tripId != id ||
              step != BookingStep.searching)
            return;
          _nextPriceCheck = null;
          unawaited(_checkPriceSuggestion(id));
        },
      );
      if (_priceSuggestion != null) setState(() => _priceSuggestion = null);
    }
  }

  Future<void> _decidePrice(bool improve) async {
    final id = b.tripId;
    final quote = _priceSuggestion?['id']?.toString();
    if (_decidingPrice || id == null || quote == null) return;
    setState(() => _decidingPrice = true);
    try {
      final data = await SupabaseService.instance.decideSearchPriceV9(
        id,
        quote,
        improve,
      );
      if (!mounted || !_ownsAccount || b.tripId != id) return;
      final trip = Map<String, dynamic>.from(data['trip'] as Map);
      setState(() {
        _priceSuggestion = null;
        _nextPriceCheck = DateTime.now().add(const Duration(days: 1));
        b.fare = _toDouble(trip['total_fare']);
        b.wallet = _toDouble(trip['wallet_amount']);
        b.cash = _toDouble(trip['cash_amount']);
      });
      await _refreshTripStatus();
    } catch (_) {
      if (mounted && _ownsAccount)
        _show(context.strings.bookingFinalCopy6c65081c);
      await _refreshTripStatus();
    } finally {
      if (mounted && _ownsAccount) setState(() => _decidingPrice = false);
    }
  }

  // ===========================================================================
  // CANCEL SEARCH
  // ===========================================================================

  Future<void> _cancelSearch() async {
    final id = b.tripId;
    if (id == null || id.isEmpty || navigating || _cancellingSearch) return;
    unawaited(GrowthService().observe('cancel_requested'));
    _cancellingSearch = true;
    if (mounted && _ownsAccount) setState(() {});
    try {
      final result = await SupabaseService.instance.cancelCustomerSearchV37(id);
      if (!mounted || !_ownsAccount || b.tripId != id) return;
      if (result['success'] == true || result['already_cancelled'] == true) {
        _priceSuggestionTimer?.cancel();
        _searchRecoveryTimerV37?.cancel();
        tripSub?.unsubscribe();
        navigating = true;
        context.go(AppRoutes.homeScreen);
        return;
      }
      throw StateError(result['error']?.toString() ?? 'cancel_failed');
    } catch (error) {
      if (!mounted || !_ownsAccount) return;
      unawaited(GrowthService().observe('cancel_failed'));
      // The server remains authoritative. If a captain accepted at the same
      // moment, move to the live trip; otherwise keep the cancel action usable.
      try {
        final fresh = await SupabaseService.instance.getTripById(id);
        final status = fresh?['trip_status']?.toString() ?? '';
        final captainId = fresh?['captain_id']?.toString();
        if (const {
              'accepted',
              'arriving',
              'arrived',
              'started',
            }.contains(status) &&
            captainId != null &&
            captainId.isNotEmpty) {
          if (mounted && _ownsAccount) {
            navigating = true;
            context.go('${AppRoutes.liveTrip}?tripId=$id');
          }
          return;
        }
        if (status == 'cancelled') {
          final fee = num.tryParse(
            fresh?['cancellation_fee_used']?.toString() ?? '',
          );
          final legacyFee = num.tryParse(
            fresh?['cancellation_fee']?.toString() ?? '',
          );
          if (fee != 0 || legacyFee != 0) {
            if (mounted && _ownsAccount)
              _show(context.strings.bookingFinalCopydd481f00);
            return;
          }
          if (mounted && _ownsAccount) {
            navigating = true;
            context.go(AppRoutes.homeScreen);
          }
          return;
        }
      } catch (_) {}
      if (mounted && _ownsAccount) {
        // The server may reject free cancellation after a concurrent
        // acceptance. Never fall back to the fee-bearing cancellation RPC.
        _show(localizedCancellationFailure(context, error));
      }
    } finally {
      _cancellingSearch = false;
      if (mounted && _ownsAccount) setState(() {});
    }
  }

  void _backToFare() {
    _searchRecoveryTimerV37?.cancel();
    _searchAmountsV37 = null;
    _priceSuggestionTimer?.cancel();
    _priceSuggestionTimer = null;
    tripSub?.unsubscribe();

    if (!mounted || !_ownsAccount) return;

    setState(() {
      b.tripId = null;

      offers.clear();

      searchStarted = null;

      locked = false;

      navigating = false;
    });

    _next(BookingStep.fare);
  }

  // ===========================================================================
  // PROMO
  // ===========================================================================

  Future<Map<String, dynamic>> _promo(String code, double amount) async {
    final generation = ++_promoValidationGeneration;
    final revision = _routeRevisionV36;
    final owner = customerId;
    if (customerId == null) {
      return {'success': false, 'error': 'login_required'};
    }
    try {
      final result = await SupabaseService.instance.validatePromoCode(
        code,
        customerId!,
        amount,
      );
      if (!mounted ||
          !_ownsAccount ||
          generation != _promoValidationGeneration ||
          revision != _routeRevisionV36 ||
          owner != customerId) {
        return {'success': false, 'error': 'promo_network_error'};
      }
      if (result['success'] == true) {
        promoCode = result['code']?.toString() ?? code;
        promoDiscount = _toDouble(result['discount']);
        return result;
      }
      promoCode = null;
      promoDiscount = 0;
      return result;
    } catch (_) {
      if (generation != _promoValidationGeneration) {
        return {'success': false, 'error': 'promo_network_error'};
      }
      promoCode = null;
      promoDiscount = 0;
      return {'success': false, 'error': 'promo_network_error'};
    }
  }

  void _clearPromo() {
    _promoValidationGeneration++;
    promoCode = null;
    promoDiscount = 0;
  }

  String _bookingPromoError(Object exception, {bool alreadyCreated = false}) =>
      localizedBookingFailure(
        context,
        exception,
        alreadyCreated: alreadyCreated,
      );

  // ===========================================================================
  // PAYMENT CALCULATION
  // ===========================================================================

  _PaymentAmounts _calculatePaymentAmounts({
    required String method,
    required double total,
    required double walletBalance,
  }) {
    final safeTotal = _positive(total);

    final double availableWallet = walletBalance > 0 ? walletBalance : 0.0;

    if (method == 'wallet' && availableWallet >= safeTotal) {
      return _PaymentAmounts(
        method: 'wallet',
        walletAmount: safeTotal,
        cashAmount: 0,
      );
    }

    if (method == 'combined') {
      final double walletAmount = availableWallet > safeTotal
          ? safeTotal
          : availableWallet;

      return _PaymentAmounts(
        method: 'combined',
        walletAmount: walletAmount,
        cashAmount: safeTotal - walletAmount,
      );
    }

    /*
     * Cash هو الوضع الافتراضي.
     */
    return _PaymentAmounts(
      method: 'cash',
      walletAmount: 0,
      cashAmount: safeTotal,
    );
  }

  // ===========================================================================
  // UI
  // ===========================================================================

  String get title {
    switch (step) {
      case BookingStep.service:
        return context.strings.ui41f09900;

      case BookingStep.pickup:
        return context.strings.ui4e3d1712;

      case BookingStep.destination:
        return context.strings.uia3ac6d76;

      case BookingStep.fare:
        return _growthBookingUi && _routeFirstV36
            ? (_growthServiceChosen
                  ? context.strings.ui7fc5c5dd
                  : context.strings.ui09e60c0f)
            : (_routeFirstV36
                  ? context.strings.ui56807a6f
                  : context.strings.uib075cda8);

      case BookingStep.searching:
        return context.strings.ui3c6518b4;

      case BookingStep.offers:
        return context.strings.ui07676a93;
    }
  }

  Widget _sheet() {
    switch (step) {
      case BookingStep.service:
        return BookingServiceSheetWidget(onServiceSelected: _service);

      case BookingStep.pickup:
        return BookingPickupSheetWidget(
          onPickupSelected: _pickup,
          onUseCurrentLocation: () => _useCurrentLocationV36(auto: true),
          prefilledLabel: b.pickupLat == null ? null : pickupLabel,
          initialNote: b.customerNote,
          descriptionRequired:
              b.pickupLat != null &&
              (b.area == context.strings.selectedLocation ||
                  b.area == CustomerCityScopeV38.name ||
                  (b.area?.trim().isEmpty ?? true)),
          onConfirmPrefilled: b.pickupLat == null || b.pickupLng == null
              ? null
              : () => _pickup(
                  b.area ?? '',
                  b.building ?? '',
                  lat: b.pickupLat,
                  lng: b.pickupLng,
                ),
          onNoteChanged: (value) => b.customerNote = value,
        );

      case BookingStep.destination:
        return BookingDestinationSheetWidget(
          pickupLabel: pickupLabel,
          pickupAreaLetter: b.area,
          pickupLat: b.pickupLat,
          pickupLng: b.pickupLng,
          customerId: customerId,
          onDestinationSelected: _destination,
        );

      case BookingStep.fare:
        if (b.fare == null || b.pricingQuote == null) {
          return Padding(
            padding: EdgeInsets.all(30),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    context.strings.bookingFinalCopy70377ee9,
                    style: TextStyle(),
                  ),
                ],
              ),
            ),
          );
        }
        final fareWidget = BookingFareSheetWidget(
          serviceId: b.service ?? 'car',

          pickupLabel: pickupLabel,

          destinationLabel: b.destination ?? '',

          distance: b.distance ?? 0,

          duration: b.duration ?? 0,

          fare: b.fare ?? 0,
          growthDiscount: _useEarnedDiscount ? _growthDiscount : 0,
          availableGrowthDiscount: _growthDiscount,
          useEarnedDiscount: _useEarnedDiscount,
          onEarnedDiscountChanged: (use) {
            if (!mounted || !_ownsAccount || creating) return;
            setState(() => _useEarnedDiscount = use);
          },
          growthPreviewReady: _growthQuoteReady,

          incentiveAmount: b.incentive,

          passengerCount: b.passengers,

          packageWeightKg: b.weight,

          /*
           * لو الرصيد سالب:
           *
           * -50
           *
           * الـFare Widget يعرض:
           * مستحق سابق = 50
           */
          walletBalance: walletBalance,

          previousDueReason: previousDueReason,

          initialCustomerNote: b.customerNote,
          initialExtraExpectedAmount: b.extraExpectedAmount,
          onExtraExpectedAmountChanged: (value) =>
              b.extraExpectedAmount = value,
          initialExtraRequests: b.extraRequests,
          onExtraRequestsChanged: (value) => b.extraRequests = value,

          onCustomerNoteChanged: (value) {
            b.customerNote = value;
          },

          // These values are already rendered inside the fare sheet itself.
          // Updating the booking model without rebuilding the entire booking
          // screen keeps payment/passenger interactions noticeably lighter.
          onPassengerCountChanged: (value) {
            b.passengers = value.clamp(1, 4).toInt();
          },

          onPackageWeightChanged: (value) {
            b.weight = value;
          },

          onPaymentMethodChanged: (method, wallet, cash) {
            b.payment = method;
            b.wallet = wallet;
            b.cash = cash;
          },

          onConfirm: _confirm,

          onApplyPromo: _promo,
          onClearPromo: _clearPromo,
        );
        if (!_canCompareRideFares) return fareWidget;
        return Column(
          children: [
            if (_categoriesV3.any((c) => c.enabled && c.id != 'veto_market'))
              _categorySummaryV3()
            else
              _servicesV36(),
            Expanded(child: fareWidget),
          ],
        );

      case BookingStep.searching:
        return const SizedBox.shrink();

      case BookingStep.offers:
        return BookingCaptainOffersWidget(
          tripId: b.tripId ?? '',

          offers: offers,

          onCaptainSelected: (_, __) {
            _show(context.strings.ui1dc14005);
          },
        );
    }
  }

  int get _flowStepsCount => 4;

  int get _currentFlowStep {
    switch (step) {
      case BookingStep.service:
        return 1;
      case BookingStep.pickup:
        return _routeFirstV36 ? 1 : 2;
      case BookingStep.destination:
        return _routeFirstV36 ? 2 : 3;
      case BookingStep.fare:
      case BookingStep.searching:
      case BookingStep.offers:
        return _routeFirstV36 && step == BookingStep.fare ? 3 : 4;
    }
  }

  String get _stepLead {
    switch (step) {
      case BookingStep.service:
        return context.strings.ui4c324b17;
      case BookingStep.pickup:
        return context.strings.uia06d487b;
      case BookingStep.destination:
        return context.strings.uic714374d;
      case BookingStep.fare:
        return context.strings.ui94709dd1;
      case BookingStep.searching:
        return context.strings.ui194ae5ca;
      case BookingStep.offers:
        return context.strings.ui595241dd;
    }
  }

  String get _stepSubtitle {
    switch (step) {
      case BookingStep.service:
        return context.strings.ui674f7a10;
      case BookingStep.pickup:
        return context.strings.ui5acaa87e;
      case BookingStep.destination:
        return context.strings.ui4ef558e7;
      case BookingStep.fare:
        return context.strings.uice4a26ca;
      case BookingStep.searching:
        return context.strings.uiacd55510;
      case BookingStep.offers:
        return context.strings.uib3a04740;
    }
  }

  IconData get _stepIcon {
    switch (step) {
      case BookingStep.service:
        return Icons.grid_view_rounded;
      case BookingStep.pickup:
        return Icons.my_location_rounded;
      case BookingStep.destination:
        return Icons.route_rounded;
      case BookingStep.fare:
        return Icons.receipt_long_rounded;
      case BookingStep.searching:
        return Icons.radar_rounded;
      case BookingStep.offers:
        return Icons.local_taxi_rounded;
    }
  }

  List<_BookingSummaryChipData> get _summaryChips {
    final items = <_BookingSummaryChipData>[];
    if (b.service != null && serviceLabel != null) {
      items.add(
        _BookingSummaryChipData(
          icon: Icons.local_taxi_rounded,
          label: context.strings.ui728e6087,
          value: serviceLabel!,
          color: AppTheme.gold,
        ),
      );
    }
    if (b.area != null || b.building != null) {
      items.add(
        _BookingSummaryChipData(
          icon: Icons.my_location_rounded,
          label: context.strings.ui4d7d679f,
          value: pickupLabel,
          color: const Color(0xFF53B9FF),
        ),
      );
    }
    if ((b.destination ?? '').trim().isNotEmpty) {
      items.add(
        _BookingSummaryChipData(
          icon: Icons.flag_rounded,
          label: context.strings.ui97fe3fe5,
          value: b.destination!,
          color: const Color(0xFF8E7CFF),
        ),
      );
    }
    if ((b.fare ?? 0) > 0 && step.index >= BookingStep.fare.index) {
      items.add(
        _BookingSummaryChipData(
          icon: Icons.payments_rounded,
          label: context.strings.ui8d0a03c3,
          value: context.strings.moneyValue((b.fare ?? 0).toStringAsFixed(2)),
          color: const Color(0xFF45D18C),
        ),
      );
    }
    return items;
  }

  Widget _buildHeaderCard() {
    final progress = (_currentFlowStep / _flowStepsCount)
        .clamp(0, 1)
        .toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.surface.withAlpha(240),
            Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withAlpha(228),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(180),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: _back,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(170),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 17,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withAlpha(35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _stepIcon,
                            color: AppTheme.gold,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _stepLead,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: progress,
                        backgroundColor: AppTheme.primary.withAlpha(140),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.gold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          context.strings.flowStep(
                            _currentFlowStep,
                            _flowStepsCount,
                          ),
                          style: const TextStyle(
                            color: AppTheme.gold,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.strings.uib43afc26,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.gold,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            _stepSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10.5,
            ),
          ),
          if (_summaryChips.isNotEmpty) ...[
            const SizedBox(height: 7),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final item = _summaryChips[index];
                  return _BookingSummaryChip(item: item);
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: _summaryChips.length,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(248),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 16)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: context.strings.uicb822418,
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: _back,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      context.strings.uib43afc26,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$_currentFlowStep / $_flowStepsCount',
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: _currentFlowStep / _flowStepsCount,
              minHeight: 5,
              backgroundColor: Theme.of(context).colorScheme.outline,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
            ),
          ),
          if (_routeFirstV36 &&
              step == BookingStep.pickup &&
              b.pickupLat != null &&
              b.pickupLng != null) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(
                  Icons.my_location_rounded,
                  color: AppTheme.gold,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.strings.foundPickup(pickupLabel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _next(BookingStep.destination),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                  ),
                  icon: const Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  label: Text(
                    context.strings.ui8f7d74ac,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (!const <String>{
              'أ',
              'ب',
              'ج',
              'د',
              'هـ',
              'و',
              'ز',
              'ح',
              'ط',
              'ك',
              'ل',
              'م',
              'ن',
              'ع',
              'س',
              'ص',
            }.contains(b.area))
              V37SuggestAddressButton(
                cityHint: b.area,
                latitude: b.pickupLat,
                longitude: b.pickupLng,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchingCard() {
    if (b.tripId == null || b.pickupLat == null || b.pickupLng == null)
      return const SizedBox.shrink();
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ProductSearchingView(
            tripId: b.tripId!,
            searchStarted: searchStarted,
            pickupLabel: pickupLabel,
            destinationLabel: b.destination ?? '',
            pickup: LatLng(b.pickupLat!, b.pickupLng!),
            destination: b.destLat == null || b.destLng == null
                ? null
                : LatLng(b.destLat!, b.destLng!),
            onHome: () => context.go(AppRoutes.homeScreen),
            onRefresh: () => _refreshTripStatus(manual: true),
            onCancel: _cancelSearch,
            price: _searchPriceCardV37(),
            offerControls: Column(
              children: [
                if (_priceSuggestion != null)
                  SearchPriceSuggestionV9(
                    total: _toDouble(_priceSuggestion!['suggested_total']),
                    busy: _decidingPrice,
                    onContinue: () => _decidePrice(false),
                    onImprove: () => _decidePrice(true),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final amount in [5, 10, 15, 20])
                      ChoiceChip(
                        label: Text('+ $amount'),
                        selected: b.incentive == amount,
                        onSelected: _decidingPrice || b.incentive >= amount
                            ? null
                            : (_) => _boostV10(amount),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (!_ownsAccount) {
      return Scaffold(
        body: SafeArea(
          child: Center(child: Text(context.strings.bookingAccountChanged)),
        ),
      );
    }
    return Directionality(
      textDirection: Directionality.of(context),
      child: PopScope(
        canPop: step != BookingStep.searching,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && step == BookingStep.searching) {
            context.go(AppRoutes.homeScreen);
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: LayoutBuilder(
            builder: (context, viewport) {
              final locationStep =
                  step == BookingStep.pickup || step == BookingStep.destination;
              final headerHeight =
                  MediaQuery.paddingOf(context).top +
                  (_growthBookingUi ? 48 : 0) +
                  (locationStep
                      ? 116
                      : step == BookingStep.fare
                      ? 180
                      : (_summaryChips.isEmpty ? 166 : 207));
              final availableSheetHeight =
                  viewport.maxHeight > headerHeight + 90
                  ? viewport.maxHeight - headerHeight
                  : viewport.maxHeight * (locationStep ? 0.83 : 0.64);
              final maxSheetHeight = step == BookingStep.fare
                  ? math.min(availableSheetHeight, viewport.maxHeight * 0.82)
                  : availableSheetHeight;
              // Location choice is a real, full-height page. The previous
              // floating sheet could push the place-type controls outside the
              // visible viewport, especially in browsers and on short phones.
              if (locationStep) {
                return SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: _back,
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  tooltip: MaterialLocalizations.of(
                                    context,
                                  ).backButtonTooltip,
                                ),
                                Expanded(
                                  child: Text(
                                    step == BookingStep.pickup
                                        ? 'أكد مكان ركوبك'
                                        : 'رايح فين؟',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Text(
                                  step == BookingStep.pickup
                                      ? '1 / 3'
                                      : '2 / 3',
                                  style: const TextStyle(
                                    color: AppTheme.gold,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_firstTripGuideOpen)
                            Card(
                              child: ListTile(
                                title: Text(
                                  context.strings.bookingGuide,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                trailing: IconButton(
                                  tooltip: context.strings.understood,
                                  onPressed: _dismissBookingGuide,
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                            ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Material(
                                color: AppTheme.errorLight,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        error!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (_retryDestinationQuote != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          b.destination ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: _retryingDestinationQuote
                                              ? null
                                              : _retrySelectedDestinationQuote,
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.white,
                                          ),
                                          icon: const Icon(Icons.refresh),
                                          label: Text(context.strings.retry),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (step == BookingStep.pickup)
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: BookingMapWidget(
                                        pickupLat: b.pickupLat,
                                        pickupLng: b.pickupLng,
                                        pickupLabel: pickupLabel,
                                      ),
                                    ),
                                  ),
                                  Expanded(flex: 4, child: _sheet()),
                                ],
                              ),
                            )
                          else
                            Expanded(child: _sheet()),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return Stack(
                // The header is a small non-positioned child. Without an
                // expanded stack it determines the whole map/sheet height.
                fit: StackFit.expand,
                children: [
                  if (step != BookingStep.searching)
                    Positioned(
                      top: step == BookingStep.fare
                          ? MediaQuery.paddingOf(context).top +
                                (_growthBookingUi ? 112 : 76)
                          : 0,
                      bottom: step == BookingStep.fare ? maxSheetHeight : 0,
                      left: 0,
                      right: 0,
                      child: BookingMapWidget(
                        pickupLat: b.pickupLat,
                        pickupLng: b.pickupLng,
                        destLat: b.destLat,
                        destLng: b.destLng,
                        pickupLabel: b.area == null ? null : pickupLabel,
                        destLabel: b.destination,
                        routePoints: b.route,
                      ),
                    ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(
                              context,
                            ).scaffoldBackgroundColor.withAlpha(75),
                            Theme.of(
                              context,
                            ).scaffoldBackgroundColor.withAlpha(15),
                            Theme.of(
                              context,
                            ).scaffoldBackgroundColor.withAlpha(190),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.34, 1.0],
                        ),
                      ),
                    ),
                  ),
                  if (step != BookingStep.searching)
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                        child: locationStep
                            ? _buildLocationHeader()
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_growthBookingUi)
                                    GrowthBookingProgress(
                                      stage:
                                          step == BookingStep.fare &&
                                              _growthServiceChosen
                                          ? 2
                                          : 1,
                                    ),
                                  if (step == BookingStep.fare)
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: _back,
                                          tooltip: MaterialLocalizations.of(
                                            context,
                                          ).backButtonTooltip,
                                          icon: const Icon(
                                            Icons.arrow_forward_rounded,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            'راجع مشوارك',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    _buildHeaderCard(),
                                ],
                              ),
                      ),
                    ),
                  if (error != null)
                    Positioned(
                      top: MediaQuery.paddingOf(context).top + 186,
                      left: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.errorLight.withAlpha(240),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                error!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => error = null),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_routePreviewUnavailable && step == BookingStep.fare)
                    Positioned(
                      top: headerHeight,
                      left: 14,
                      right: 14,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            context.strings.routeDisplayUnavailable,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                  if (creating)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withAlpha(90),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.gold,
                          ),
                        ),
                      ),
                    ),
                  if (step == BookingStep.searching)
                    _buildSearchingCard()
                  else
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxSheetHeight),
                        child: SlideTransition(
                          position: slide,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_firstTripGuideOpen &&
                                  step != BookingStep.fare)
                                Card(
                                  child: ListTile(
                                    title: Text(
                                      context.strings.bookingGuide,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    trailing: IconButton(
                                      tooltip: context.strings.understood,
                                      onPressed: _dismissBookingGuide,
                                      icon: const Icon(Icons.close),
                                    ),
                                  ),
                                ),
                              Flexible(child: _sheet()),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ), // Scaffold
      ), // PopScope
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is num) {
      return value.toDouble();
    }

    final parsed = double.tryParse(value?.toString() ?? '');

    return parsed ?? fallback;
  }

  double _positive(double value) {
    return value < 0 ? 0 : value;
  }

  void _show(String message) {
    if (!mounted || !_ownsAccount) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: Directionality.of(context),
          style: const TextStyle(),
        ),
        backgroundColor: AppTheme.errorLight,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_saveBookingDraft());
    _bookingAuthSubscription?.cancel();
    if (_ownsAccount &&
        (step == BookingStep.pickup || step == BookingStep.destination)) {
      GrowthService().observe('area_selection_abandoned');
    }
    _priceSuggestionTimer?.cancel();
    _searchRecoveryTimerV37?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    tripSub?.unsubscribe();
    sheet.dispose();
    super.dispose();
  }
}

class _BookingSummaryChipData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _BookingSummaryChipData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

class _BookingSummaryChip extends StatelessWidget {
  final _BookingSummaryChipData item;
  const _BookingSummaryChip({required this.item});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppTheme.primary.withAlpha(185),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: item.color.withAlpha(140)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, size: 16, color: item.color),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 135),
          child: Text(
            '${item.label}: ${item.value}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

// ============================================================================
// PAYMENT MODEL
// ============================================================================

class _PaymentAmounts {
  final String method;
  final double walletAmount;
  final double cashAmount;

  const _PaymentAmounts({
    required this.method,
    required this.walletAmount,
    required this.cashAmount,
  });
}
