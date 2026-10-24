import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../services/booking_address_seed.dart';
import '../../services/booking_performance.dart';
import '../../services/product_session_timing.dart';
import '../../services/home_read_coordinator.dart';
import '../../l10n/strings.dart';
import '../growth/growth_screens.dart';
import '../../services/growth_service.dart';
import '../../services/customer_location_state.dart';
import '../../services/product_geocoding_service.dart';
import '../../services/zone_pricing_service.dart';
import '../../theme/app_theme.dart';
import './widgets/home_active_trip_widget.dart';
import '../../widgets/customer_map_home.dart';
import '../trip_booking_screen/widgets/booking_map_widget.dart';
import './widgets/product_home_panel.dart';
import '../../services/customer_city_scope_v38.dart';
import '../../widgets/customer_city_selector_v38.dart';
import './widgets/home_promo_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  double _walletBalance = 0.0;
  int _completedTrips = 0;

  bool _hasActiveTrip = false;
  Map<String, dynamic>? _activeTrip;
  Map<String, dynamic>? _activeMarketOrder;

  bool _isLoading = true;
  bool _homeLoadFailed = false;
  bool _marketLoadFailed = false;
  int _homeDataRevision = 0;
  String? _homeAuthUserId;
  StreamSubscription<AuthState>? _homeAuthSubscription;
  String? _lastPromptedTimeoutTripId;
  bool _checkingTimeout = false;
  BuildContext? _timeoutDialogContext;
  Timer? _timeoutExpiryTimer;

  String? _customerId;

  int _unreadNotifications = 0;

  String? _manuallyChosenCityV38;
  double? _lastLatitudeV37;
  double? _lastLongitudeV37;
  PricingZone? _currentZone;
  String? _savedPickupLabel;
  String? _nearbyPickupLabel;
  String get _shortPickupLabel => _savedPickupLabel ?? _nearbyPickupLabel ??
      (_zoneLocationUnavailable || _currentZone == null
        ? 'موقعك الحالي' : _currentZone!.name);
  BookingAddressSeed? _homePickup;
  DateTime? _homePickupValidUntil;
  BookingAddressSeed? get _suggestedPickup {
    if (_zoneResolving || _zoneLocationUnavailable) return null;
    if (_manuallyChosenCityV38 != null &&
        _manuallyChosenCityV38 != _currentZone?.name)
      return null;
    if (_homePickupValidUntil?.isBefore(DateTime.now()) == true) return null;
    return _homePickup;
  }

  bool _zoneResolving = true;
  bool _zoneLocationUnavailable = false;
  DateTime? _lastZoneCheck;

  RealtimeChannel? _walletSubscription;
  RealtimeChannel? _tripSubscription;
  RealtimeChannel? _marketOrderSubscription;
  RealtimeChannel? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(GrowthService().observe('app_opened'));
    WidgetsBinding.instance.addObserver(this);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );

    _loadCustomerData();
    _homeAuthUserId = SupabaseService.instance.currentUser?.id;
    _homeAuthSubscription = SupabaseService
        .instance
        .client
        .auth
        .onAuthStateChange
        .listen((state) {
          final next = state.session?.user.id;
          if (!mounted || next == _homeAuthUserId) return;
          _homeAuthUserId = next;
          _homeDataRevision++;
          _walletSubscription?.unsubscribe();
          _walletSubscription = null;
          _tripSubscription?.unsubscribe();
          _tripSubscription = null;
          _marketOrderSubscription?.unsubscribe();
          _marketOrderSubscription = null;
          _notificationSubscription?.unsubscribe();
          _notificationSubscription = null;
          _timeoutExpiryTimer?.cancel();
          ProductSessionTiming.instance.clearHomeForAccountChange();
          setState(() {
            _customerId = null;
            _walletBalance = 0;
            _completedTrips = 0;
            _unreadNotifications = 0;
            _activeTrip = null;
            _hasActiveTrip = false;
            _activeMarketOrder = null;
            _currentZone = null;
            _savedPickupLabel = null;
            _nearbyPickupLabel = null;
            _homePickup = null;
            _homePickupValidUntil = null;
            _lastLatitudeV37 = null;
            _lastLongitudeV37 = null;
            _manuallyChosenCityV38 = null;
            _lastZoneCheck = null;
            _lastPromptedTimeoutTripId = null;
            _homeLoadFailed = false;
            _marketLoadFailed = false;
            _isLoading = true;
          });
          unawaited(_loadCustomerData());
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // A trip may have been accepted while the home screen was suspended.
      _loadCustomerData();
      unawaited(_dismissTimeoutDialogIfExpired());
    }
  }

  Future<void> _dismissTimeoutDialogIfExpired() async {
    final ctx = _timeoutDialogContext;
    if (ctx == null || !ctx.mounted) return;
    try {
      final result = await SupabaseService.instance.client.rpc(
        'customer_pending_search_retry_v28',
      );
      if (result is Map &&
          result['eligible'] != true &&
          ctx.mounted &&
          identical(_timeoutDialogContext, ctx)) {
        Navigator.of(ctx).pop(false);
      }
    } catch (_) {
      // Do not dismiss based on an unverified network error.
    }
  }

  Future<void> _offerTimeoutRetry() async {
    if (!mounted || _checkingTimeout || _hasActiveTrip) return;
    _checkingTimeout = true;
    try {
      // Eligibility and expiration are decided by Supabase clock, not device time.
      final result = await SupabaseService.instance.client.rpc(
        'customer_pending_search_retry_v28',
      );
      if (result is! Map || result['eligible'] != true || !mounted) return;
      final id = result['trip_id']?.toString();
      if (id == null || id.isEmpty || _lastPromptedTimeoutTripId == id) return;
      _lastPromptedTimeoutTripId = id;
      if (!mounted || _hasActiveTrip) return;
      final expiresAt = DateTime.tryParse(
        result['expires_at']?.toString() ?? '',
      );
      final serverNow = DateTime.tryParse(
        result['server_now']?.toString() ?? '',
      );
      _timeoutExpiryTimer?.cancel();
      if (expiresAt != null && serverNow != null) {
        final delay = expiresAt.difference(serverNow);
        _timeoutExpiryTimer = Timer(
          delay.isNegative ? Duration.zero : delay + const Duration(seconds: 1),
          () {
            // The deadline came from Supabase's server clock, so hide the prompt
            // even when the app temporarily has no network connection.
            final dialog = _timeoutDialogContext;
            if (dialog != null && dialog.mounted) {
              Navigator.of(dialog).pop(false);
            }
          },
        );
      }
      final retry = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          _timeoutDialogContext = ctx;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(context.strings.home86b9f2f0),
              content: const Text(
                'ملقيناش كابتن خلال 10 دقايق، فأنهينا البحث تلقائيًا. '
                'تحب تطلب نفس المشوار من جديد؟',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.strings.home0708df98),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(context.strings.home76509239),
                ),
              ],
            ),
          );
        },
      );
      _timeoutExpiryTimer?.cancel();
      _timeoutDialogContext = null;
      if (retry == true && mounted) {
        context.push(
          '${AppRoutes.tripBookingScreen}?retryTripId=$id&timeoutRetry=1',
        );
      }
    } catch (_) {
      // Feature installation may be pending; never block Home on timeout popup.
    } finally {
      _checkingTimeout = false;
    }
  }

  Future<void> _refreshUnreadNotifications() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;
    try {
      final count = await SupabaseService.instance.getUnreadNotificationCount(
        userId,
      );
      if (mounted && SupabaseService.instance.currentUser?.id == userId) {
        setState(() => _unreadNotifications = count);
      }
    } catch (_) {
      // Keep the previous badge until connectivity is restored.
    }
  }

  Future<void> _loadCustomerData() async {
    final revision = ++_homeDataRevision;
    try {
      final user = SupabaseService.instance.currentUser;

      if (user == null) {
        if (mounted) {
          context.go(AppRoutes.signUpLoginScreen);
        }
        return;
      }

      final customer = await SupabaseService.instance
          .getCustomerByUserId(user.id)
          .timeout(const Duration(seconds: 8));

      if (customer == null) {
        if (mounted) {
          context.go(AppRoutes.signUpLoginScreen);
        }
        return;
      }

      final cid = customer['id'] as String;
      if (!mounted ||
          revision != _homeDataRevision ||
          SupabaseService.instance.currentUser?.id != user.id)
        return;

      // Independent reads run together; market availability never delays the
      // account/safety state for longer than the bounded request budget.
      final marketFuture = SupabaseService.instance
          .getMarketOrders(customerId: cid, limit: 20)
          .timeout(const Duration(seconds: 8));
      final activeFuture = SupabaseService.instance
          .getActiveTrip(cid)
          .timeout(const Duration(seconds: 8));
      final activeTrip = await HomeReadCoordinator.load(
        essential: activeFuture,
        ancillary: marketFuture,
        onAncillary: (orders) {
          if (!mounted ||
              revision != _homeDataRevision ||
              SupabaseService.instance.currentUser?.id != user.id)
            return;
          setState(() {
            _activeMarketOrder = orders
                .where(
                  (o) => !{
                    'delivered',
                    'cancelled',
                  }.contains(o['order_status']?.toString()),
                )
                .firstOrNull;
            _marketLoadFailed = false;
          });
        },
        onAncillaryError: (error) {
          if (!mounted ||
              revision != _homeDataRevision ||
              SupabaseService.instance.currentUser?.id != user.id)
            return;
          debugPrint('Home market status read failed: ${error.runtimeType}');
          setState(() {
            _activeMarketOrder = null;
            _marketLoadFailed = true;
          });
        },
      );
      if (!mounted ||
          revision != _homeDataRevision ||
          SupabaseService.instance.currentUser?.id != user.id)
        return;
      final activeStatus = activeTrip?['trip_status']?.toString();

      final hasActiveTrip =
          activeTrip != null &&
          const {
            'requested',
            'offer_received',
            'accepted',
            'arriving',
            'arrived',
            'started',
          }.contains(activeStatus);

      /*
       * IMPORTANT:
       *
       * requested / offer_received
       * =========================
       * لا نفتح Live Trip.
       *
       * لأن العميل في هذه المرحلة ما زال
       * في شاشة البحث عن كابتن.
       *
       * Live Trip يبدأ فقط بعد تعيين كابتن فعليًا.
       */

      final captainAssigned = activeTrip?['captain_id'] != null;

      if (hasActiveTrip && captainAssigned && mounted) {
        context.go('${AppRoutes.liveTrip}?tripId=${activeTrip['id']}');
        return;
      }

      if (!mounted || revision != _homeDataRevision) return;

      setState(() {
        _customerId = cid;


        _walletBalance =
            (customer['wallet_balance'] as num?)?.toDouble() ?? 0.0;

        _completedTrips = (customer['total_completed_trips'] as int?) ?? 0;

        _activeTrip = activeTrip;

        _hasActiveTrip = hasActiveTrip;

        _homeLoadFailed = false;

        _isLoading = false;
      });

      _entranceController.forward();

      _subscribeToRealtime(cid, user.id);
      // Ask about the one-time welcome only AFTER authentication, customer
      // creation and the first safe Home read have completed. An existing
      // in-progress trip always wins over the marketing sheet.
      if (!hasActiveTrip) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              revision != _homeDataRevision ||
              SupabaseService.instance.currentUser?.id != user.id)
            return;
          GrowthGiftSheet.maybeShow(
            context,
            customer: Map<String, dynamic>.from(customer),
            onNameSaved: (updatedName) {
              if (mounted && _customerId == cid) {
              }
            },
          );
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            revision == _homeDataRevision &&
            SupabaseService.instance.currentUser?.id == user.id) {
          ProductSessionTiming.instance.markHomeVisible();
        }
      });
      unawaited(_refreshUnreadNotifications());
      Future.microtask(_refreshCurrentCity);
      if (!hasActiveTrip) Future.microtask(_offerTimeoutRetry);
    } catch (_) {
      if (!mounted || revision != _homeDataRevision) return;
      setState(() {
        _isLoading = false;
        _homeLoadFailed = true;
      });
      _entranceController.forward();
    }
  }

  void _subscribeToRealtime(String customerId, String userId) {
    final subscriptionRevision = _homeDataRevision;
    bool ownsSubscription() =>
        mounted &&
        subscriptionRevision == _homeDataRevision &&
        _customerId == customerId &&
        SupabaseService.instance.currentUser?.id == userId;
    _walletSubscription?.unsubscribe();
    _tripSubscription?.unsubscribe();
    _marketOrderSubscription?.unsubscribe();
    _notificationSubscription?.unsubscribe();
    _walletSubscription = SupabaseService.instance.subscribeToCustomerWallet(
      customerId,
      (update) {
        if (!ownsSubscription()) return;

        setState(() {
          _walletBalance =
              (update['wallet_balance'] as num?)?.toDouble() ?? _walletBalance;

          _completedTrips =
              (update['total_completed_trips'] as int?) ?? _completedTrips;
        });
      },
    );

    /*
     * IMPORTANT:
     *
     * We listen to trips in realtime,
     * but we DO NOT redirect the customer
     * for requested / offer_received.
     *
     * Only an actually assigned captain can
     * open Live Trip.
     */

    _tripSubscription = SupabaseService.instance.client
        .channel('home_trips_$customerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'trips',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: customerId,
          ),
          callback: (payload) {
            if (!ownsSubscription()) return;
            final trip = payload.newRecord;

            final status = trip['trip_status']?.toString() ?? '';

            final captainId = trip['captain_id'];

            final liveStatuses = ['accepted', 'arriving', 'arrived', 'started'];

            /*
             * requested / offer_received
             * لا تعمل navigation.
             */
            if (liveStatuses.contains(status) && captainId != null && mounted) {
              context.go('${AppRoutes.liveTrip}?tripId=${trip['id']}');
            }

            /*
             * لو الرحلة لسه في البحث،
             * نحفظها فقط كرحلة حالية.
             */
            if (status == 'requested' || status == 'offer_received') {
              if (!ownsSubscription()) return;

              setState(() {
                _activeTrip = Map<String, dynamic>.from(trip);

                _hasActiveTrip = true;
              });
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trips',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: customerId,
          ),
          callback: (payload) {
            if (!ownsSubscription()) return;
            final trip = payload.newRecord;

            final status = trip['trip_status']?.toString() ?? '';

            final captainId = trip['captain_id'];

            final liveStatuses = ['accepted', 'arriving', 'arrived', 'started'];

            /*
             * أول مرة يتم تعيين كابتن:
             * نفتح Live Trip.
             */
            if (liveStatuses.contains(status) && captainId != null && mounted) {
              context.go('${AppRoutes.liveTrip}?tripId=${trip['id']}');

              return;
            }

            /*
             * أثناء البحث:
             * نظل على الصفحة الحالية.
             */
            if (status == 'requested' || status == 'offer_received') {
              if (!ownsSubscription()) return;

              setState(() {
                _activeTrip = Map<String, dynamic>.from(trip);

                _hasActiveTrip = true;
              });

              return;
            }

            /*
             * بعد الإلغاء أو الإنهاء:
             * نزيل الرحلة الحالية من Home.
             */
            if (status == 'cancelled' || status == 'completed') {
              if (!ownsSubscription()) return;

              setState(() {
                _activeTrip = null;
                _hasActiveTrip = false;
              });
            }
          },
        )
        .subscribe();

    _marketOrderSubscription = SupabaseService.instance.client
        .channel('home_market_orders_$customerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'market_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: customerId,
          ),
          callback: (_) async {
            if (!ownsSubscription()) return;
            try {
              final orders = await SupabaseService.instance.getMarketOrders(
                customerId: customerId,
                limit: 20,
              );
              Map<String, dynamic>? active;
              for (final order in orders) {
                final status = order['order_status']?.toString();
                if (status != 'delivered' && status != 'cancelled') {
                  active = order;
                  break;
                }
              }
              if (ownsSubscription()) {
                setState(() {
                  _activeMarketOrder = active;
                  _marketLoadFailed = false;
                });
              }
            } catch (_) {
              if (ownsSubscription()) {
                setState(() {
                  _activeMarketOrder = null;
                  _marketLoadFailed = true;
                });
              }
            }
          },
        )
        .subscribe();

    _notificationSubscription = SupabaseService.instance
        .subscribeToNotificationChanges(userId, (_) {
          if (ownsSubscription()) _refreshUnreadNotifications();
        });
  }

  @override
  void dispose() {
    _homeAuthSubscription?.cancel();
    _timeoutExpiryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _walletSubscription?.unsubscribe();
    _tripSubscription?.unsubscribe();
    _marketOrderSubscription?.unsubscribe();
    _notificationSubscription?.unsubscribe();

    _entranceController.dispose();

    super.dispose();
  }

  Future<void> _refreshCurrentCity({bool force = false}) async {
    final revision = _homeDataRevision;
    final userId = SupabaseService.instance.currentUser?.id;
    bool ownsRead() =>
        mounted &&
        revision == _homeDataRevision &&
        SupabaseService.instance.currentUser?.id == userId;
    final last = _lastZoneCheck;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 2)) {
      return;
    }
    if (ownsRead()) {
      setState(() {
        _zoneResolving = true;
        _zoneLocationUnavailable = false;
        if (force) {
          _savedPickupLabel = null;
          _nearbyPickupLabel = null;
        }
      });
    }
    try {
      // Always prefer the actual device position. Saved locations are a safe
      // fallback when permission or GPS is unavailable, not a fake live pin.
      final position = await CustomerLocationState.locate();
      if (!ownsRead()) return;
      BookingAddressSeed? saved;
      if (position == null && _customerId != null) {
        try {
          final addresses = await SupabaseService.instance.getCustomerAddresses(
            _customerId!,
          );
          if (!ownsRead()) return;
          for (final row in addresses) {
            final candidate = BookingAddressSeed.saved(row);
            if (candidate?.defaultPickup == true) {
              saved = candidate;
              break;
            }
          }
        } catch (_) { /* A saved fallback is optional. */ }
      }
      if (!ownsRead()) return;
      if (position == null && saved == null) {
        if (ownsRead())
          setState(() {
            _zoneResolving = false;
            _zoneLocationUnavailable = true;
            _homePickup = null;
            _nearbyPickupLabel = null;
            _lastLatitudeV37 = null;
            _lastLongitudeV37 = null;
          });
        return;
      }
      final match = await ZonePricingService.instance.resolveCity(
        saved?.latitude ?? position!.latitude,
        saved?.longitude ?? position!.longitude,
      );
      if (!ownsRead()) return;
      CustomerCityScopeV38.resolved(match?.name);
      if (saved == null) CustomerLocationState.resolved(match?.name);
      setState(() {
        _currentZone = match;
        _savedPickupLabel = saved?.label;
        _nearbyPickupLabel = null;
        _lastLatitudeV37 = saved?.latitude ?? position!.latitude;
        _lastLongitudeV37 = saved?.longitude ?? position!.longitude;
        _zoneResolving = false;
        _zoneLocationUnavailable = false;
        _lastZoneCheck = DateTime.now();
        _homePickup = match == null
            ? null
            : saved ??
                  BookingAddressSeed(
                    label: context.strings.currentPickup,
                    latitude: position!.latitude,
                    longitude: position.longitude,
                    city: match.name,
                  );
        _homePickupValidUntil = saved == null
            ? position!.timestamp.add(const Duration(seconds: 60))
            : null;
      });
      if (saved == null && position != null && match != null) {
        unawaited(_resolveNearbyPickup(
          position.latitude, position.longitude, match.name, revision, userId));
      }
    } catch (_) {
      if (!ownsRead()) return;
      setState(() {
        _zoneResolving = false;
        _zoneLocationUnavailable = true;
        _homePickup = null;
        _lastLatitudeV37 = null;
        _lastLongitudeV37 = null;
      });
    }
  }

  /// A verified building may label GPS only when it is actually within 200m.
  /// The GPS coordinates remain unchanged, even when a label is found.
  Future<void> _resolveNearbyPickup(
    double lat, double lng, String city, int revision, String? userId,
  ) async {
    String? label;
    String? area;
    String? building;
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'v36_nearest_verified_building',
        params: {'p_lat': lat, 'p_lng': lng, 'p_radius_m': 200},
      ).timeout(const Duration(seconds: 3));
      if (raw is Map && raw['area_letter'] != null &&
          raw['building_number'] != null) {
        area = raw['area_letter'].toString();
        building = raw['building_number'].toString();
        label = 'منطقة $area - عمارة $building';
      }
    } catch (_) { /* Never invent a verified building. */ }
    if (label == null) {
      try {
        final places = await SupabaseService.instance.getFamousPlaces()
            .timeout(const Duration(seconds: 3));
        double closestMeters = 201;
        for (final place in places) {
          final name = place['name']?.toString().trim() ?? '';
          final pLat = double.tryParse('${place['latitude'] ?? ''}');
          final pLng = double.tryParse('${place['longitude'] ?? ''}');
          if (name.isEmpty || pLat == null || pLng == null ||
              !pLat.isFinite || !pLng.isFinite ||
              pLat.abs() > 90 || pLng.abs() > 180) continue;
          final meters = Geolocator.distanceBetween(lat, lng, pLat, pLng);
          if (meters <= 200 && meters < closestMeters) {
            closestMeters = meters;
            label = 'قريب من $name';
          }
        }
      } catch (_) { /* No approved landmark nearby. */ }
    }
    if (label == null) {
      try {
        if (!mounted) return;
        final address = await ProductGeocodingService().reverse(
          lat, lng, language: Localizations.localeOf(context).languageCode,
        ).timeout(const Duration(seconds: 3));
        if (address != null && address.address.isNotEmpty) {
          label = address.address;
        }
      } catch (_) { /* Current location is still available. */ }
    }
    if (!mounted || revision != _homeDataRevision ||
        SupabaseService.instance.currentUser?.id != userId ||
        _savedPickupLabel != null || _zoneLocationUnavailable ||
        (_homePickupValidUntil?.isBefore(DateTime.now()) ?? false)) return;
    setState(() {
      _nearbyPickupLabel = label;
      // Changing the label must never change the actual pickup GPS pin.
      _homePickup = BookingAddressSeed(
        label: label ?? 'موقعك الحالي',
        latitude: lat, longitude: lng,
        city: city, areaLetter: area, buildingNumber: building,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.gold),
        ),
      );
    }

    if (_homeLoadFailed && _customerId == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.strings.accountLoadFailed,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _loadCustomerData();
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(context.strings.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          bottom: false,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: CustomerMapHome(
                map: BookingMapWidget(
                  pickupLat: _lastLatitudeV37,
                  pickupLng: _lastLongitudeV37,
                ),
                city: _shortPickupLabel,
                locating: _zoneResolving,
                unreadCount: _unreadNotifications,
                onLocate: () => _refreshCurrentCity(force: true),
                onPickup: () => _startProductBooking(
                  BookingAddressSelection(attempt: BookingPerformanceAttempt()),
                  null,
                ),
                onCity: () => showCustomerCitySelectorV38(
                  context,
                  onSelected: (name) {
                    if (!mounted) return;
                    setState(
                      () => _manuallyChosenCityV38 = name.isEmpty ? null : name,
                    );
                    if (name.isEmpty) _refreshCurrentCity(force: true);
                  },
                ),
                onAccount: () => Scaffold.of(context).openDrawer(),
                onNotifications: () async {
                  await context.push(AppRoutes.notifications);
                  if (mounted) await _refreshUnreadNotifications();
                },
                slivers: [
                  if (_hasActiveTrip && _activeTrip != null)
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: HomeActiveTripWidget(
                          activeTrip: _activeTrip!,
                          onTap: () => _startProductBooking(
                            BookingAddressSelection(
                              attempt: BookingPerformanceAttempt(),
                            ),
                            null,
                          ),
                        ),
                      ),
                    ),
                  if (_activeMarketOrder != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.shopping_bag_outlined),
                            title: Text(context.strings.homeActiveOrder),
                            subtitle: Text(
                              _marketOrderStatusText(
                                _activeMarketOrder!['order_status']
                                        ?.toString() ??
                                    'pending',
                              ),
                            ),
                            onTap: () => context.push(
                              AppRoutes.vitoMarketOrderTracking,
                              extra: {
                                'orderId': _activeMarketOrder!['id'].toString(),
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!_hasActiveTrip && _activeMarketOrder == null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: ProductHomePanel(
                          customerId: _customerId,
                          suggestedPickup: _suggestedPickup,
                          pickupCaption: _shortPickupLabel,
                          onStart: _startProductBooking,
                          onMarket: () => context.push(AppRoutes.vitoMarket),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(child: HomePromoWidget()),
                  ),
                  if (_zoneLocationUnavailable && !_zoneResolving)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_off_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'خدمة تحديد الموقع ضعيفة؛ يمكنك المحاولة مجدداً أو تحديد الوجهة يدوياً',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _refreshCurrentCity(force: true),
                                icon: const Icon(Icons.my_location_rounded, size: 16),
                                label: Text(context.strings.retry),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_homeLoadFailed || _marketLoadFailed)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer.withAlpha(50),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.error.withAlpha(80),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.wifi_off_rounded,
                                color: Theme.of(context).colorScheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'تعذر تحديث البيانات، يرجى التحقق من اتصال الإنترنت',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _loadCustomerData,
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: Text(context.strings.retry),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startProductBooking(
    BookingAddressSelection selection,
    String? service,
  ) {
    final active = _activeTrip;
    if (_hasActiveTrip && active != null) {
      final id = active['id']?.toString();
      if (id == null || id.isEmpty) return;
      final assigned =
          active['captain_id'] != null &&
          const {
            'accepted',
            'arriving',
            'arrived',
            'started',
          }.contains(active['trip_status']?.toString());
      context
          .push(
            assigned
                ? '${AppRoutes.liveTrip}?tripId=$id'
                : '${AppRoutes.tripBookingScreen}?resumeTripId=$id',
          )
          .then((_) {
            if (mounted) _loadCustomerData();
          });
      return;
    }
    context
        .push(
          '${AppRoutes.tripBookingScreen}${service == null ? '' : '?service=$service'}',
          extra: selection,
        )
        .then((_) {
          if (mounted) _loadCustomerData();
        });
  }

  String _marketOrderStatusText(String status) => switch (status) {
    'pending' => context.strings.home8e0c6845,
    'confirmed' => context.strings.home797b2da9,
    'preparing' => context.strings.home8594c09a,
    'ready_for_pickup' => context.strings.homee08d6fd7,
    'captain_assigned' => context.strings.home58387cb4,
    'picked_up' => context.strings.homebaac8162,
    'on_the_way' => context.strings.home2f7a3366,
    _ => context.strings.homebae11587,
  };
}
