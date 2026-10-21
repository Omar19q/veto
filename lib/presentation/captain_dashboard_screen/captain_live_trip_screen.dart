import '../trip_booking_screen/widgets/localized_cancellation_failure.dart';
import '../../l10n/strings.dart';
import '../../widgets/trip_financial_card_v11.dart';
import 'dart:async';
import '../../widgets/trip_safety_code.dart';
import '../../widgets/trip_promise_panel.dart';
import '../../services/trip_data_v10.dart';
import '../../widgets/trip_loading_v10.dart';
import '../trip_booking_screen/widgets/smooth_live_trip_map.dart';

import 'package:flutter/material.dart';
import 'widgets/change_transfer_widget.dart';
import '../../widgets/trip_chat_button.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'widgets/captain_customer_rating_v29.dart';
import 'widgets/captain_route_preview_v45.dart';
import '../../widgets/customer_identity_v29.dart';

class CaptainLiveTripScreen extends StatefulWidget {
  final String tripId;
  const CaptainLiveTripScreen({super.key, required this.tripId});

  @override
  State<CaptainLiveTripScreen> createState() => _CaptainLiveTripScreenState();
}

class _CaptainLiveTripScreenState extends State<CaptainLiveTripScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _trip;
  bool _loading = true;
  bool _busy = false;
  TripRealtimeLease? _sub;
  Timer? _waitingTimer;
  String? _loadError;
  bool _loadingRequest = false;
  bool _statusSyncing = false;
  DateTime? _waitingStartedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _sub?.unsubscribe();
    _waitingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load(); // Reattach Realtime and read current server state.
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {}
  }

  Future<void> _refreshTripStatus({bool manual = false}) async {
    if (!mounted || _statusSyncing) return;
    _statusSyncing = true;
    try {
      final trip = await SupabaseService.instance.getTripById(widget.tripId);
      if (!mounted) return;
      if (trip != null) {
        setState(() => _trip = {...?_trip, ...trip});
        _syncWaitingTimer();
        if (manual) _show(context.strings.captainRide182cb52e);
      } else if (manual) {
        _show(context.strings.captainRide0f653eb8);
      }
    } catch (_) {
      if (manual && mounted) _show(context.strings.captainRide3acc32e9);
    } finally {
      _statusSyncing = false;
    }
  }

  Future<void> _load() async {
    if (_loadingRequest) return;
    _loadingRequest = true;
    try {
      final trip = await SupabaseService.instance.getTripById(widget.tripId);
      if (trip == null) throw StateError('trip_not_found');
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _loading = false;
        _loadError = null;
      });
      _syncWaitingTimer();
      _sub ??= SupabaseService.instance.subscribeToTripStatus(widget.tripId, (
        update,
      ) {
        if (!mounted) return;
        final location = update['live_location'];
        setState(() {
          _trip = {...?_trip, ...normalizeTripV10(update)};
          if (location is Map) {
            final captain = Map<String, dynamic>.from(
              (_trip?['captain_context'] as Map?) ?? {},
            );
            captain.addAll({
              'current_latitude': location['latitude'],
              'current_longitude': location['longitude'],
              'location_updated_at': location['recorded_at'],
            });
            _trip!['captain_context'] = normalizeTripV10(captain);
          }
        });
        _syncWaitingTimer();
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _loadError = tripLoadErrorV10(error);
        });
    } finally {
      _loadingRequest = false;
    }
  }

  void _syncWaitingTimer() {
    final status = _trip?['trip_status']?.toString();
    final raw = (_trip?['waiting_started_at'] ?? _trip?['arrived_at'])
        ?.toString();
    final started = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    if (status == 'arrived' &&
        started == _waitingStartedAt &&
        _waitingTimer != null) {
      return;
    }
    _waitingTimer?.cancel();
    _waitingTimer = null;
    if (status != 'arrived' || started == null) {
      _waitingStartedAt = null;
      return;
    }
    _waitingStartedAt = started;
    _waitingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  String _waitingElapsedText() {
    final started = _waitingStartedAt;
    if (started == null) return '00:00';
    final seconds = DateTime.now()
        .difference(started)
        .inSeconds
        .clamp(0, 86400);
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _next() async {
    final status = _trip?['trip_status']?.toString();
    final next = switch (status) {
      'accepted' => 'arriving',
      'arriving' => 'arrived',
      'arrived' => 'started',
      'started' => 'completed',
      _ => null,
    };
    if (next == null || _busy) return;

    if(next=='started' && _trip?['pricing_snapshot']?['category_config_v3']?['safety_required']==true){
      if(!await verifyCaptainTripCode(context,widget.tripId) || !mounted)return;
    }
    setState(() => _busy = true);
    try {
      await SupabaseService.instance.advanceTripStatus(widget.tripId, next);
      // Only acknowledge the captain's action here. Customer notifications
      // are generated separately on the server, not echoed back as a toast.
      if (mounted && next != 'completed') {
        final caption = switch (next) {
          'arriving' => context.strings.captainRide5332028e,
          'arrived' => context.strings.captainRide73187c4e,
          'started' => context.strings.captainRide3ab5268d,
          _ => context.strings.captainRided8d96922,
        };
        _show(caption);
      }
      if (next == 'completed' && mounted) {
        final invoice = await SupabaseService.instance.getTripById(
          widget.tripId,
        );
        if (invoice != null) {
          await _showInvoice(invoice);
        }
        if (mounted) {
          try {
            await CaptainCustomerRatingV29.request(
              context,
              tripId: widget.tripId,
              customerName:
                  (_trip?['customer_context']?['full_name'] ??
                          context.strings.captainRidea042411e)
                      .toString(),
            );
          } catch (_) {
            /* Dashboard will show any remaining rating. */
          }
        }
        if (mounted) context.go(AppRoutes.captainDashboardScreen);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        _show(context.strings.captainRide9947a71a);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final status = _trip?['trip_status']?.toString();
    if (!const {'accepted', 'arriving', 'arrived'}.contains(status) ||
        _trip?['started_at'] != null) {
      _show(context.strings.captainRide3c0f919c);
      return;
    }
    Map<String, dynamic> preview;
    try {
      preview = await SupabaseService.instance.getCustomerCancellationPreview(
        widget.tripId,
      );
    } catch (_) {
      if (mounted) _show(context.strings.captainRidef20a786e);
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.strings.captainRidebe27c947),
        content: Text(
          preview['free'] == true
              ? context.strings.captainRidefd11f805
              : context.strings.captainCancellationFee('${preview['fee']}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.strings.captainRidecb822418),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.strings.captainRideadfc99d3),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.instance.advanceTripStatus(
        widget.tripId,
        'cancelled',
      );
      if (mounted) context.go(AppRoutes.captainDashboardScreen);
    } catch (e) {
      _show(localizedCancellationFailure(context, e));
    }
  }

  Future<void> _showInvoice(Map<String, dynamic> trip) async {
    try {
      final invoice = await SupabaseService.instance.getTripInvoice(
        widget.tripId,
      );
      final t = <String, dynamic>{
        ...trip,
        if (invoice['trip'] is Map)
          ...Map<String, dynamic>.from(invoice['trip'] as Map),
      };
      final invoiceDetails = invoice['invoice'] is Map
          ? Map<String, dynamic>.from(invoice['invoice'] as Map)
          : <String, dynamic>{};
      final customer = invoice['customer'] is Map
          ? Map<String, dynamic>.from(invoice['customer'] as Map)
          : t['customers'] is Map
          ? Map<String, dynamic>.from(t['customers'] as Map)
          : <String, dynamic>{};
      Object? field(List<String> keys) {
        for (final key in keys) {
          if (invoiceDetails[key] != null) return invoiceDetails[key];
          if (t[key] != null) return t[key];
          if (invoice[key] != null) return invoice[key];
        }
        return null;
      }

      double? moneyValue(List<String> keys) {
        final raw = field(keys);
        if (raw is num) return raw.toDouble();
        return double.tryParse(raw?.toString() ?? '');
      }

      String money(List<String> keys) {
        final amount = moneyValue(keys);
        return amount == null
            ? context.strings.captainRide82963d4d
            : context.strings.moneyValue(amount.toStringAsFixed(2));
      }

      final cashToCollect = moneyValue(['cash_collected', 'cash_amount']);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Directionality(
          textDirection: Directionality.of(context),
          child: AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              context.strings.captainRide54940fb7,
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
                  _cashCollectCard(cashToCollect),
                  const SizedBox(height: 5),
                  Text(
                    context.strings.captainRide18b3b709,
                    style: TextStyle(
                      
                      color: Color(0xFFBEC9D8),
                      fontSize: 10,
                    ),
                  ),
                  if (cashToCollect != null && cashToCollect > 0) ...[
                    const SizedBox(height: 12),
                    ChangeTransferWidget(tripId: widget.tripId),
                  ],
                  const SizedBox(height: 12),
                  _row(
                    context.strings.captainRidea042411e,
                    customer['full_name']?.toString() ??
                        field(['customer_name'])?.toString() ??
                        '—',
                  ),
                  _row(
                    context.strings.captainRide7f29d28a,
                    money(['base_fare']),
                  ),
                  _row(
                    context.strings.captainRidee8ea6cc8,
                    money(['waiting_charge']),
                  ),
                  _row(
                    context.strings.captainRideb593a645,
                    '- ${money(['promo_discount'])}',
                  ),
                  _row(
                    context.strings.captainRide3eab5144,
                    money(['incentive_total', 'incentive_amount']),
                  ),
                  _row(
                    context.strings.captainRide500e1d79,
                    money([
                      'previous_due_collected',
                      'previous_due',
                      'customer_previous_due',
                    ]),
                  ),
                  _row(
                    context.strings.captainRidec5496762,
                    money(['customer_total', 'total_fare']),
                    strong: true,
                  ),
                  _row(
                    context.strings.captainRideb245e20d,
                    money(['wallet_used', 'wallet_amount']),
                  ),
                  _row(
                    context.strings.captainRide6b6e59d4,
                    money(['cash_collected', 'cash_amount']),
                    strong: true,
                  ),
                  _row(
                    context.strings.captainRide53f0a84e,
                    money(['commission', 'commission_amount']),
                  ),
                  _row(
                    context.strings.captainRide79fe765a,
                    money([
                      'company_incentive',
                      'company_incentive_amount',
                      'incentive_company_share',
                    ]),
                  ),
                  _row(
                    context.strings.captainRide4bbacf57,
                    money([
                      'captain_incentive',
                      'captain_incentive_amount',
                      'incentive_captain_share',
                    ]),
                  ),
                  _row(
                    context.strings.captainRide9c8ac33a,
                    money(['captain_earnings']),
                    strong: true,
                  ),
                  _row(
                    context.strings.captainRide493a9f67,
                    money([
                      'captain_settlement_delta',
                      'settlement_delta',
                      'financial_settlement_change',
                    ]),
                  ),
                  _row(
                    context.strings.captainRide233aea82,
                    money(['captain_settlement_after']),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.primary,
                ),
                child: Text(
                  context.strings.captainRide3ef541b9,
                  style: TextStyle(),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (mounted) _show(context.strings.captainRide9af289d1);
    }
  }

  Widget _cashCollectCard(double? amount) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF3B2A06), Color(0xFF1E2236)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.gold.withAlpha(120)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.strings.captainRide6ff5cf85,
          style: TextStyle(
            
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          amount == null
              ? context.strings.captainRideaab7cc3e
              : context.strings.moneyValue(amount.toStringAsFixed(2)),
          style: const TextStyle(
            
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppTheme.gold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount == null
              ? context.strings.captainRide4bbd31a2
              : context.strings.captainRideba6f0140,
          style: TextStyle(
            
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    ),
  );

  Widget _row(String a, String b, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            a,
            style: TextStyle(
              
              color: strong
                  ? Theme.of(context).colorScheme.onSurface
                  : const Color(0xFFC6D0E4),
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          b,
          style: TextStyle(
            
            color: strong
                ? AppTheme.gold
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  // Opens real turn-by-turn directions in the installed map/browser.
  // Accepted/arriving/arrived -> pickup. Started -> destination. This does not
  // advance any trip state or alter its financials.
  Future<void> _openTripDirections({required bool toDestination}) async {
    // Refresh from the server before opening navigation, so an older UI does
    // not send the captain back to pickup after the ride has started.
    await _refreshTripStatus();
    final trip = _trip;
    if (trip == null) return;
    final liveStatus = trip['trip_status']?.toString();
    if (!const {
      'accepted',
      'arriving',
      'arrived',
      'started',
    }.contains(liveStatus)) {
      _show(context.strings.captainRide0b915e74);
      return;
    }
    toDestination = liveStatus == 'started';
    final latitude =
        (trip[toDestination ? 'destination_latitude' : 'pickup_latitude']
                as num?)
            ?.toDouble();
    final longitude =
        (trip[toDestination ? 'destination_longitude' : 'pickup_longitude']
                as num?)
            ?.toDouble();
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      _show(
        toDestination
            ? context.strings.captainRide5b455cbb
            : context.strings.captainRide87bf7175,
      );
      return;
    }
    final target = '$latitude,$longitude';
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': target,
      'travelmode': 'driving',
    });
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _show(context.strings.captainRide765e075b);
    } catch (_) {
      if (mounted) _show(context.strings.captainRide94920016);
    }
  }

  Future<void> _openTripSupport() async {
    try {
      final svc = SupabaseService.instance;
      var whatsapp =
          (await svc.getSetting('captain_support_whatsapp'))?.trim() ?? '';
      var phone = (await svc.getSetting('captain_support_phone'))?.trim() ?? '';
      if (whatsapp.isEmpty)
        whatsapp =
            (await svc.getSetting('customer_service_whatsapp'))?.trim() ?? '';
      if (phone.isEmpty)
        phone = (await svc.getSetting('customer_service_phone'))?.trim() ?? '';
      final waDigits = whatsapp.replaceAll(RegExp(r'\D'), '');
      if (waDigits.isNotEmpty) {
        final number = waDigits.startsWith('20')
            ? waDigits
            : '20${waDigits.replaceFirst(RegExp(r'^0+'), '')}';
        final message = Uri.encodeComponent(
          context.strings.captainSupportRide(widget.tripId),
        );
        final opened = await launchUrl(
          Uri.parse('https://wa.me/$number?text=$message'),
          mode: LaunchMode.externalApplication,
        );
        if (!opened) _show(context.strings.captainRide186db0ab);
      } else if (phone.isNotEmpty) {
        await launchUrl(
          Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}'),
        );
      } else {
        _show(context.strings.captainRidedc09f493);
      }
    } catch (_) {
      _show(context.strings.captainRidef034b7ea);
    }
  }

  Future<void> _call(String phone) async {
    final p = phone.trim();
    if (p.isEmpty) return;
    await launchUrl(Uri.parse('tel:$p'));
  }

  void _show(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s, style: const TextStyle()),
      ),
    );
  }

  String _status(String? s) => switch (s) {
    'accepted' => context.strings.captainRide0c1c76d8,
    'arriving' => context.strings.captainRide7a8d87be,
    'arrived' => context.strings.captainRide36e931f5,
    'started' => context.strings.captainRidea6fa5196,
    'completed' => context.strings.captainRidece7c7ba9,
    'cancelled' => context.strings.captainRidede0b18e1,
    _ => context.strings.captainRide6a95aeca,
  };

  String? _nextLabel(String? s) => switch (s) {
    'accepted' => context.strings.captainRide3010a9b6,
    'arriving' => context.strings.captainRide058c0950,
    'arrived' => context.strings.captainRide2cb6f5f1,
    'started' => context.strings.captainRide11c70484,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: TripLoadingV10(),
      );
    }

    final t = _trip;
    if (t == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError ?? context.strings.captainRide9a86a128,
                  style: TextStyle(
                    
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _loading = true);
                    _load();
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(context.strings.captainRide8bbee7af),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.captainDashboardScreen),
                  child: Text(context.strings.captainRide97044b5c),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final customer = t['customer_context'] is Map
        ? Map<String, dynamic>.from(t['customer_context'])
        : <String, dynamic>{};

    final name = customer['full_name']?.toString().trim().isNotEmpty == true
        ? customer['full_name'].toString()
        : context.strings.captainRidea042411e;
    final phone = customer['phone']?.toString() ?? '';
    final photo = customer['profile_photo_url']?.toString();

    final pickup = t['pickup_address']?.toString() ?? '';
    final destination = t['destination_address']?.toString() ?? '';
    final status = t['trip_status']?.toString();
    final note = t['customer_note']?.toString().trim() ?? '';
    final extraRequests = t['extra_requests']?.toString().trim() ?? '';

    final pickupLat = (t['pickup_latitude'] as num?)?.toDouble();
    final pickupLng = (t['pickup_longitude'] as num?)?.toDouble();
    final destLat = (t['destination_latitude'] as num?)?.toDouble();
    final destLng = (t['destination_longitude'] as num?)?.toDouble();

    final nextLabel = _nextLabel(status);
    final freeWaiting = (t['free_wait_minutes_used'] as num?)?.toInt();
    final waitingRate = (t['waiting_rate_used'] as num?)?.toDouble();

    return Directionality(
      textDirection: Directionality.of(context),
      child: PopScope(
        canPop: const {'completed', 'cancelled'}.contains(status),
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              _status(status),
              style: TextStyle(
                
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: _statusSyncing
                    ? null
                    : () => _refreshTripStatus(manual: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  context.strings.captainRidedcf45bf6,
                  style: TextStyle(
                    
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: TextButton.styleFrom(foregroundColor: AppTheme.gold),
              ),
            ],
            leading: const {'completed', 'cancelled'}.contains(status)
                ? IconButton(
                    onPressed: () =>
                        context.go(AppRoutes.captainDashboardScreen),
                    icon: Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  )
                : IconButton(
                    onPressed: () => _show(context.strings.captainRidef7776e80),
                    icon: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppTheme.gold,
                    ),
                  ),
          ),
          body: status == 'cancelled'
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF331F2A),
                            border: Border.all(
                              color: const Color(0xFFFF8685),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.event_busy_rounded,
                            color: Color(0xFFFF8685),
                            size: 51,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          context.strings.captainRidede0b18e1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            
                            fontSize: 26,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          context.strings.captainRide1c184d79,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            
                            color: Color(0xFFB5C1D0),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () =>
                                context.go(AppRoutes.captainDashboardScreen),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.gold,
                              foregroundColor: const Color(0xFF101725),
                              minimumSize: const Size.fromHeight(52),
                            ),
                            icon: const Icon(Icons.home_rounded),
                            label: Text(
                              context.strings.captainRidec99f7794,
                              style: TextStyle(
                                
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (pickupLat != null && pickupLng != null)
                      SizedBox(
                        height: 225,
                        child: SmoothLiveTripMap(
                          darkTiles: true,
                          tripStatus: status,
                          serviceType: t['service_type']?.toString(),
                          captainLat:
                              (t['captain_context']?['current_latitude']
                                      as num?)
                                  ?.toDouble(),
                          captainLng:
                              (t['captain_context']?['current_longitude']
                                      as num?)
                                  ?.toDouble(),
                          pickupLat: pickupLat,
                          pickupLng: pickupLng,
                          destinationLat: destLat,
                          destinationLng: destLng,
                        ),
                      ),
                    _tripProgress(status),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 26),
                        children: [
                          if(t['ride_category_id_v3']!=null) ...[Text('${t['pricing_snapshot']?['category_config_v3']?[Localizations.localeOf(context).languageCode=='ar'?'name_ar':'name_en']??''}',style:Theme.of(context).textTheme.titleMedium),TripPromisePanel(tripId:widget.tripId,status:status??'',captain:true)],
                          CaptainCustomerBadgeV29(
                            tripId: widget.tripId,
                            customerName: name,
                            customerPhoto: photo,
                            customerPhone: phone,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _action(
                                  Icons.call_rounded,
                                  context.strings.captainRide606af07c,
                                  phone.isEmpty ? null : () => _call(phone),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TripChatButton(tripId: widget.tripId),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: CaptainRoutePreviewV45(
                              tripId: widget.tripId,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _openTripSupport,
                              icon: const Icon(Icons.support_agent_rounded),
                              label: Text(
                                context.strings.captainRide287b4011,
                                style: TextStyle(
                                  
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.gold,
                                side: const BorderSide(color: AppTheme.gold),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Column(
                              children: [
                                _routeRow(
                                  Icons.my_location_rounded,
                                  AppTheme.successLight,
                                  context.strings.captainRideae7ae56d,
                                  pickup,
                                ),
                                const SizedBox(height: 13),
                                _routeRow(
                                  Icons.location_on_rounded,
                                  AppTheme.errorLight,
                                  context.strings.captainRide8b068efc,
                                  destination,
                                ),
                              ],
                            ),
                          ),
                          if (const {
                            'accepted',
                            'arriving',
                            'arrived',
                            'started',
                          }.contains(status)) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2D250D),
                                    Color(0xFF161F30),
                                  ],
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppTheme.gold.withAlpha(145),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    status == 'started'
                                        ? context.strings.captainRide3c2c2a12
                                        : context.strings.captainRide28582b4d,
                                    style: TextStyle(
                                      
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    status == 'started' ? destination : pickup,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 52,
                                    child: ElevatedButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _openTripDirections(
                                              toDestination:
                                                  status == 'started',
                                            ),
                                      icon: const Icon(
                                        Icons.navigation_rounded,
                                        size: 22,
                                      ),
                                      label: Text(
                                        status == 'started'
                                            ? context
                                                  .strings
                                                  .captainRidef73184e0
                                            : context
                                                  .strings
                                                  .captainRide7b2fdccc,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.gold,
                                        foregroundColor: AppTheme.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (extraRequests.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              context.strings.captainExtraRequests(
                                extraRequests,
                              ),
                              textDirection: Directionality.of(context),
                              style: TextStyle(
                                
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                          if (note.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.cardBorder),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.edit_note_rounded,
                                    color: AppTheme.gold,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      context.strings.captainCustomerNote(note),
                                      style: TextStyle(
                                        
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (status == 'arrived' &&
                              _waitingStartedAt != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppTheme.gold.withAlpha(100),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.timer_rounded,
                                    color: AppTheme.gold,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      context.strings.captainRidede501d19,
                                      style: TextStyle(
                                        
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _waitingElapsedText(),
                                    style: const TextStyle(
                                      
                                      color: AppTheme.gold,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (status == 'arrived')
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Text(
                                freeWaiting != null && waitingRate != null
                                    ? context.strings.captainWaitingPolicy(
                                        '$freeWaiting',
                                        waitingRate.toStringAsFixed(2),
                                      )
                                    : context.strings.captainRidef6c538ef,
                                style: const TextStyle(
                                  
                                  color: Color(0xFFC6D0E4),
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (nextLabel != null)
                            SizedBox(
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _busy ? null : _next,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.gold,
                                  foregroundColor: AppTheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: Text(
                                  nextLabel,
                                  style: const TextStyle(
                                    
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          if (const {
                                'accepted',
                                'arriving',
                                'arrived',
                              }.contains(status) &&
                              t['started_at'] == null) ...[
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: _busy ? null : _cancel,
                              child: Text(
                                context.strings.captainRide6aef022f,
                                style: TextStyle(
                                  
                                  color: AppTheme.errorLight,
                                ),
                              ),
                            ),
                          ],
                          if (status == 'completed') ...[
                            const SizedBox(height: 12),
                            TripFinancialCardV11(trip: t, captain: true),
                            if (((t['cash_amount'] as num?) ?? 0) > 0)
                              ChangeTransferWidget(tripId: widget.tripId),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ), // PopScope
      ),
    );
  }

  Widget _tripProgress(String? status) {
    final steps = <(String, String, IconData)>[
      ('accepted', context.strings.captainRide69ca2e6b, Icons.task_alt_rounded),
      (
        'arriving',
        context.strings.captainRide7e5dbf26,
        Icons.navigation_rounded,
      ),
      (
        'arrived',
        context.strings.captainRideceb508b1,
        Icons.location_on_rounded,
      ),
      ('started', context.strings.captainRidedaa86941, Icons.route_rounded),
      ('completed', context.strings.captainRide3398d2be, Icons.flag_rounded),
    ];
    int rank(String? value) => switch (value) {
      'accepted' => 0,
      'arriving' => 1,
      'arrived' => 2,
      'started' => 3,
      'completed' => 4,
      _ => 0,
    };
    final current = rank(status);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF202B46), Color(0xFF141B2C)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.gold.withValues(alpha: .28)),
      ),
      child: Row(
        children: steps.indexed.map((entry) {
          final done = current >= entry.$1;
          final active = current == entry.$1;
          return Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  width: active ? 34 : 28,
                  height: active ? 34 : 28,
                  decoration: BoxDecoration(
                    color: done
                        ? AppTheme.gold
                        : Theme.of(context).colorScheme.surfaceVariant,
                    shape: BoxShape.circle,
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: AppTheme.gold.withValues(alpha: .24),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    entry.$2.$3,
                    size: active ? 18 : 15,
                    color: done
                        ? AppTheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.$2.$2,
                  maxLines: 1,
                  style: TextStyle(
                    
                    fontSize: 8.5,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                    color: done
                        ? AppTheme.gold
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback? onTap) => SizedBox(
    height: 50,
    child: ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: AppTheme.gold,
        side: BorderSide(color: AppTheme.gold.withAlpha(90)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon),
      label: Text(
        label,
        style: const TextStyle(
          
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  Widget _routeRow(IconData icon, Color color, String label, String value) =>
      Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    
                    color: const Color(0xFFC6D0E4),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
