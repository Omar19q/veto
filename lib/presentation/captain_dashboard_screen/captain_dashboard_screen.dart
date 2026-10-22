import '../../l10n/strings.dart';
import '../../widgets/captain_combo_introduction.dart';
import 'dart:async';
import '../../widgets/trip_safety_code.dart';
import '../../widgets/trip_promise_panel.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../services/captain_tracking_service.dart';
import '../../services/staff_access_v16.dart';
import '../../services/veto_mode_v21.dart';
import '../../services/captain_location_permission_flow.dart';
import '../../services/app_sound_service.dart';
import '../../theme/app_theme.dart';
import '../karizma/karizma_screen.dart';
import './widgets/captain_reward_banner.dart';
import './widgets/captain_fare_preview_widget.dart';
import './widgets/captain_route_preview_v45.dart';
import './widgets/captain_home_map_v30.dart';
import './widgets/captain_more_v32.dart';
import './widgets/captain_presence_card.dart';
import '../../widgets/customer_identity_v29.dart';

bool isFreshCaptainPosition(Position position, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(position.timestamp);
  return age >= const Duration(seconds: -5) &&
      age <= const Duration(seconds: 90) &&
      position.latitude.isFinite &&
      position.longitude.isFinite &&
      position.latitude.abs() <= 90 &&
      position.longitude.abs() <= 180;
}

Future<Position> getCaptainLocationFix({
  Future<Position> Function(LocationSettings)? readCurrent,
  Future<Position?> Function()? readCached,
  bool? web,
}) async {
  final current =
      readCurrent ??
      (settings) => Geolocator.getCurrentPosition(locationSettings: settings);
  final cachedReader = readCached ?? () => Geolocator.getLastKnownPosition();
  try {
    final position = await current(
      const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (!isFreshCaptainPosition(position))
      throw TimeoutException('stale_location');
    return position;
  } on TimeoutException {
    if (!(web ?? kIsWeb)) {
      Position? cached;
      try {
        cached = await cachedReader().timeout(const Duration(seconds: 3));
      } on TimeoutException {
        // Continue with balanced positioning when the cache cannot be read.
      }
      if (cached != null && isFreshCaptainPosition(cached)) return cached;
    }
    final position = await current(
      const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
    if (!isFreshCaptainPosition(position))
      throw TimeoutException('stale_location');
    return position;
  }
}

class CaptainDashboardScreen extends StatefulWidget {
  const CaptainDashboardScreen({super.key});

  @override
  State<CaptainDashboardScreen> createState() => _CaptainDashboardScreenState();
}

class _CaptainDashboardScreenState extends State<CaptainDashboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _screenAwakeChannel = MethodChannel('veto_sanya/screen_awake');
  int _tab = 0;
  late final AnimationController _readyPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _loading = true;
  bool _busy = false;
  String? _lastRatingEventV10;
  bool _offerStateLoading = false;
  bool _offerStateDirty = false;
  Timer? _offerReloadDebounce;
  void _scheduleOfferReload() {
    _offerReloadDebounce ??= Timer(const Duration(milliseconds: 250), () {
      _offerReloadDebounce = null;
      final id = _captain?['id']?.toString();
      if (mounted && id != null)
        unawaited(_reloadOfferAndTripState(id, silent: true));
    });
  }

  bool _appInForegroundV10 = true;
  bool _online = false;
  bool _presenceChanging = false;
  int _presenceRevision = 0;
  bool _presenceDisconnected = false;
  String? _presenceReason;
  final Set<String> _alertedOfferIds = <String>{};
  double _debtThreshold = 150;
  String? _wiredTripId;
  String? _error;
  Map<String, dynamic>? _captain;
  Map<String, dynamic>? _activeTrip;
  Map<String, dynamic>? _marketAssignment;
  List<Map<String, dynamic>> _offers = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _marketHistory = <Map<String, dynamic>>[];
  bool _marketHistoryUnavailable = false;
  bool _offerSyncUnavailableV33 = false;
  List<Map<String, dynamic>> _transactions = <Map<String, dynamic>>[];
  Map<String, dynamic>? _dailySummary;
  List<Map<String, dynamic>> _rewards = <Map<String, dynamic>>[];
  bool _dailyUnavailable = false;
  int _unreadNotifications = 0;
  int _karizmaUnread = 0;
  Timer? _karizmaTimer;
  RealtimeChannel? _karizmaNewsChannel;

  Future<void> _refreshKarizmaUnread() async {
    if (SupabaseService.instance.currentUser == null) return;
    try {
      final count = await SupabaseService.instance.karizmaUnreadV26('captain');
      if (mounted) setState(() => _karizmaUnread = count);
    } catch (_) {
      /* Do not hide a known badge on network errors. */
    }
  }

  RealtimeChannel? _offersChannel;
  String? _boundCaptainV15;
  TripRealtimeLease? _tripChannel;
  RealtimeChannel? _notificationsChannel;
  RealtimeChannel? _statsChannel;
  Timer? _midnightTimer;
  Timer? _metricsRefreshTimer;
  final Map<String, RealtimeChannel> _offerTripChannels =
      <String, RealtimeChannel>{};
  StreamSubscription<Position>? _locationSub;
  StreamSubscription<DateTime>? _serverFixSubV46;
  DateTime? _lastDispatchRecoveryV46;
  bool _dispatchRecoveryBusyV46 = false;
  bool _resumingCaptainV47 = false;
  Timer? _gpsHealthTimerV46;
  DateTime? _gpsMonitorStartedV46;

  Position? _v30MapPosition;
  DateTime? _v30MapRefresh;
  bool _startingLocation = false;
  DateTime? _lastLocationNotice;
  bool _permissionRequestedThisSession = false;
  Timer? _offerPollTimer;
  DateTime? _lastOfferFallbackCheckV34;

  @override
  void initState() {
    super.initState();
    _loadStaffVerifierV21();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refreshKarizmaUnread();
    _karizmaTimer = Timer.periodic(const Duration(seconds: 75), (_) {
      if (_appInForegroundV10) _refreshKarizmaUnread();
    });
    _karizmaNewsChannel = SupabaseService.instance.subscribeToKarizmaNewsV26(
      () => _refreshKarizmaUnread(),
    );
  }

  @override
  void dispose() {
    if (_offersChannel != null)
      unawaited(SupabaseService.instance.client.removeChannel(_offersChannel!));
    _offerReloadDebounce?.cancel();
    _offerReloadDebounce = null;
    _tripChannel?.unsubscribe();
    if (_notificationsChannel != null)
      unawaited(
        SupabaseService.instance.client.removeChannel(_notificationsChannel!),
      );
    if (_statsChannel != null)
      unawaited(SupabaseService.instance.client.removeChannel(_statsChannel!));
    _midnightTimer?.cancel();
    _metricsRefreshTimer?.cancel();
    for (final channel in _offerTripChannels.values) {
      unawaited(SupabaseService.instance.client.removeChannel(channel));
    }
    _offerTripChannels.clear();
    _locationSub?.cancel();
    _serverFixSubV46?.cancel();
    _gpsHealthTimerV46?.cancel();
    _setScreenAwake(false);
    _offerPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _readyPulse.dispose();
    _karizmaTimer?.cancel();
    if (_karizmaNewsChannel != null)
      unawaited(
        SupabaseService.instance.client.removeChannel(_karizmaNewsChannel!),
      );
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWaitingMotion();
  }

  void _syncWaitingMotion() {
    if (MediaQuery.disableAnimationsOf(context) || !_appInForegroundV10) {
      _readyPulse.stop();
      _readyPulse.value = 0.5;
    } else if (!_readyPulse.isAnimating) {
      _readyPulse.repeat(reverse: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForegroundV10 = state == AppLifecycleState.resumed;
    _syncWaitingMotion();
    // Re-read outstanding offers on foreground after missed Realtime events.
    if (state == AppLifecycleState.resumed && mounted) {
      // Restore urgent trips/offers first. Avoid reloading all history, wallet
      // and rewards every time the user switches briefly between apps.
      final captainId = _captain?['id']?.toString();
      if (captainId == null) {
        unawaited(_load());
      } else {
        // A previously-online captain may have an expired GPS fix. Upload and
        // confirm a new fix before requesting nearby offers, not the reverse.
        unawaited(_resumeCaptainV47(captainId));
      }
      unawaited(_refreshKarizmaUnread());
    }
  }

  Future<void> _resumeCaptainV47(String captainId) async {
    if (_resumingCaptainV47 || !mounted) return;
    _resumingCaptainV47 = true;
    try {
      await _refreshPresence();
      if (!mounted || !_appInForegroundV10) return;
      if (_online) {
        final tracker = CaptainTrackingService.instance;
        bool fresh = false;
        if (!tracker.isRunning || _locationSub == null) {
          fresh = await _startLocation(captainId);
        } else {
          fresh = await tracker.refreshNow();
        }
        if (!mounted || !_appInForegroundV10) return;
        if (fresh) {
          await _recoverOffersAfterGpsV46(captainId);
        } else {
          _showLocationNotice(context.strings.captain278d3e8e);
        }
      }
      if (mounted && _appInForegroundV10) {
        await _reloadOfferAndTripState(captainId, silent: true);
      }
    } catch (error) {
      debugPrint('Captain resume V47: $error');
    } finally {
      _resumingCaptainV47 = false;
    }
  }

  Future<void> _load() async {
    final presenceRevision = _presenceRevision;
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) {
        if (mounted) context.go(AppRoutes.signUpLoginScreen);
        return;
      }

      final role = await SupabaseService.instance.getUserRole(user.id);
      if (role != 'captain') {
        if (mounted) context.go(AppRoutes.signUpLoginScreen);
        return;
      }

      final captain = await SupabaseService.instance.getCaptainByUserId(
        user.id,
      );
      if (captain == null) throw Exception('captain_not_found');
      final captainId = captain['id']?.toString();
      if (captainId == null || captainId.isEmpty) {
        throw Exception('captain_id_missing');
      }

      // Prioritize offers and GPS before slower history, wallet and reports.
      // Subscribe exactly once; the existing _subscribe guard handles repeats.
      if (mounted) {
        setState(() {
          _captain = Map<String, dynamic>.from(captain);
          _online = captain['is_online'] == true;
          _loading = false;
        });
        _subscribe(captainId);
        if (_online && !_startingLocation && _locationSub == null) {
          unawaited(_startLocation(captainId));
        }
      }

      final active = await SupabaseService.instance.getActiveTripForCaptain(
        captainId,
      );
      Map<String, dynamic>? marketAssignment;
      try {
        marketAssignment = await SupabaseService.instance
            .getCaptainMarketAssignment();
      } catch (_) {
        // A normal ride remains usable if the market module is unavailable.
      }
      final offers = await _loadPendingOffers(captainId);
      final history = await SupabaseService.instance.getCaptainTrips(
        captainId,
        limit: 50,
      );
      List<Map<String, dynamic>> marketHistory = [];
      bool marketHistoryUnavailable = false;
      try {
        marketHistory = await SupabaseService.instance.getCaptainMarketHistory(
          limit: 50,
        );
      } catch (_) {
        marketHistoryUnavailable = true;
      }
      final txs = await SupabaseService.instance.getCaptainTransactions(
        captainId,
        limit: 100,
      );
      // Never approximate today's data from the most recent 50 trips.
      Map<String, dynamic>? daily;
      List<Map<String, dynamic>> rewards = <Map<String, dynamic>>[];
      int unread = 0;
      try {
        daily = await SupabaseService.instance.getCaptainDailySummaryV22();
      } catch (_) {
        daily = null;
      }
      try {
        rewards = await SupabaseService.instance.getMyCaptainRewardsV22();
      } catch (_) {
        /* Rewards never block existing trip functions. */
      }
      try {
        unread = await SupabaseService.instance.getUnreadNotificationCount(
          user.id,
        );
      } catch (_) {
        unread = _unreadNotifications;
      }
      double threshold = (captain['debt_threshold'] as num?)?.toDouble() ?? 150;
      try {
        final service = captain['vehicle_type']?.toString() == 'motorcycle'
            ? 'motorcycle_ride'
            : 'car_ride';
        final pricing = await SupabaseService.instance.getServicePricingFromRpc(
          service,
        );
        final configured = pricing?['captain_debt_threshold'];
        if (configured is num) threshold = configured.toDouble();
      } catch (_) {
        // The captain's stored limit remains a display fallback.
      }

      final valid = offers.where(isLiveCaptainOffer).toList();

      if (!mounted) return;
      setState(() {
        if (!_presenceChanging && presenceRevision == _presenceRevision) {
          _captain = Map<String, dynamic>.from(captain);
        }
        _activeTrip = active == null ? null : Map<String, dynamic>.from(active);
        _marketAssignment = marketAssignment;
        _offers = valid;
        _history = history;
        _marketHistory = marketHistory;
        _marketHistoryUnavailable = marketHistoryUnavailable;
        _transactions = txs;
        _dailySummary = daily;
        _dailyUnavailable = daily == null;
        _rewards = rewards;
        _unreadNotifications = unread;
        if (!_presenceChanging && presenceRevision == _presenceRevision) {
          _online = captain['is_online'] == true;
        }
        _debtThreshold = threshold;
        _loading = false;
        _error = null;
      });

      _scheduleComboIntroduction();
      _syncScreenAwake();
      if (!_permissionRequestedThisSession) {
        _permissionRequestedThisSession = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _ensureLocationPermission(showErrors: false);
        });
      }

      _scheduleMidnightRefresh();
      if (!_online) {
        await CaptainTrackingService.instance.stop();
        await _locationSub?.cancel();
        _locationSub = null;
        await _serverFixSubV46?.cancel();
        _serverFixSubV46 = null;
        _gpsHealthTimerV46?.cancel();
        _gpsHealthTimerV46 = null;
      }
      if (_online &&
          !_busy &&
          !_startingLocation &&
          (_locationSub == null ||
              !CaptainTrackingService.instance.isRunning)) {
        unawaited(_startLocation(captainId));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = context.strings.captainf6174ae5;
        });
        _syncScreenAwake();
      }
    }
  }

  Future<void> _refreshDashboardMetrics() async {
    if (!mounted) return;
    Map<String, dynamic>? daily;
    List<Map<String, dynamic>>? rewards;
    int? unread;
    try {
      daily = await SupabaseService.instance.getCaptainDailySummaryV22();
    } catch (_) {
      daily = null;
    }
    try {
      rewards = await SupabaseService.instance.getMyCaptainRewardsV22();
    } catch (_) {
      /* Keep last known reward list if temporarily offline. */
    }
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId != null) {
      try {
        unread = await SupabaseService.instance.getUnreadNotificationCount(
          userId,
        );
      } catch (_) {
        /* Retain badge until the next fetch. */
      }
    }
    if (!mounted) return;
    setState(() {
      _dailySummary = daily;
      _dailyUnavailable = daily == null;
      if (rewards != null) _rewards = rewards;
      if (unread != null) _unreadNotifications = unread;
    });
    _scheduleMidnightRefresh();
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final raw = _dailySummary?['next_midnight']?.toString();
    final next = DateTime.tryParse(raw ?? '');
    final delay = next?.difference(DateTime.now());
    // Server supplies Africa/Cairo midnight with its proper UTC offset.
    final safeDelay = delay == null || delay.isNegative
        ? const Duration(minutes: 1)
        : delay + const Duration(seconds: 1);
    _midnightTimer = Timer(safeDelay, () {
      _refreshDashboardMetrics();
    });
  }

  Future<void> _openNotifications() async {
    await context.push(AppRoutes.notifications);
    if (mounted) await _refreshDashboardMetrics();
  }

  DateTime? _ratingSyncSinceV11;
  bool _ratingSyncingV11 = false;
  void _receiveRatingV11(Map<String, dynamic> row) {
    if (!mounted) return;
    final data = row['data'];
    if (data is! Map ||
        data['rating_stars'] == null ||
        data['rating_event_id']?.toString() == _lastRatingEventV10)
      return;
    _lastRatingEventV10 = data['rating_event_id']?.toString();
    _show(context.strings.captainHomeNewRating('${data['rating_stars']}'));
  }

  Future<void> _resyncRatingsV11() async {
    if (_ratingSyncingV11 || !mounted) return;
    _ratingSyncingV11 = true;
    final userId = SupabaseService.instance.currentUser?.id;
    final since = _ratingSyncSinceV11 ?? DateTime.now().toUtc();
    try {
      if (userId == null) return;
      final rows = await SupabaseService.instance.client
          .from('notifications')
          .select('id,created_at,data')
          .eq('user_id', userId)
          .gte('created_at', since.toIso8601String())
          .order('created_at', ascending: false)
          .limit(100);
      if (!mounted || SupabaseService.instance.currentUser?.id != userId)
        return;
      // One animation for the latest missed rating; stats refresh restores the aggregate.
      final ratings = rows.where(
        (row) =>
            row['data'] is Map && (row['data'] as Map)['rating_stars'] != null,
      );
      if (ratings.isNotEmpty)
        _receiveRatingV11(Map<String, dynamic>.from(ratings.first));
      if (rows.isNotEmpty)
        _ratingSyncSinceV11 =
            DateTime.tryParse('${rows.first['created_at']}')?.toUtc() ?? since;
      await _refreshDashboardMetrics();
    } catch (_) {
      /* Reconnect/resume retries without periodic requests. */
    } finally {
      _ratingSyncingV11 = false;
    }
  }

  void _subscribe(String captainId) {
    if (_boundCaptainV15 == captainId && _offersChannel != null) {
      _wireActiveTripRealtime();
      return;
    }
    _boundCaptainV15 = captainId;
    _ratingSyncSinceV11 ??= DateTime.now().toUtc();
    if (_notificationsChannel != null)
      unawaited(
        SupabaseService.instance.client.removeChannel(_notificationsChannel!),
      );
    if (_statsChannel != null)
      unawaited(SupabaseService.instance.client.removeChannel(_statsChannel!));
    _notificationsChannel = SupabaseService.instance
        .subscribeToNotificationChanges(
          SupabaseService.instance.currentUser!.id,
          (row) {
            if (!mounted) return;
            _receiveRatingV11(row);
            if (row['notification_type'] == 'trip_completed' ||
                row['notification_type'] == 'rating') {
              _refreshDashboardMetrics();
            }
          },
          onReconnect: () => _resyncRatingsV11(),
        );
    _statsChannel = SupabaseService.instance.subscribeToCaptainTripStats(
      captainId,
      (trip) {
        if (!mounted) return;
        if (trip['trip_status']?.toString() == 'completed') {
          _refreshDashboardMetrics();
        }
      },
    );
    if (_offersChannel != null)
      unawaited(SupabaseService.instance.client.removeChannel(_offersChannel!));
    _tripChannel?.unsubscribe();
    _wiredTripId = null;

    _offersChannel = SupabaseService.instance.subscribeToCaptainOffers(
      captainId,
      (event) async {
        if (!mounted) return;
        final connection = event['_realtime_connection'];
        if (connection != null) {
          setState(() => _presenceDisconnected = connection != 'subscribed');
          return;
        }
        final reconnectSync = event['_realtime_sync'] == true;
        if (reconnectSync && !_presenceChanging)
          unawaited(
            _refreshPresence().catchError((Object _) {
              if (mounted) setState(() => _presenceDisconnected = true);
            }),
          );
        if (!reconnectSync &&
            event['_offer_changed'] != true &&
            event['id'] != null &&
            _alertedOfferIds.add(event['id'].toString())) {
          if (_alertedOfferIds.length > 200)
            _alertedOfferIds.remove(_alertedOfferIds.first);
          HapticFeedback.mediumImpact();
          await AppSoundService.instance.playOffer();
        }
        _scheduleOfferReload();
      },
    );

    _wireActiveTripRealtime();
    _startOfferFallbackPolling(captainId);
    _metricsRefreshTimer?.cancel();
    _metricsRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _refreshDashboardMetrics();
    });
  }

  void _startOfferFallbackPolling(String captainId) {
    _offerPollTimer?.cancel();
    // Realtime handles the fast path. Polling is a safety net on connection
    // loss, not a second full-time listener competing for network resources.
    _offerPollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted ||
          !_online ||
          _busy ||
          _activeTrip != null ||
          !_appInForegroundV10 ||
          _offerStateLoading)
        return;
      final now = DateTime.now();
      final interval = _presenceDisconnected
          ? const Duration(seconds: 10)
          : const Duration(seconds: 12);
      if (_lastOfferFallbackCheckV34 != null &&
          now.difference(_lastOfferFallbackCheckV34!) < interval)
        return;
      _lastOfferFallbackCheckV34 = now;
      await _reloadOfferAndTripState(captainId, silent: true);
    });
  }

  Future<void> _reloadOfferAndTripState(
    String captainId, {
    bool silent = false,
  }) async {
    if (_offerStateLoading) {
      _offerStateDirty = true;
      return;
    }
    _offerStateLoading = true;
    try {
      final active = await SupabaseService.instance.getActiveTripForCaptain(
        captainId,
      );
      final offers = await _loadPendingOffers(captainId);
      if (mounted && _offerSyncUnavailableV33) {
        setState(() => _offerSyncUnavailableV33 = false);
      }
      Map<String, dynamic>? marketAssignment;
      try {
        marketAssignment = await SupabaseService.instance
            .getCaptainMarketAssignment();
      } catch (_) {
        marketAssignment = _marketAssignment;
      }
      if (!mounted) return;
      final nextOffers = offers.where(isLiveCaptainOffer).toList();
      if (!silent ||
          jsonEncode(nextOffers) != jsonEncode(_offers) ||
          jsonEncode(active) != jsonEncode(_activeTrip) ||
          jsonEncode(marketAssignment) != jsonEncode(_marketAssignment)) {
        final isNewMarket =
            marketAssignment?['status'] == 'accepted' &&
            marketAssignment?['id'] != _marketAssignment?['id'];
        setState(() {
          _activeTrip = active == null
              ? null
              : Map<String, dynamic>.from(active);
          _offers = nextOffers;
          _marketAssignment = marketAssignment;
        });
        if (isNewMarket) {
          HapticFeedback.mediumImpact();
          AppSoundService.instance.playOffer();
        }
        _syncScreenAwake();
      }
      _scheduleComboIntroduction();
      _syncOfferTripRealtime();
      _wireActiveTripRealtime();
    } catch (_) {
      // The read-only offers RPC may be unavailable even when presence is online.
      if (mounted && !_offerSyncUnavailableV33) {
        setState(() => _offerSyncUnavailableV33 = true);
      }
    } finally {
      _offerStateLoading = false;
      if (_offerStateDirty && mounted) {
        _offerStateDirty = false;
        _scheduleOfferReload();
      }
    }
  }

  void _syncOfferTripRealtime() {
    final ids =
        _offers
            .map((o) => o['trip_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final groups = <String, List<String>>{};
    for (var i = 0; i < ids.length; i += 100) {
      final group = ids.sublist(i, (i + 100).clamp(0, ids.length));
      groups[group.join(',')] = group;
    }
    for (final key in _offerTripChannels.keys.toList()) {
      if (!groups.containsKey(key)) {
        final old = _offerTripChannels.remove(key);
        if (old != null)
          unawaited(SupabaseService.instance.client.removeChannel(old));
      }
    }
    for (final entry in groups.entries) {
      if (_offerTripChannels.containsKey(entry.key)) continue;
      _offerTripChannels[entry.key] = SupabaseService.instance.client
          .channel(
            'offered_trip_group_${DateTime.now().microsecondsSinceEpoch}',
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'trips',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.inFilter,
              column: 'id',
              value: entry.value,
            ),
            callback: (_) => _scheduleOfferReload(),
          )
          .subscribe((status, _) {
            if (status == RealtimeSubscribeStatus.subscribed)
              _scheduleOfferReload();
          });
    }
  }

  void _wireActiveTripRealtime() {
    final activeId = _activeTrip?['id']?.toString();
    if (activeId == _wiredTripId) return;
    _tripChannel?.unsubscribe();
    _wiredTripId = activeId;
    if (activeId == null) return;
    _tripChannel = SupabaseService.instance.subscribeToTripStatus(activeId, (
      trip,
    ) async {
      if (!mounted) return;
      final status = trip['trip_status']?.toString();
      setState(() {
        _activeTrip = (status == 'completed' || status == 'cancelled')
            ? null
            : Map<String, dynamic>.from(trip);
      });
      if (status == 'completed' || status == 'cancelled') {
        await _load();
      }
      _syncScreenAwake();
    });
  }

  Future<List<Map<String, dynamic>>> _loadPendingOffers(
    String captainId,
  ) async {
    try {
      return await SupabaseService.instance.getPendingOffersForCaptain(
        captainId,
      );
    } catch (error) {
      // Do not silently replace a failed security-controlled RPC with an
      // unrestricted table query. Make the actual failure visible on load.
      throw Exception('pending_offers_failed: $error');
    }
  }

  // The caller cannot SELECT an unassigned trip directly under trips RLS.
  // Check the captain-scoped offers RPC here; the accept RPC remains the
  // authoritative atomic validation and assignment.
  Future<bool> _isOfferCurrentlyValid(String offerId, String captainId) async {
    final offers = await SupabaseService.instance.getPendingOffersForCaptain(
      captainId,
    );
    return offers.any(
      (o) =>
          o['id']?.toString() == offerId &&
          o['offer_status']?.toString() == 'sent',
    );
  }

  // A captain can be marked online even though their last GPS fix is stale.
  // Refresh already existing offers only AFTER the server confirms a fresh fix.
  // Optional RPC is throttled on the server too; if V46 SQL is not installed,
  // normal Realtime and the existing fallback remain available.
  Future<void> _recoverOffersAfterGpsV46(String captainId) async {
    if (!mounted ||
        !_appInForegroundV10 ||
        !_online ||
        _dispatchRecoveryBusyV46)
      return;
    final now = DateTime.now();
    if (_lastDispatchRecoveryV46 != null &&
        now.difference(_lastDispatchRecoveryV46!) < const Duration(seconds: 25))
      return;
    _lastDispatchRecoveryV46 = now;
    _dispatchRecoveryBusyV46 = true;
    try {
      try {
        await SupabaseService.instance.client
            .rpc(
              'captain_resume_dispatch_v46',
              params: {'p_captain_id': captainId},
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // Do not block incoming offers when SQL has not yet been installed.
      }
      await _reloadOfferAndTripState(captainId, silent: true);
    } finally {
      _dispatchRecoveryBusyV46 = false;
    }
  }

  Future<void> _refreshPresence() async {
    final presenceRevision = _presenceRevision;
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;
    final captain = await SupabaseService.instance.getCaptainByUserId(user.id);
    if (captain == null || !mounted || presenceRevision != _presenceRevision)
      return;
    setState(() {
      _captain = Map<String, dynamic>.from(captain);
      _online = captain['is_online'] == true;
      _presenceReason = null;
    });
  }

  Future<void> _toggleOnline() async {
    if (_captain == null || _presenceChanging) return;
    if (_busy) {
      _show(context.strings.captain5d90693a);
      return;
    }
    setState(() {
      _presenceRevision++;
      _presenceChanging = true;
      _presenceReason = null;
    });
    final next = !_online;
    var mutationAttempted = false;
    var onlineStatusConfirmed = false;
    try {
      if (next) {
        final permissionReady = await _ensureLocationPermission(
          showErrors: true,
        );
        if (!permissionReady) {
          if (mounted)
            setState(() => _presenceReason = context.strings.captain0e3338be);
          return;
        }
        final locationReady = await _startLocation(_captain!['id'].toString());
        if (!locationReady) {
          if (mounted)
            setState(() => _presenceReason = context.strings.captain13e4b9b7);
          return;
        }
      }
      // V15 RPC remains the sole authority for debt, approval and active jobs.
      mutationAttempted = true;
      await SupabaseService.instance.updateCaptainOnlineStatus(
        _captain!['id'].toString(),
        next,
      );
      onlineStatusConfirmed = true;
      // Read only the captain, never the complete dashboard, after confirmation.
      await _refreshPresence();
      if (next && _online && mounted) {
        unawaited(_recoverOffersAfterGpsV46(_captain!['id'].toString()));
      }
      if (!_online) {
        await CaptainTrackingService.instance.stop();
        await _locationSub?.cancel();
        _locationSub = null;
        await _serverFixSubV46?.cancel();
        _serverFixSubV46 = null;
        _gpsHealthTimerV46?.cancel();
        _gpsHealthTimerV46 = null;
      }
      _syncScreenAwake();
      _scheduleOfferReload();
    } catch (e) {
      final message = e.toString();
      final reason = next && message.contains('debt_limit_reached')
          ? context.strings.captain199848b2
          : message.contains('active_trip_in_progress')
          ? context.strings.captain9c360bcd
          : message.contains('captain_inactive')
          ? context.strings.captain37cdd354
          : message.contains('captain_banned')
          ? context.strings.captain0028fab8
          : _captainServerError(e, changingOnlineStatus: true);
      if (mounted)
        setState(() {
          _presenceReason = reason;
          _presenceDisconnected =
              e is! PostgrestException &&
              !message.contains('captain_') &&
              !message.contains('debt_limit') &&
              !message.contains('active_trip');
        });
      _show(reason);
      if (next && message.contains('debt_limit_reached') && mounted) {
        context.push(AppRoutes.captainDebtInvoice);
      }
    } finally {
      // The tracker starts before the online RPC so a fresh GPS fix is ready.
      // If the server rejects going online (e.g. debt/approval), turn off the
      // location foreground service immediately; never track an offline driver.
      if ((next && !onlineStatusConfirmed) ||
          (!mutationAttempted && !_online)) {
        await CaptainTrackingService.instance.stop();
        await _locationSub?.cancel();
        _locationSub = null;
        await _serverFixSubV46?.cancel();
        _serverFixSubV46 = null;
        _gpsHealthTimerV46?.cancel();
        _gpsHealthTimerV46 = null;
      }
      if (mounted) setState(() => _presenceChanging = false);
    }
  }

  Future<bool> _ensureLocationPermission({required bool showErrors}) async {
    if (!mounted) return false;
    return CaptainLocationPermissionFlow.request(
      context,
      explainAlways: showErrors,
    );
  }

  Future<bool> _startLocation(String captainId) async {
    // A running stream does not imply that Supabase accepted a recent fix.
    if (_locationSub != null && CaptainTrackingService.instance.isRunning) {
      return CaptainTrackingService.instance.refreshNow();
    }
    if (_startingLocation || !mounted) return false;
    _startingLocation = true;
    bool uploading = false;
    try {
      // Automatic restore/resume must not reopen a blocking settings dialog.
      // The explicit online action already requests permission with explanation.
      if (!await _ensureLocationPermission(showErrors: false)) return false;

      // A one-shot fix must not start the background tracking service.
      final position = await _getFreshPosition();
      if (!mounted) return false;
      uploading = true;
      await SupabaseService.instance
          .updateCaptainLocation(
            captainId,
            position.latitude,
            position.longitude,
          )
          .timeout(const Duration(seconds: 15));
      uploading = false;
      if (!mounted) return false;
      setState(() => _v30MapPosition = position);
      await CaptainTrackingService.instance.start(captainId);
      _gpsMonitorStartedV46 = DateTime.now();
      _gpsHealthTimerV46?.cancel();
      _gpsHealthTimerV46 = Timer.periodic(const Duration(seconds: 45), (
        _,
      ) async {
        if (!mounted || !_appInForegroundV10 || !_online) return;
        final last = CaptainTrackingService.instance.lastServerFix;
        final started = _gpsMonitorStartedV46;
        // Refresh only the presentation of readiness, without changing online
        // status, tracking cadence or server distribution eligibility.
        if (mounted) setState(() {});
        if (last != null &&
            DateTime.now().difference(last) < const Duration(seconds: 100))
          return;
        if (started != null &&
            DateTime.now().difference(started) < const Duration(seconds: 100))
          return;
        final ok = await CaptainTrackingService.instance.refreshNow();
        if (!ok && mounted && _online) {
          _showLocationNotice(context.strings.captain20d90f0e);
        }
      });
      await _serverFixSubV46?.cancel();
      _serverFixSubV46 = CaptainTrackingService.instance.serverFixes.listen((
        _,
      ) {
        if (mounted && _online) {
          unawaited(_recoverOffersAfterGpsV46(captainId));
        }
      });
      // On a fresh login, a one-shot GPS fix was already saved above.
      if (_online) unawaited(_recoverOffersAfterGpsV46(captainId));
      await _locationSub?.cancel();
      _locationSub = CaptainTrackingService.instance.positions.listen(
        (position) {
          // UI-only map marker. Location uploads remain in tracking service.
          if (!mounted || !isFreshCaptainPosition(position)) return;
          final now = DateTime.now();
          if (_v30MapRefresh != null &&
              now.difference(_v30MapRefresh!) < const Duration(seconds: 5))
            return;
          _v30MapRefresh = now;
          setState(() => _v30MapPosition = position);
        },
        onError: (Object error) {
          _showLocationNotice(_captainLocationError(error));
        },
        onDone: () {
          _locationSub = null;
        },
        cancelOnError: false,
      );
      return true;
    } catch (error) {
      if (mounted) {
        _show(
          uploading ? _captainServerError(error) : _captainLocationError(error),
        );
      }
      return false;
    } finally {
      _startingLocation = false;
    }
  }

  Future<Position> _getFreshPosition() async {
    return getCaptainLocationFix();
  }

  void _showLocationNotice(String message) {
    if (!mounted) return;
    final last = _lastLocationNotice;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 1))
      return;
    _lastLocationNotice = DateTime.now();
    _show(message);
  }

  String _captainLocationError(Object error) {
    if (error is LocationServiceDisabledException) {
      return context.strings.captaineaa58c01;
    }
    if (error is PermissionDeniedException) {
      return context.strings.captainae5e5078;
    }
    if (error is TimeoutException) {
      return context.strings.captainb91e4e01;
    }
    return context.strings.captain4d71e045;
  }

  String _captainServerError(
    Object error, {
    bool changingOnlineStatus = false,
  }) {
    final message = error.toString().toLowerCase();
    if (message.contains('stale') ||
        message.contains('session_expired') ||
        message.contains('jwt expired') ||
        message.contains('session_not_active')) {
      return context.strings.captain0c8c1ed6;
    }
    if (error is PostgrestException) {
      if (error.code == 'PGRST202' ||
          error.code == 'PGRST203' ||
          error.code == '42883') {
        return context.strings.captainHomeMissingRpc(error.code ?? 'unknown');
      }
      if (error.code == '42501' ||
          error.code == 'PGRST301' ||
          message.contains('forbidden')) {
        return context.strings.captain6779d8a9;
      }
      return context.strings.captainHomeServerSave(
        changingOnlineStatus
            ? context.strings.captainHomed528cf79
            : context.strings.captainHome8937faa1,
        error.code ?? context.strings.captainHome5a0374f3,
      );
    }
    if (message.contains('forbidden') || message.contains('unauthorized')) {
      return context.strings.captain1c8a49fe;
    }
    return changingOnlineStatus
        ? context.strings.captain96de460e
        : context.strings.captain07ec3438;
  }

  void _syncScreenAwake() {
    // Keep the display awake only while waiting online for an incoming job.
    _setScreenAwake(
      _online && _captain?['is_available'] == true && _activeTrip == null,
    );
  }

  Future<void> _setScreenAwake(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _screenAwakeChannel.invokeMethod<void>('setEnabled', enabled);
    } catch (_) {
      // A missing native implementation must not break captain operations.
    }
  }

  bool _comboPrompting = false;
  bool _comboCheckedThisSession = false;
  void _scheduleComboIntroduction() {
    if (_comboPrompting ||
        _comboCheckedThisSession ||
        _captain == null ||
        _activeTrip != null)
      return;
    if (!_offers.any(
      (o) =>
          o['trips'] is Map &&
          (o['trips']['extra_requests']?.toString().trim() ?? '').isNotEmpty,
    ))
      return;
    _comboPrompting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (mounted)
          _comboCheckedThisSession = await CaptainComboIntroduction.ensure(
            context,
            _captain!['id'].toString(),
          );
      } catch (_) {
        if (mounted) _show(context.strings.captain4d8aa1e0);
      } finally {
        _comboPrompting = false;
      }
    });
  }

  Future<void> _acceptOffer(Map<String, dynamic> offer) async {
    if (_captain == null || _activeTrip != null || _busy || _presenceChanging) {
      _show(context.strings.captain4bd12227);
      return;
    }
    final oid = offer['id']?.toString();
    final tripId = offer['trip_id']?.toString();
    final captainId = _captain!['id']?.toString();
    if (oid == null || tripId == null || captainId == null) return;
    if (!isLiveCaptainOffer(offer)) {
      _show(context.strings.captain961fe263);
      return;
    }

    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final tripData = offer['trips'];
      if (tripData is Map &&
          (tripData['extra_requests']?.toString().trim() ?? '').isNotEmpty) {
        if (!await CaptainComboIntroduction.ensure(context, captainId)) return;
        if (!mounted) return;
      }
      if (!await _isOfferCurrentlyValid(oid, captainId)) {
        setState(() => _offers.removeWhere((o) => o['id']?.toString() == oid));
        _show(context.strings.captaind292c0f8);
        return;
      }
      await SupabaseService.instance.acceptCaptainOffer(oid, tripId, captainId);
      final active = <String, dynamic>{
        ...Map<String, dynamic>.from((offer['trips'] as Map?) ?? {}),
        'id': tripId,
        'captain_id': captainId,
        'trip_status': 'accepted',
      };
      if (mounted) {
        setState(() {
          _offers.removeWhere((o) => o['id']?.toString() == oid);
          _activeTrip = Map<String, dynamic>.from(active);
        });
        _syncScreenAwake();
        HapticFeedback.heavyImpact();
        await AppSoundService.instance.playSuccess();
        _show(context.strings.captain61f278b9);
        _wireActiveTripRealtime();
        if (mounted) {
          context.push('${AppRoutes.captainLiveTrip}?tripId=$tripId');
        }
      }
    } catch (e) {
      final err = e.toString().replaceFirst('Exception: ', '');
      if (err.contains('trip_taken_by_other_captain')) {
        _show(context.strings.captain6aad32b8);
      } else if (err.contains('captain_already_busy')) {
        _show(context.strings.captaine28fe29b);
      } else {
        _show(context.strings.captain817dceb0);
      }
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _declineOffer(Map<String, dynamic> offer) async {
    if (_captain == null || _busy || _presenceChanging) return;
    final oid = offer['id']?.toString();
    final status = offer['offer_status']?.toString();
    if (oid == null || status != 'sent') return;
    setState(() => _busy = true);
    try {
      await SupabaseService.instance.declineCaptainTripOffer(
        oid,
        _captain!['id'].toString(),
      );
      if (mounted)
        setState(() => _offers.removeWhere((o) => o['id']?.toString() == oid));
    } catch (e) {
      _show(context.strings.captain3e4011c0);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeTripStatus(String next) async {
    final id = _activeTrip?['id']?.toString();
    if (id == null || _busy || _presenceChanging) return;

    setState(() => _busy = true);
    try {
      await SupabaseService.instance.advanceTripStatus(id, next);

      if (next == 'completed') {
        final invoice = await SupabaseService.instance.getTripById(id);
        if (mounted && invoice != null) {
          await _showCaptainInvoice(invoice);
        }
        // No second modal: rating is prompted only at trip completion.
      }

      await _load();
    } catch (_) {
      _show(context.strings.captain9947a71a);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showCaptainInvoice(Map<String, dynamic> trip) async {
    final tripId = trip['id']?.toString();
    if (tripId == null || tripId.isEmpty) return;
    try {
      final response = await SupabaseService.instance.getTripInvoice(tripId);
      final dbTrip = <String, dynamic>{
        ...trip,
        if (response['trip'] is Map)
          ...Map<String, dynamic>.from(response['trip'] as Map),
      };
      final details = response['invoice'] is Map
          ? Map<String, dynamic>.from(response['invoice'] as Map)
          : <String, dynamic>{};

      Object? field(List<String> keys) {
        for (final key in keys) {
          if (details[key] != null) return details[key];
          if (dbTrip[key] != null) return dbTrip[key];
          if (response[key] != null) return response[key];
        }
        return null;
      }

      String money(List<String> keys) {
        final raw = field(keys);
        final amount = raw is num
            ? raw.toDouble()
            : double.tryParse(raw?.toString() ?? '');
        return amount == null
            ? context.strings.captain82963d4d
            : context.strings.moneyValue(amount.toStringAsFixed(2));
      }

      final customer = dbTrip['customers'];
      final customerName =
          field(['customer_name'])?.toString() ??
          (customer is Map ? customer['full_name']?.toString() : null) ??
          '—';
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Directionality(
          textDirection: Directionality.of(context),
          child: AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              context.strings.captain583a75cf,
              style: TextStyle(
                
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.strings.captainHomeCustomer(customerName),
                    style: TextStyle(
                      
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF332807), Color(0xFF18263C)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          context.strings.captainfee7f899,
                          style: TextStyle(
                            
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          money(['cash_collected', 'cash_amount']),
                          style: TextStyle(
                            
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          context.strings.captaind922438f,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _invoiceRow(
                    context.strings.captain7f29d28a,
                    money(['base_fare']),
                  ),
                  _invoiceRow(
                    context.strings.captaine8ea6cc8,
                    money(['waiting_charge']),
                  ),
                  _invoiceRow(
                    context.strings.captainb593a645,
                    money(['promo_discount']),
                  ),
                  _invoiceRow(
                    context.strings.captain48f62d04,
                    money(['incentive_total', 'incentive_amount']),
                  ),
                  _invoiceRow(
                    context.strings.captaind8148f15,
                    money([
                      'previous_due_collected',
                      'previous_due',
                      'customer_previous_due',
                    ]),
                  ),
                  const Divider(),
                  _invoiceRow(
                    context.strings.captaindf9cee25,
                    money(['customer_total', 'total_fare']),
                    strong: true,
                  ),
                  _invoiceRow(
                    context.strings.captainccfb9ede,
                    money(['wallet_used', 'wallet_amount']),
                  ),
                  _invoiceRow(
                    context.strings.captain8b296d76,
                    money(['cash_collected', 'cash_amount']),
                    strong: true,
                  ),
                  const Divider(),
                  _invoiceRow(
                    context.strings.captain3bdc9404,
                    money(['commission', 'commission_amount']),
                  ),
                  _invoiceRow(
                    context.strings.captain79fe765a,
                    money([
                      'company_incentive',
                      'company_incentive_amount',
                      'incentive_company_share',
                    ]),
                  ),
                  _invoiceRow(
                    context.strings.captainc3b788c0,
                    money([
                      'captain_incentive',
                      'captain_incentive_amount',
                      'incentive_captain_share',
                    ]),
                  ),
                  _invoiceRow(
                    context.strings.captain986f250b,
                    money(['captain_earnings']),
                    strong: true,
                  ),
                  _invoiceRow(
                    context.strings.captaind3aa4069,
                    money([
                      'captain_settlement_delta',
                      'settlement_delta',
                      'financial_settlement_change',
                    ]),
                  ),
                  _invoiceRow(
                    context.strings.captain233aea82,
                    money(['captain_settlement_after']),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: AppTheme.primary,
                ),
                child: Text(
                  context.strings.captain3ef541b9,
                  style: TextStyle(),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      _show(context.strings.captainaa0eba0d);
    }
  }

  Widget _invoiceRow(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                
                color: strong
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                fontSize: strong ? 14 : 12,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              
              color: strong
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: strong ? 16 : 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _callNumber(String phone) async {
    final clean = phone.trim();
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (!await launchUrl(uri, mode: LaunchMode.platformDefault))
      _show(context.strings.captaindb6c6f4e);
  }

  Future<void> _showSupport() async {
    String phone = '';
    String whatsapp = '';
    try {
      phone =
          (await SupabaseService.instance.getSetting(
            'captain_support_phone',
          ))?.trim() ??
          '';
      whatsapp =
          (await SupabaseService.instance.getSetting(
            'captain_support_whatsapp',
          ))?.trim() ??
          '';
      if (phone.isEmpty)
        phone =
            (await SupabaseService.instance.getSetting(
              'customer_service_phone',
            ))?.trim() ??
            '';
      if (whatsapp.isEmpty)
        whatsapp =
            (await SupabaseService.instance.getSetting(
              'customer_service_whatsapp',
            ))?.trim() ??
            '';
    } catch (_) {}

    if (!mounted) return;
    if (phone.isEmpty && whatsapp.isEmpty) {
      _show(context.strings.captain2b50d9f0);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final rawWa = whatsapp.replaceAll(RegExp(r'\D'), '');
        final international = rawWa.isEmpty
            ? ''
            : (rawWa.startsWith('20')
                  ? rawWa
                  : '20${rawWa.replaceFirst(RegExp(r'^0+'), '')}');
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Directionality(
              textDirection: Directionality.of(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.strings.captainc3bb52b7,
                    style: TextStyle(
                      
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (phone.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _callNumber(phone);
                        },
                        icon: const Icon(Icons.call_rounded),
                        label: Text(
                          context.strings.captainebfead75,
                          style: TextStyle(
                            
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  if (international.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          final uri = Uri.parse('https://wa.me/$international');
                          if (!await launchUrl(
                                uri,
                                mode: LaunchMode.platformDefault,
                              ) &&
                              mounted) {
                            _show(context.strings.captain56a1b88a);
                          }
                        },
                        icon: const Icon(
                          Icons.chat_rounded,
                          color: AppTheme.whatsapp,
                        ),
                        label: const Text(
                          'WhatsApp',
                          style: TextStyle(
                            
                            fontWeight: FontWeight.w800,
                            color: AppTheme.whatsapp,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle()),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }
    if (_error != null) {
      return Directionality(
        textDirection: Directionality.of(context),
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppTheme.errorLight,
                    size: 46,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _load,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: AppTheme.primary,
                    ),
                    child: Text(
                      context.strings.captain14d5786f,
                      style: TextStyle(),
                    ),
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
          child: IndexedStack(
            index: _tab,
            children: [
              _homePage(),
              _tripsPage(),
              _walletPage(),
              KarizmaScreen(audience: 'captain', visible: _tab == 3),
              _morePage(),
            ],
          ),
        ),
        bottomNavigationBar: _captainDock(),
      ),
    );
  }

  Widget _captainDock() {
    final items = <(IconData, String)>[
      (Icons.space_dashboard_rounded, context.strings.captainbfcf4830),
      (Icons.route_rounded, context.strings.captainf3683943),
      (Icons.account_balance_wallet_rounded, context.strings.captain166aea7d),
      (Icons.newspaper_rounded, context.strings.captain62d6fd3d),
      (Icons.grid_view_rounded, context.strings.captain478c486f),
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF121A2B)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? const Color(0xFF29344D)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x66000000) : Colors.black.withAlpha(20),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: items.indexed.map((entry) {
            final index = entry.$1;
            final item = entry.$2;
            final selected = _tab == index;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() {
                  _tab = index;
                  if (index == 3) _karizmaUnread = 0;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedScale(
                            duration: const Duration(milliseconds: 220),
                            scale: selected ? 1.12 : 1,
                            child: Icon(
                              item.$1,
                              size: 22,
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (index == 3 && _karizmaUnread > 0)
                            const Positioned(
                              top: -3,
                              left: -5,
                              child: CircleAvatar(
                                radius: 4,
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$2,
                        maxLines: 1,
                        style: TextStyle(
                          
                          fontSize: 9.5,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _homePage() {
    final rating = (_captain?['rating'] as num?)?.toDouble() ?? 0;
    final todayTrips = (_dailySummary?['today_trips'] as num?)?.toInt() ?? 0;
    final todayEarnings =
        (_dailySummary?['today_earnings'] as num?)?.toDouble() ?? 0;
    final missingEarnings =
        (_dailySummary?['missing_earnings'] as num?)?.toInt() ?? 0;
    final settlement = (_captain?['settlement_debt'] as num?)?.toDouble() ?? 0;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          if (_offerSyncUnavailableV33)
            MaterialBanner(
              content: Text(
                context.strings.captain2443fd0d,
                style: TextStyle( color: Colors.white),
              ),
              backgroundColor: const Color(0xFF443018),
              actions: [
                TextButton(
                  onPressed: _load,
                  child: Text(
                    context.strings.captain00eab31f,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          if (_offers.isNotEmpty && _activeTrip == null) ...[
            _title(
              context.strings.captainee9201f4,
              Icons.notifications_active_rounded,
            ),
            ..._offers.map(_offerCard),
            const SizedBox(height: 8),
          ],
          if (_activeTrip != null) ...[
            _title(
              context.strings.captain99f2c8a6,
              Icons.directions_car_filled_rounded,
            ),
            _activeTripCard(_activeTrip!),
            const SizedBox(height: 8),
          ],
          _v30CompactHeader(),
          const SizedBox(height: 12),
          CaptainHomeMapV30(
            captain: _captain,
            online: _online,
            visible: _tab == 0,
            liveLatitude: _v30MapPosition?.latitude,
            liveLongitude: _v30MapPosition?.longitude,
            onOpenDemandMap: () => context.push('/captain/demand-map'),
          ),
          const SizedBox(height: 12),
          _v32OnlineButton(),
          const SizedBox(height: 13),
          if (_rewards.isNotEmpty) ...[
            _title(
              context.strings.captaind6004d47,
              Icons.card_giftcard_rounded,
            ),
            ..._rewards
                .take(3)
                .map((reward) => CaptainRewardBanner(campaign: reward)),
          ],
          if (_marketAssignment != null) ...[
            _title(context.strings.captain4abac2da, Icons.shopping_bag_rounded),
            _marketAssignmentCard(_marketAssignment!),
          ],
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 9),
            iconColor: Theme.of(context).colorScheme.primary,
            collapsedIconColor: Theme.of(context).colorScheme.primary,
            title: Text(
              context.strings.captaindee9712a,
              style: TextStyle(
                
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            children: [
              _onlineCard(),
              const SizedBox(height: 12),
              _title(context.strings.captain33e9156d, Icons.insights_rounded),
              Row(
                children: [
                  Expanded(
                    child: _metric(
                      context.strings.captainb13e131c,
                      _dailyUnavailable ? '—' : '$todayTrips',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metric(
                      context.strings.captain4c103c55,
                      _dailyUnavailable
                          ? '—'
                          : context.strings.moneyValue(
                              todayEarnings.toStringAsFixed(2),
                            ),
                    ),
                  ),
                ],
              ),
              if (_dailyUnavailable)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    context.strings.captainf8e8dfb6,
                    style: TextStyle(
                      
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (missingEarnings > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    context.strings.captainHomePartialEarnings(
                      '$missingEarnings',
                    ),
                    style: TextStyle(
                      
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              _metric(
                context.strings.captain80098418,
                '${rating.toStringAsFixed(1)} ★',
              ),
              const SizedBox(height: 8),
              _settlementBanner(settlement),
            ],
          ),
        ],
      ),
    );
  }

  // V32 main-header: only brand + essential actions. Map owns zone metrics.
  Widget _v30CompactHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    child: Row(
      children: [
        Image.asset(
          'assets/images/veto_sanya_app_icon.png',
          width: 38,
          height: 38,
          semanticLabel: 'VETO SANYA',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VETO SANYA',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 16,
                ),
              ),
              Text(
                context.strings.captainfcd34918,
                style: TextStyle(
                  color: Color(0xFFB6C4D6),
                  
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        _roundHeaderButton(
          Icons.refresh_rounded,
          context.strings.captain00eab31f,
          _load,
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _roundHeaderButton(
              Icons.notifications_none_rounded,
              context.strings.captain8ce3e0cc,
              _openNotifications,
            ),
            if (_unreadNotifications > 0)
              Positioned(
                top: -4,
                left: -4,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: const Color(0xFFE54C50),
                  child: Text(
                    _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                    style: const TextStyle(color: Colors.white, fontSize: 9),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _roundHeaderButton(
    IconData icon,
    String tooltip,
    VoidCallback onTap,
  ) =>
      Material(
        color: Colors.black.withValues(alpha: .22),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
        ),
      );

  Widget _v32OnlineButton() {
    final state = _presenceState;
    final unavailable =
        state == CaptainPresence.unavailable ||
        state == CaptainPresence.disconnected;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _presenceChanging || _busy ? null : _toggleOnline,
            icon: Icon(
              _online
                  ? Icons.power_settings_new_rounded
                  : Icons.directions_car_filled_rounded,
              size: 22,
            ),
            label: Text(
              _presenceChanging
                  ? context.strings.captain8448690a
                  : _online
                  ? context.strings.captain7b3b2ab3
                  : context.strings.captainb074b07c,
              style: const TextStyle(
                
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: const Color(0xFF0B1524),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        if (unavailable || _presenceReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Text(
              _presenceReason ?? CaptainPresenceCard.label(state),
              textAlign: TextAlign.center,
              style: TextStyle(
                
                color: Theme.of(context).colorScheme.primary,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }

  Widget _marketAssignmentCard(Map<String, dynamic> assignment) {
    final store = assignment['store'] is Map
        ? Map<String, dynamic>.from(assignment['store'] as Map)
        : <String, dynamic>{};
    final order = assignment['order'] is Map
        ? Map<String, dynamic>.from(assignment['order'] as Map)
        : <String, dynamic>{};
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF302706), Color(0xFF141B2D)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(Icons.storefront, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store['name']?.toString() ??
                          context.strings.captain3c02a45d,
                      style: TextStyle(
                        
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      store['address']?.toString() ?? '',
                      style: TextStyle(
                        
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                context.strings.moneyValue(
                  ((order['delivery_fee'] as num?)?.toDouble() ?? 0)
                      .toStringAsFixed(2),
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            margin: const EdgeInsets.only(bottom: 9),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.greenAccent.withValues(alpha: .35),
              ),
            ),
            child: Text(
              context.strings.captainbef9383c,
              style: TextStyle(
                
                color: Colors.greenAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openMarketOrder(order),
              icon: const Icon(Icons.navigation_rounded),
              label: Text(context.strings.captainf86852a4),
            ),
          ),
        ],
      ),
    );
  }

  void _openMarketOrder(Map<String, dynamic> order) {
    final orderId = order['id']?.toString();
    if (orderId == null || orderId.isEmpty) return;
    context.push('${AppRoutes.captainMarketOrder}?orderId=$orderId');
  }

  Widget _tripsPage() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
        children: [
          _pageIntro(
            Icons.route_rounded,
            context.strings.captainf3683943,
            context.strings.captaind83efdf5,
          ),
          const SizedBox(height: 12),
          if (_marketHistoryUnavailable)
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                context.strings.captain4bf40b6a,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  
                ),
              ),
            ),
          if (_marketHistory.isNotEmpty) ...[
            Text(
              context.strings.captainaf4b3178,
              style: TextStyle(
                
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ..._marketHistory.map(_marketHistoryCard),
            const SizedBox(height: 12),
          ],
          if (_history.isEmpty && _marketHistory.isEmpty)
            _emptyCard(
              Icons.route_rounded,
              context.strings.captaincf83fb17,
              context.strings.captainda3de6e3,
            )
          else
            ..._history.map(_historyCard),
        ],
      ),
    );
  }

  Widget _walletPage() {
    final settlement = (_captain?['settlement_debt'] as num?)?.toDouble() ?? 0;
    final totalNet = (_captain?['total_earnings'] as num?)?.toDouble() ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
        children: [
          _pageIntro(
            Icons.account_balance_wallet_rounded,
            context.strings.captain2823f378,
            context.strings.captainHomea9f18daf,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metric(
                  context.strings.captainHomed704e9bc,
                  context.strings.moneyValue(totalNet.toStringAsFixed(2)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  context.strings.captainHomecf1aadab,
                  context.strings.moneyValue(settlement.toStringAsFixed(2)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _settlementBanner(settlement),
          const SizedBox(height: 8),
          Text(
            context.strings.captainHome227f09b8,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.strings.captainHomeed440205,
            style: TextStyle(
              
              color: Theme.of(context).colorScheme.primary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (_transactions.isEmpty)
            _emptyCard(
              Icons.receipt_long_rounded,
              context.strings.captainHome96dede8e,
              context.strings.captainHome2f8aa27c,
            )
          else
            ..._transactions.map(
              (tx) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tx['description']?.toString() ??
                            tx['tx_type']?.toString() ??
                            context.strings.captainHome3fcf112b,
                        style: TextStyle(
                          
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      context.strings.moneyValue(
                        ((tx['amount'] as num?)?.toDouble() ?? 0)
                            .toStringAsFixed(2),
                      ),
                      style: TextStyle(
                        
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _marketHistoryCard(Map<String, dynamic> order) {
    final delivered = order['order_status'] == 'delivered';
    final number =
        order['store_order_number']?.toString().padLeft(2, '0') ?? '';
    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.shopping_bag_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          context.strings.captainMarketTitle(
            order['store_name']?.toString() ??
                context.strings.captainHome234766dc,
            number.isEmpty ? '' : context.strings.captainMarketWindow(number),
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            
          ),
        ),
        subtitle: Text(
          context.strings.captainMarketNet(
            delivered
                ? context.strings.captainHome5f7b65d5
                : context.strings.captainHome616d302c,
            context.strings.moneyValue(
              ((order['captain_earning'] as num?)?.toDouble() ?? 0)
                  .toStringAsFixed(2),
            ),
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            
          ),
        ),
        trailing: Icon(
          Icons.receipt_long_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        onTap: () => _openMarketOrder(order),
      ),
    );
  }

  bool _staffVerifierV21 = false;
  bool _linkedCustomerV21 = false;
  Future<void> _loadStaffVerifierV21() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;
    try {
      final linked = await VetoModeV21.canUseCustomer(userId);
      if (mounted) setState(() => _linkedCustomerV21 = linked);
    } catch (_) {}
    try {
      final access = await StaffAccessV16.load();
      if (mounted)
        setState(
          () => _staffVerifierV21 =
              access.active &&
              access.can('verification.view') &&
              access.can('verification.manage'),
        );
    } catch (_) {}
  }

  Future<void> _switchToCustomerV21() async {
    if (_activeTrip != null || _online) {
      _show(context.strings.captainHomeaf9189ea);
      return;
    }
    final id = SupabaseService.instance.currentUser?.id;
    if (id == null || !mounted) return;
    final ok = await VetoModeV21.openCustomer(GoRouter.of(context), id);
    if (!ok && mounted) _show(context.strings.captainHome3dc57bb8);
  }

  // V32: dedicated presentation widget. The existing callbacks preserve
  // location/identity permissions, wallet settlement, and sign-out guards.
  Widget _morePage() => CaptainMoreV32(
    captain: _captain,
    linkedCustomer: _linkedCustomerV21,
    staffVerifier: _staffVerifierV21,
    onOpenProfile: _showProfile,
    onSwitchCustomer: _switchToCustomerV21,
    onQuickVerification: () {
      if (_online || _activeTrip != null) {
        _show(context.strings.captainHome31e75c6d);
        return;
      }
      VetoModeV21.staffView = true;
      VetoModeV21.customerView = false;
      context.go(AppRoutes.adminDashboard);
    },
    onTrips: () => setState(() => _tab = 1),
    onEarnings: () => setState(() => _tab = 2),
    onDemand: () => context.push('/captain/demand-map'),
    onNotifications: _openNotifications,
    onSupport: _showSupport,
    onPrivacy: () => context.push(AppRoutes.legalCenter),
    onDelete: () => context.push(AppRoutes.deleteAccount),
    onRefresh: _load,
    onSignOut: () async {
      final id = _captain?['id']?.toString();
      if (_activeTrip != null ||
          (id != null &&
              await SupabaseService.instance.getActiveTripForCaptain(id) !=
                  null)) {
        _show(context.strings.captainHomeffc8991e);
        if (mounted) setState(() => _tab = 0);
        return;
      }
      await SupabaseService.instance.signOut();
      if (mounted) context.go(AppRoutes.signUpLoginScreen);
    },
  );

  Widget _pageIntro(IconData icon, String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF202B46), Color(0xFF151C2E)],
              )
            : null,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF303C56) : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProfile() async {
    final c = _captain ?? const <String, dynamic>{};
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Directionality(
        textDirection: Directionality.of(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.strings.captainHome59807bee,
                style: TextStyle(
                  
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              _profileRow(
                context.strings.captainHome52ab0984,
                c['full_name']?.toString() ?? '—',
              ),
              _profileRow(
                context.strings.captainHome94b59a51,
                c['phone']?.toString() ?? '—',
              ),
              _profileRow(
                context.strings.captainHome4309e001,
                '${c['vehicle_brand'] ?? ''} ${c['vehicle_model'] ?? ''}'
                        .trim()
                        .isEmpty
                    ? (c['vehicle_type']?.toString() ?? '—')
                    : '${c['vehicle_brand'] ?? ''} ${c['vehicle_model'] ?? ''}',
              ),
              _profileRow(
                context.strings.captainHome936290d6,
                c['vehicle_plate']?.toString() ?? '—',
              ),
              _profileRow(
                context.strings.captain80098418,
                '${((c['rating'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} ★',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileRow(String a, String b) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            a,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            b,
            textAlign: TextAlign.right,
            style: TextStyle(
              
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  CaptainPresence get _presenceState => resolveCaptainPresence(
    online: _online,
    changing: _presenceChanging,
    disconnected: _presenceDisconnected,
    busy: _activeTrip != null || _marketAssignment != null,
    unavailable:
        _captain?['captain_status'] != 'active' ||
        ((_captain?['settlement_debt'] as num?)?.toDouble() ?? 0) <=
            -_debtThreshold,
  );

  Widget _onlineCard() => CaptainPresenceCard(
    locationFresh: isConfirmedCaptainGpsFresh(CaptainTrackingService.instance.lastServerFix),
    state: _presenceState,
    online: _online,
    reason:
        _presenceReason ??
        (_presenceState == CaptainPresence.unavailable
            ? ((_captain?['settlement_debt'] as num?)?.toDouble() ?? 0) <=
                      -_debtThreshold
                  ? context.strings.captainHomec0ec8bb3
                  : context.strings.captainHome59003b32
            : null),
    onToggle: _toggleOnline,
  );
  Widget _offerCard(Map<String, dynamic> offer) {
    final trip = offer['trips'] is Map
        ? Map<String, dynamic>.from(offer['trips'])
        : <String, dynamic>{};
    final distance = (trip['distance_km'] as num?)?.toDouble();
    final note = trip['customer_note']?.toString().trim() ?? '';
    final serviceType = trip['service_type']?.toString() ?? '';
    final extras = trip['extra_requests']?.toString().trim() ?? '';
    final extraAmount = trip['extra_expected_amount'];
    final expiresAt = DateTime.tryParse(offer['expires_at']?.toString() ?? '');
    final eta = (offer['eta_minutes'] as num?)?.toInt();
    final pickupDistance = (offer['captain_distance_km'] as num?)?.toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withAlpha(110),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (expiresAt != null)
            CaptainOfferDeadline(
              key: ValueKey('${offer['id']}:$expiresAt'),
              expiresAt: expiresAt,
              onExpired: () {
                if (!mounted) return;
                setState(
                  () => _offers.removeWhere((o) => o['id'] == offer['id']),
                );
                _syncOfferTripRealtime();
              },
            ),
          if (pickupDistance != null || eta != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                [
                  if (pickupDistance != null)
                    context.strings.captainHomePickupDistance(
                      pickupDistance.toStringAsFixed(1),
                    ),
                  if (eta != null) context.strings.captainHomeArrival('$eta'),
                ].join(' • '),
                style: TextStyle(
                  
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (extras.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                context.strings.captainOfferExtras(
                  extras,
                  extraAmount == null
                      ? context.strings.captainExtrasLimit
                      : context.strings.captainExtrasEstimate('$extraAmount'),
                ),
                style: TextStyle(
                  
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  ((trip['extra_requests']?.toString().trim() ?? '').isNotEmpty
                      ? context.strings.captainHome3fb68bff
                      : context.strings.captainHomede8700b0),
                  style: TextStyle(
                    
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (distance != null)
                Text(
                  context.strings.captainHomeDistance(
                    distance.toStringAsFixed(1),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (serviceType.isNotEmpty)
            _chip(
              serviceType == 'motorcycle_ride'
                  ? context.strings.captainHome80a51d6a
                  : serviceType == 'package'
                  ? context.strings.captainHome113cb058
                  : context.strings.captainHome89aef3a3,
              Theme.of(context).colorScheme.primary,
            ),
          const SizedBox(height: 7),
          Text(
            trip['pickup_address']?.toString() ?? '',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.strings.captainHomeToDestination(
              trip['destination_address']?.toString() ?? '',
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      context.strings.captainCustomerNote(note),
                      style: TextStyle(
                        
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if ((offer['trip_id'] ?? trip['id']) != null)
            Align(
              alignment: Alignment.centerRight,
              child: CaptainRoutePreviewV45(
                tripId: (offer['trip_id'] ?? trip['id']).toString(),
              ),
            ),
          const SizedBox(height: 8),
          CaptainFarePreviewWidget(offer: offer),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 7,
            children: [
              if (distance != null)
                _chip(
                  context.strings.captainHomeDistance(
                    distance.toStringAsFixed(1),
                  ),
                  Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy || _presenceChanging
                      ? null
                      : () => _acceptOffer(offer),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(
                    context.strings.captainHome9703ff57,
                    style: TextStyle(
                      
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy || _presenceChanging
                      ? null
                      : () => _declineOffer(offer),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(
                    context.strings.captainHomeeb3b1bcc,
                    style: TextStyle(
                      
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activeTripCard(Map<String, dynamic> trip) {
    final status = trip['trip_status']?.toString() ?? 'accepted';
    final customerPhone = trip['customer_phone']?.toString() ?? '';
    final customerName =
        trip['customer_name']?.toString().trim().isNotEmpty == true
        ? trip['customer_name'].toString()
        : context.strings.captainHomea042411e;
    final customerPhoto = trip['customer_photo_url']?.toString();
    final note = trip['customer_note']?.toString().trim() ?? '';

    String? next;
    String label = '';
    if (status == 'accepted') {
      next = 'arriving';
      label = context.strings.captainHome3a7baec4;
    } else if (status == 'arriving') {
      next = 'arrived';
      label = context.strings.captainHomeceb508b1;
    } else if (status == 'arrived') {
      next = 'started';
      label = context.strings.captainHome2cb6f5f1;
    } else if (status == 'started') {
      next = 'completed';
      label = context.strings.captainHome11c70484;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withAlpha(100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if(trip['ride_category_id_v3']!=null) Text('${trip['pricing_snapshot']?['category_config_v3']?[Localizations.localeOf(context).languageCode=='ar'?'name_ar':'name_en']??''}',style:Theme.of(context).textTheme.titleMedium),
          if((trip['trip_promises_v3'] as List? ?? []).isNotEmpty) Text((trip['trip_promises_v3'] as List).map((p)=>const {'quiet':'مشوار هادي / Quiet','no_music':'بدون أغاني / No music','ac':'تكييف / A/C','child':'معايا طفل / Child accompanied','baggage':'مساعدة الشنط / Baggage help','child_seat':'كرسي طفل / Child seat'}[p]??p).join(' · ')),
          if(trip['ride_category_id_v3']!=null) TripPromisePanel(tripId:trip['id'].toString(),status:status,captain:true),
          CaptainCustomerBadgeV29(
            tripId: trip['id']?.toString() ?? '',
            customerName: customerName,
            customerPhoto: customerPhoto,
            customerPhone: customerPhone,
          ),
          const SizedBox(height: 6),
          Text(
            context.strings.captainHomeStatus(_statusLabel(status)),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            trip['pickup_address']?.toString() ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.strings.captainHomeToDestination(
              trip['destination_address']?.toString() ?? '',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                context.strings.captainCustomerNote(note),
                style: TextStyle(
                  
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 11,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: customerPhone.isEmpty
                      ? null
                      : () => _callNumber(customerPhone),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: Text(
                    context.strings.captainHome606af07c,
                    style: TextStyle(
                      
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                    '${AppRoutes.tripChat}?tripId=${trip['id']}',
                  ),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                  label: Text(
                    context.strings.captainHome212e5d4b,
                    style: TextStyle(
                      
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : () async {
                  if(next=='started' && trip['pricing_snapshot']?['category_config_v3']?['safety_required']==true){
                    final verified=await verifyCaptainTripCode(context,trip['id'].toString());
                    if(!verified || !mounted)return;
                  }
                  await _changeTripStatus(next!);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'accepted':
        return context.strings.captainHome0c1c76d8;
      case 'arriving':
        return context.strings.captainHome7a8d87be;
      case 'arrived':
        return context.strings.captainHome36e931f5;
      case 'started':
        return context.strings.captainHomea6fa5196;
      default:
        return s;
    }
  }

  Widget _historyCard(Map<String, dynamic> t) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Row(
      children: [
        Icon(
          Icons.route_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t['destination_address']?.toString() ??
                    context.strings.captainHomea674a023,
                style: TextStyle(
                  
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _historyStatusLabel(t['trip_status']?.toString()),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Text(
          context.strings.moneyValue(
            ((t['captain_earnings'] as num?)?.toDouble() ?? 0).toStringAsFixed(
              0,
            ),
          ),
          style: TextStyle(
            
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (t['trip_status']?.toString() == 'completed')
          IconButton(
            tooltip: context.strings.captainHome54940fb7,
            onPressed: () => _showCaptainInvoice(t),
            icon: Icon(
              Icons.receipt_long_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
      ],
    ),
  );

  String _historyStatusLabel(String? status) => switch (status) {
    'pending' => context.strings.captainHome196a7a12,
    'accepted' => context.strings.captainHome156d85a1,
    'arriving' => context.strings.captainHome7a8d87be,
    'arrived' => context.strings.captainHome83ab21ee,
    'started' => context.strings.captainHome888bd5a4,
    'completed' => context.strings.captainHomef1d6d15f,
    'cancelled' => context.strings.captainHomed87ae61b,
    _ => context.strings.captainHomefa8729c1,
  };

  Widget _metric(String title, String value) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            
            color: const Color(0xFFC6D0E4),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _settlementBanner(double settlement) {
    final owesCompany = settlement < 0;
    final amount = settlement.abs();
    final limitReached = owesCompany && amount >= _debtThreshold;
    final color = owesCompany ? AppTheme.errorLight : AppTheme.successLight;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withAlpha(55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                owesCompany
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_rounded,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  owesCompany
                      ? context.strings.captainHomeCompanyDue(
                          amount.toStringAsFixed(2),
                        )
                      : settlement > 0
                      ? context.strings.captainHomeYourSettlement(
                          amount.toStringAsFixed(2),
                        )
                      : context.strings.captainHome1cabb6f1,
                  style: TextStyle(
                    
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (limitReached) ...[
            const SizedBox(height: 8),
            Text(
              context.strings.captainHomeDebtLimit(
                _debtThreshold.toStringAsFixed(2),
              ),
              style: const TextStyle(
                
                color: AppTheme.errorLight,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push(AppRoutes.captainDebtInvoice),
              icon: const Icon(Icons.receipt_long_rounded),
              label: Text(
                context.strings.captainHome9cef3446,
                style: TextStyle(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: color.withAlpha(55)),
    ),
    child: Text(
      text,
      style: TextStyle(
        
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _title(String title, IconData icon) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 18),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            
            color: Theme.of(context).colorScheme.primary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _emptyCard(IconData icon, String title, String subtitle) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      children: [
        AnimatedBuilder(
          animation: _readyPulse,
          builder: (context, child) => Transform.scale(
            scale: icon == Icons.radar_rounded
                ? 0.92 + (_readyPulse.value * 0.16)
                : 1,
            child: child,
          ),
          child: Container(
            width: 106,
            height: 106,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withAlpha(65),
              ),
              gradient: RadialGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withAlpha(28),
                  Colors.transparent,
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withAlpha(100),
                ),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 38,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
