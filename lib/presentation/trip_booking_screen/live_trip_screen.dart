import '../../services/ride_categories.dart';
import 'widgets/localized_cancellation_failure.dart';
import '../../l10n/strings.dart';
import 'package:vetosanya/widgets/captain_photo_v16.dart';
import '../../widgets/trip_financial_card_v11.dart';
import 'dart:async';
import '../../widgets/trip_safety_code.dart';
import '../../widgets/trip_promise_panel.dart';
import 'package:geolocator/geolocator.dart';
import 'widgets/trip_rating_sheet_v10.dart';
import 'widgets/captain_profile_sheet_v10.dart';
import '../../services/trip_data_v10.dart';
import '../../widgets/trip_loading_v10.dart';
import 'package:flutter/material.dart';
import 'widgets/smooth_live_trip_map.dart';
import '../../services/trip_chat_inbox.dart';
import 'package:go_router/go_router.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../services/growth_service.dart';
import '../../theme/app_theme.dart';

class LiveTripScreen extends StatefulWidget {
  final String tripId;

  const LiveTripScreen({super.key, required this.tripId});

  @override
  State<LiveTripScreen> createState() => _LiveTripScreenState();
}

class _LiveTripScreenState extends State<LiveTripScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _trip;
  Map<String, dynamic>? _captain;

  bool _loading = true;
  bool _canceling = false;
  bool _ratingShown = false;
  bool _cancelDialogShown = false;

  StreamSubscription<Position>? _customerGps;
  Position? _customerPosition;
  DateTime? _lastCustomerFix;
  String? _captainId;

  TripRealtimeLease? _tripChannel;
  RealtimeChannel? _captainChannel;
  bool _loadInFlight = false;
  String? _loadError;
  bool _appInForeground = true;
  bool _syncingTrip = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTrip();
    unawaited(_startCustomerLocation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _tripChannel?.unsubscribe();
    _captainChannel?.unsubscribe();
    _customerGps?.cancel();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appInForeground = true;
      // Realtime sockets may miss UPDATEs while Android suspends the app.
      _subscribeToTrip();
      _refreshTripStatus();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _appInForeground = false;
    }
  }

  Future<void> _startCustomerLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
      if (!mounted || _customerGps != null) return;
      _customerGps =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              distanceFilter: 25,
            ),
          ).listen(
            (p) {
              if (!mounted ||
                  !_appInForeground ||
                  (_lastCustomerFix != null &&
                      DateTime.now().difference(_lastCustomerFix!) <
                          const Duration(seconds: 10))) {
                return;
              }
              _lastCustomerFix = DateTime.now();
              setState(() => _customerPosition = p);
            },
            onError: (_) {
              /* Optional blue dot never blocks the trip. */
            },
          );
    } catch (_) {}
  }

  Future<void> _refreshTripStatus({bool manual = false}) async {
    if (!mounted || _syncingTrip) return;
    _syncingTrip = true;
    try {
      final fresh = await SupabaseService.instance.getTripById(widget.tripId);
      if (!mounted) return;
      if (fresh == null) {
        if (manual) _showError(context.strings.live284968d7);
        return;
      }
      _applyTripUpdate(Map<String, dynamic>.from(fresh));
      if (manual) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(
              context.strings.live182cb52e,
              style: TextStyle(),
            ),
          ),
        );
      }
    } catch (_) {
      if (manual && mounted) _showError(context.strings.live6ef3859c);
    } finally {
      _syncingTrip = false;
    }
  }

  // ===========================================================================
  // LOAD
  // ===========================================================================

  Future<void> _loadTrip() async {
    if (_loadInFlight) return;
    _loadInFlight = true;
    try {
      final trip = await SupabaseService.instance.getTripById(widget.tripId);
      if (trip == null) throw StateError('trip_not_found');
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _captain = Map<String, dynamic>.from(
          (trip['captain_context'] as Map?) ?? {},
        );
        _captainId = trip['captain_id']?.toString();
        _loading = false;
        _loadError = null;
      });
      _subscribeToTrip();
      _applyTripUpdate(trip);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = tripLoadErrorV10(error);
        });
      }
    } finally {
      _loadInFlight = false;
    }
  }

  Future<void> _loadCaptain(String captainId) async {
    final trip = await SupabaseService.instance.getTripById(widget.tripId);
    if (mounted && trip != null) _applyTripUpdate(trip);
  }

  // ===========================================================================
  // TRIP REALTIME
  // ===========================================================================

  void _subscribeToTrip() {
    _tripChannel ??= SupabaseService.instance.subscribeToTripStatus(
      widget.tripId,
      (data) => _applyTripUpdate(Map<String, dynamic>.from(data)),
    );
  }

  void _applyTripUpdate(Map<String, dynamic> data) {
    if (!mounted) return;

    final updatedTrip = normalizeTripV10(data);

    final oldCaptainId = _captainId;
    final newCaptainId = updatedTrip['captain_id']?.toString();

    setState(() {
      _trip = <String, dynamic>{...?_trip, ...updatedTrip};
      if (updatedTrip['captain_context'] is Map &&
          (updatedTrip['captain_context'] as Map).isNotEmpty) {
        _captain = normalizeTripV10(updatedTrip['captain_context'] as Map);
        _captainId = _trip?['captain_id']?.toString();
      }
      final location = updatedTrip['live_location'];
      if (location is Map) {
        _captain = {
          ...?_captain,
          ...normalizeTripV10({
            'current_latitude': location['latitude'],
            'current_longitude': location['longitude'],
            'location_updated_at': location['recorded_at'],
          }),
        };
      }
    });

    if (newCaptainId != null &&
        newCaptainId.isNotEmpty &&
        newCaptainId != oldCaptainId &&
        updatedTrip['captain_context'] is! Map) {
      _loadCaptain(newCaptainId);
    }

    final status = updatedTrip['trip_status']?.toString();

    if (status == 'completed' &&
        !_ratingShown &&
        _trip?['rating_submitted'] != true) {
      _ratingShown = true;

      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          _showRatingDialog();
        }
      });
    }

    if (status == 'cancelled' && !_cancelDialogShown) {
      _cancelDialogShown = true;

      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _showCancelledDialog();
        }
      });
    }
  }

  // ===========================================================================
  // CAPTAIN LOCATION REALTIME
  // ===========================================================================

  // ===========================================================================
  // CHAT
  // ===========================================================================

  bool get _canCancel {
    final status = _trip?['trip_status']?.toString();

    // Both parties may cancel until the captain presses Start trip.
    // The server remains authoritative if the status changes meanwhile.
    return const {
          'requested',
          'offer_received',
          'accepted',
          'arriving',
          'arrived',
        }.contains(status) &&
        _trip?['started_at'] == null;
  }

  Future<void> _cancelTrip() async {
    if (!_canCancel || _canceling) return;

    // Read-only preview of the administrator-configured fee.
    // The database decides the real status and accounting at cancellation.
    Map<String, dynamic>? cancellationInfo;
    try {
      cancellationInfo = await SupabaseService.instance
          .getCustomerCancellationPreview(widget.tripId);
    } catch (_) {}
    if (!mounted) return;
    final free = cancellationInfo?['free'] == true;
    final amount = cancellationInfo?['fee'];
    final feeText = amount is num
        ? context.strings.moneyValue(amount.toStringAsFixed(2))
        : context.strings.liveeed45423;
    final status = _trip?['trip_status']?.toString();
    final searching = const {'requested', 'offer_received'}.contains(status);
    final message = searching
        ? context.strings.livefc43d3fe
        : free
        ? context.strings.live47420271
        : cancellationInfo?['free'] == false
        ? context.strings.liveCancellationAfterGrace(feeText)
        : context.strings.live3006aec8;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title:  Text(
              context.strings.live6aef022f,
              style: TextStyle(
                
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              context.strings.liveCancelConfirm(message),
              style: const TextStyle(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child:  Text(
                  context.strings.livecb822418,
                  style: TextStyle(),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorLight,
                  foregroundColor: Colors.white,
                ),
                child:  Text(
                  context.strings.live6aef022f,
                  style: TextStyle(),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _canceling = true;
    });

    try {
      // A free search cancellation can NEVER fall back to the paid path.
      // If a captain accepted simultaneously the guarded server call rejects
      // without charging either party; refresh the trip state instead.
      if (searching) {
        await SupabaseService.instance.cancelCustomerSearchV37(widget.tripId);
      } else {
        await SupabaseService.instance.cancelTrip(
          widget.tripId,
          reason: 'customer_cancelled_trip',
        );
      }

      if (!mounted) return;

      context.go(AppRoutes.homeScreen);
    } catch (error) {
      if (!mounted) return;
      // A captain may have accepted while the search-cancel dialog was open.
      // Refresh the server state instead of falling back to a paid RPC.
      try { await _loadTrip(); } catch (_) {}
      if (!mounted) return;
      setState(() {
        _canceling = false;
      });
      // Search cancellation is fee-free and must not fall back to a paid
      // cancellation if a captain was assigned during the dialog.
      _showError(localizedCancellationFailure(context, error));
    }
  }

  // ===========================================================================
  // RATING
  // ===========================================================================

  Future<void> _showCancelledDialog() async {
    Map<String, dynamic>? receipt;
    if (GrowthService.buildEnabled) {
      try {
        receipt = await GrowthService().call(
          'growth_cancellation_receipt_v1', {'p_trip': widget.tripId},
        );
      } catch (_) {
        // An unavailable receipt must never be displayed as a successful refund.
      }
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title:  Text(context.strings.livede0b18e1),
        content: GrowthService.buildEnabled
            ? CancellationReceiptCard(receipt: receipt)
            :  Text(
          context.strings.liveac9ac0e6,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(d);
              context.go(AppRoutes.homeScreen);
            },
            child:  Text(context.strings.live65d25b44),
          ),
        ],
      ),
    );
  }

  Future<void> _showRatingDialog() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TripRatingSheetV10(
        tripId: widget.tripId,
        captainName: (_captain?['full_name']?.toString() ?? context.strings.live2f225a03)
            .split(' ')
            .first,
      ),
    );
  }

  Future<void> _openTripSupport() async {
    final uri = Uri.parse(
      'https://wa.me/201031517830?text=${Uri.encodeComponent(context.strings.liveSupportMessage(widget.tripId))}',
    );
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) _showError(context.strings.live6539544e);
    } catch (_) {
      if (mounted) _showError(context.strings.live6539544e);
    }
  }

  Widget _buildTripSupportButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _openTripSupport,
        icon: const Icon(Icons.support_agent_rounded, color: AppTheme.gold),
        label:  Text(
          context.strings.live37ccdeb7,
          style: TextStyle(
            
            color: AppTheme.gold,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.gold),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: isDark ? 0 : 0.5,
          shadowColor: Colors.black12,
          title: Text(
            context.strings.live99f2c8a6,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          centerTitle: true,
          actions: [
            TextButton.icon(
              onPressed: _syncingTrip
                  ? null
                  : () => _refreshTripStatus(manual: true),
              icon: Icon(Icons.refresh_rounded, size: 18, color: primary),
              label: Text(
                context.strings.livedcf45bf6,
                style: TextStyle(
                  color: primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          leading: IconButton(
            onPressed: () {
              context.go(AppRoutes.homeScreen);
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: _loading
            ? const TripLoadingV10()
            : _trip == null
            ? _buildError()
            : _buildBody(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.errorLight,
              size: 52,
            ),
            const SizedBox(height: 14),
            Text(
              _loadError ?? context.strings.live9a86a128,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                _loadTrip();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                context.strings.live14d5786f,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final status = _trip?['trip_status']?.toString();

    if (!_isLiveStatus(status) || _captainId == null || _captain == null) {
      return _buildSearching();
    }

    return _buildLiveTrip();
  }

  // ===========================================================================
  // SEARCHING
  // ===========================================================================

  Widget _buildSearching() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final status = _trip?['trip_status']?.toString();
    final note = _trip?['customer_note']?.toString();
    final incentive = _number(_trip?['incentive_amount']);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? const Color(0xFF2A3355) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? const Color(0x33000000) : const Color(0x0A0F172A),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.radar_rounded,
                    color: primary,
                    size: 64,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    status == 'offer_received'
                        ? context.strings.live5a6daebf
                        : context.strings.live3c6518b4,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.strings.live4babb638,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildRouteTimeline(),
            if (note != null && note.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildNoteCard(note),
            ],
            if (incentive > 0) ...[
              const SizedBox(height: 14),
              _buildIncentiveCard(incentive),
            ],
            const SizedBox(height: 24),
            CircularProgressIndicator(color: primary),
            const SizedBox(height: 20),
            if (status != 'completed' && status != 'cancelled')
              _buildTripSupportButton(),
            const SizedBox(height: 14),
            if (_canCancel) _buildCancelButton(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // LIVE TRIP
  // ===========================================================================

  Widget _buildLiveTrip() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _trip?['trip_status']?.toString();

    final captainName = _stringValue(
      _captain?['full_name'],
      context.strings.live2f225a03,
    );

    final phone = _firstString(_captain, const [
      'phone',
      'phone_number',
      'mobile',
    ]);

    final photo = _firstString(_captain, const [
      'profile_photo_url',
      'profile_photo',
      'photo_url',
    ]);

    final customerNote = _firstString(_trip, const [
      'customer_note',
      'captain_note',
      'note',
    ]);

    final incentive = _number(_trip?['incentive_amount']);
    final captainLat = _numberOrNull(_captain?['current_latitude']);
    final captainLng = _numberOrNull(_captain?['current_longitude']);
    final pickupLat = _numberOrNull(_trip?['pickup_latitude']);
    final pickupLng = _numberOrNull(_trip?['pickup_longitude']);
    final destinationLat = _numberOrNull(_trip?['destination_latitude']);
    final destinationLng = _numberOrNull(_trip?['destination_longitude']);

    return Stack(
      children: [
        Positioned.fill(
          child: SmoothLiveTripMap(
            topInset: 76,
            customerLat: _customerPosition?.latitude,
            customerLng: _customerPosition?.longitude,
            tripStatus: status,
            serviceType: _trip?['service_type']?.toString(),
            locationUpdatedAt: DateTime.tryParse(
              _captain?['location_updated_at']?.toString() ?? '',
            ),
            captainLat: captainLat,
            captainLng: captainLng,
            pickupLat: pickupLat,
            pickupLng: pickupLng,
            destinationLat: destinationLat,
            destinationLng: destinationLng,
          ),
        ),
        Positioned(
          top: 12,
          left: 14,
          right: 14,
          child: _buildStatusHeader(status),
        ),
        DraggableScrollableSheet(
          initialChildSize: status == 'completed' ? .62 : .38,
          minChildSize: .24,
          maxChildSize: .85,
          snap: true,
          builder: (context, controller) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.5) : const Color(0x1A0F172A),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
              children: [
                if (_trip?['ride_category_id_v3'] != null) ...[
                  if (const {'accepted', 'arriving', 'arrived'}.contains(status))
                    CustomerTripSafetyCode(tripId: _trip!['id'].toString()),
                  TripPromisePanel(
                    tripId: _trip!['id'].toString(),
                    status: '${_trip!['trip_status']}',
                  ),
                ],
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                if (status == 'completed') _buildPaymentCard(status),
                _buildModernDriverHeader(
                  name: captainName,
                  phone: phone,
                  photo: photo,
                ),
                const SizedBox(height: 12),
                _buildPaymentMethodStrip(),
                const SizedBox(height: 12),
                _buildRouteTimeline(),
                if (incentive > 0 && status != 'completed') ...[
                  const SizedBox(height: 12),
                  _buildIncentiveCard(incentive),
                ],
                if (customerNote != null && customerNote.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildNoteCard(customerNote),
                ],
                if (status != 'completed' && status != 'cancelled') ...[
                  const SizedBox(height: 12),
                  _buildTripSupportButton(),
                ],
                if (_canCancel) ...[
                  const SizedBox(height: 12),
                  _buildCancelButton(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusHeader(String? status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _statusColor(status, isDark: isDark);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xEE10192B) : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: isDark ? 0.45 : 0.35)),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33000000) : const Color(0x140F172A),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_statusIcon(status), color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusSubtitle(status),
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDriverHeader({
    required String name,
    required String? phone,
    required String? photo,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final rating = _numberOrNull(_captain?['rating']) ??
        _numberOrNull(_captain?['captain_rating']) ??
        4.9;
    final vehicleModel = _firstString(_captain, const [
      'vehicle_model',
      'car_model',
      'vehicle_brand',
      'car_brand',
    ]) ?? '';
    final plateNumber = _firstString(_captain, const [
      'plate_number',
      'vehicle_plate',
      'car_plate',
    ]) ?? '';
    final vehicleDetails = [vehicleModel, plateNumber]
        .where((s) => s.trim().isNotEmpty)
        .join(' • ');

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => CaptainProfileSheetV10(tripId: widget.tripId),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF2A3355) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            // Circular action buttons (Chat & Call) on left
            ListenableBuilder(
              listenable: TripChatInbox.instance,
              builder: (context, _) {
                final hasUnread = TripChatInbox.instance.hasUnread(widget.tripId);
                return _buildCircleActionButton(
                  icon: Icons.chat_bubble_rounded,
                  isDark: isDark,
                  color: primary,
                  hasBadge: hasUnread,
                  onPressed: () => context.push('/trip-chat?tripId=${widget.tripId}'),
                );
              },
            ),
            const SizedBox(width: 8),
            if (phone != null && phone.trim().isNotEmpty)
              _buildCircleActionButton(
                icon: Icons.phone_rounded,
                isDark: isDark,
                color: const Color(0xFF10B981),
                onPressed: () => _callNumber(phone),
              ),
            const SizedBox(width: 14),
            // Driver info in center
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 16),
                      const SizedBox(width: 3),
                      Text(
                        rating.toStringAsFixed(1),
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (vehicleDetails.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '• $vehicleDetails',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Driver avatar with small car badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                _ProfileAvatar(imageUrl: photo, radius: 26),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF161F30) : Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.directions_car_rounded,
                      size: 11,
                      color: isDark ? const Color(0xFF0B0F19) : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required bool isDark,
    required Color color,
    required VoidCallback onPressed,
    bool hasBadge = false,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: color.withValues(alpha: isDark ? 0.16 : 0.10),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                icon,
                size: 20,
                color: color,
              ),
            ),
          ),
        ),
        if (hasBadge)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF161F30) : Colors.white,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentMethodStrip() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paymentMethod = _trip?['payment_method']?.toString() ?? 'cash';
    final isCash = paymentMethod == 'cash' || paymentMethod == 'نقدي';
    final methodLabel = isCash ? 'الدفع نقداً عند الوصول' : 'محفظة فيتو الرقمية';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3355) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: Color(0xFF10B981),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              methodLabel,
              style: TextStyle(
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(
            Icons.chevron_left_rounded,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTimeline() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final pickup = _firstString(_trip, const ['pickup_address', 'pickup_name']) ??
        context.strings.live5a0374f3;
    final destination = _firstString(_trip, const [
      'destination_address',
      'destination_name',
    ]) ?? context.strings.live5a0374f3;

    final service = _trip?['service_type']?.toString() ??
        _trip?['vehicle_type']?.toString() ??
        context.strings.livea674a023;
    final categoryText = tripCategoryLabel(context, _trip ?? {}, _serviceLabel(service));

    final distance = _numberOrNull(_trip?['distance_km']);
    final duration = _numberOrNull(_trip?['duration_minutes']);
    final fare = _numberOrNull(_trip?['final_fare'] ?? _trip?['estimated_fare'] ?? _trip?['fare_amount']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3355) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vertical timeline line and dots
              Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primary, width: 3),
                      color: isDark ? const Color(0xFF111827) : Colors.white,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 38,
                    color: isDark ? const Color(0xFF2A3355) : const Color(0xFFCBD5E1),
                  ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Addresses
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.strings.liveae7ae56d,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pickup,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.strings.live8b068efc,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF2A3355) : const Color(0xFFE2E8F0),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricPill(
                icon: Icons.directions_car_rounded,
                label: categoryText,
                isDark: isDark,
              ),
              if (distance != null) ...[
                const SizedBox(width: 8),
                _buildMetricPill(
                  icon: Icons.route_rounded,
                  label: context.strings.distanceValue(distance.toStringAsFixed(1)),
                  isDark: isDark,
                ),
              ],
              if (duration != null) ...[
                const SizedBox(width: 8),
                _buildMetricPill(
                  icon: Icons.schedule_rounded,
                  label: context.strings.durationValue(duration.toStringAsFixed(0)),
                  isDark: isDark,
                ),
              ],
              const Spacer(),
              if (fare != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.strings.moneyValue(fare.toStringAsFixed(0)),
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(String note) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primary.withValues(alpha: isDark ? 0.35 : 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sticky_note_2_rounded, color: primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.strings.live65fc6a0a,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  note,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncentiveCard(double incentive) {
    const successColor = Color(0xFF10B981);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: successColor.withValues(alpha: isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: successColor.withValues(alpha: isDark ? 0.35 : 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: successColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.strings.liveIncentive(incentive.toStringAsFixed(2)),
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PAYMENT
  // ===========================================================================

  Widget _buildPaymentCard(String? status) {
    if (status != 'completed') {
      return const SizedBox.shrink();
    }
    return TripFinancialCardV11(trip: _trip ?? const {});
  }

  // ===========================================================================

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _canceling ? null : _cancelTrip,
        icon: _canceling
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.errorLight),
              )
            : const Icon(Icons.cancel_outlined, size: 19),
        label: Text(
          context.strings.live6aef022f,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.errorLight,
          side: const BorderSide(color: AppTheme.errorLight, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  bool _isLiveStatus(String? status) {
    return status == 'accepted' ||
        status == 'arriving' ||
        status == 'arrived' ||
        status == 'started' ||
        status == 'completed';
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'requested':
        return context.strings.live3c6518b4;
      case 'offer_received':
        return context.strings.live5a6daebf;
      case 'accepted':
        return context.strings.liveb7d72a98;
      case 'arriving':
        return context.strings.live2f7a3366;
      case 'arrived':
        return context.strings.live0676addf;
      case 'started':
        return context.strings.liveda8838dc;
      case 'completed':
        return context.strings.livece7c7ba9;
      case 'cancelled':
        return context.strings.livede0b18e1;
      default:
        return context.strings.live8c2ae1f8;
    }
  }

  String _statusSubtitle(String? status) {
    switch (status) {
      case 'accepted':
        return context.strings.livebdfe2de5;
      case 'arriving':
        return context.strings.live6467fed6;
      case 'arrived':
        return context.strings.live1a58a508;
      case 'started':
        return context.strings.live340df273;
      case 'completed':
        return context.strings.live08e09e69;
      case 'cancelled':
        return context.strings.live4a4aa18a;
      default:
        return context.strings.livea7ecc2bc;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle_rounded;
      case 'arriving':
        return Icons.directions_car_rounded;
      case 'arrived':
        return Icons.person_pin_circle_rounded;
      case 'started':
        return Icons.route_rounded;
      case 'completed':
        return Icons.task_alt_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.sync_rounded;
    }
  }

  Color _statusColor(String? status, {bool isDark = true}) {
    switch (status) {
      case 'accepted':
        return isDark ? const Color(0xFF64B5F6) : const Color(0xFF3B82F6);
      case 'arriving':
        return isDark ? AppTheme.gold : const Color(0xFFE5A800);
      case 'arrived':
      case 'started':
      case 'completed':
        return const Color(0xFF10B981);
      case 'cancelled':
        return AppTheme.errorLight;
      default:
        return isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    }
  }

  String _serviceLabel(String service) {
    switch (service.toLowerCase()) {
      case 'car':
      case 'car_ride':
      case 'vehicle':
      case 'سيارة':
        return context.strings.live89aef3a3;

      case 'motorcycle':
      case 'motorcycle_ride':
      case 'motorbike':
      case 'bike':
      case 'موتوسيكل':
        return context.strings.live80a51d6a;

      case 'package':
      case 'parcel':
      case 'delivery':
      case 'طرد':
        return context.strings.live113cb058;

      default:
        return context.strings.receiptc99f71b7;
    }
  }

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double? _numberOrNull(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    final parsed = double.tryParse(value?.toString() ?? '');

    return parsed;
  }

  String _stringValue(dynamic value, String fallback) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return fallback;
    }

    return text;
  }

  String? _firstString(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;

    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return null;
  }

  Future<void> _callNumber(String phone) async {
    final uri = Uri.parse('tel:${phone.trim()}');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (mounted) {
        _showError(context.strings.livec9a1bb1e);
      }
    } catch (_) {
      if (mounted) {
        _showError(context.strings.livec9a1bb1e);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
          style: const TextStyle(),
        ),
        backgroundColor: AppTheme.errorLight,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ============================================================================
// PROFILE AVATAR
// ============================================================================

class _ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;

  const _ProfileAvatar({required this.imageUrl, required this.radius});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();

    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppTheme.gold.withAlpha(30),
        child: Icon(Icons.person_rounded, color: AppTheme.gold, size: radius),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.gold.withAlpha(30),
      backgroundImage: captainPhotoV16(url),
      onBackgroundImageError: (_, __) {},
    );
  }
}

// ============================================================================
// LIVE MAP
// ============================================================================

