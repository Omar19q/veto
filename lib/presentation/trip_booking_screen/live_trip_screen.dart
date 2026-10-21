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
import '../../widgets/trip_chat_button.dart';
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
          permission != LocationPermission.whileInUse)
        return;
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
                          const Duration(seconds: 10)))
                return;
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
      if (mounted)
        setState(() {
          _loading = false;
          _loadError = tripLoadErrorV10(error);
        });
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          title:  Text(
            context.strings.live99f2c8a6,
            style: TextStyle( fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
          actions: [
            TextButton.icon(
              onPressed: _syncingTrip
                  ? null
                  : () => _refreshTripStatus(manual: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label:  Text(
                context.strings.livedcf45bf6,
                style: TextStyle(
                  
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: TextButton.styleFrom(foregroundColor: AppTheme.gold),
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
                
                color: AppTheme.textPrimary,
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
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.primary,
              ),
              child:  Text(
                context.strings.live14d5786f,
                style: TextStyle(),
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

              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                color: AppTheme.surface,

                borderRadius: BorderRadius.circular(20),

                border: Border.all(color: AppTheme.cardBorder),
              ),

              child: Column(
                children: [
                  const Icon(
                    Icons.radar_rounded,

                    color: AppTheme.gold,

                    size: 64,
                  ),

                  const SizedBox(height: 14),

                  Text(
                    status == 'offer_received'
                        ? context.strings.live5a6daebf
                        : context.strings.live3c6518b4,

                    style: const TextStyle(
                      

                      color: AppTheme.textPrimary,

                      fontSize: 20,

                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 8),

                   Text(
                    context.strings.live4babb638,

                    textAlign: TextAlign.center,

                    style: TextStyle(
                      

                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            _buildTripInfoCard(),

            if (note != null && note.trim().isNotEmpty) ...[
              const SizedBox(height: 14),

              _buildNoteCard(note),
            ],

            if (incentive > 0) ...[
              const SizedBox(height: 14),

              _buildIncentiveCard(incentive),
            ],

            const SizedBox(height: 20),

            const CircularProgressIndicator(color: AppTheme.gold),

            const SizedBox(height: 14),

            if (status != 'completed' && status != 'cancelled')
              _buildTripSupportButton(),

            const SizedBox(height: 20),

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
    final status = _trip?['trip_status']?.toString();

    final captainName = _stringValue(_captain?['full_name'], context.strings.live2f225a03);

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
          initialChildSize: status=='completed' ? .62 : .36,
          minChildSize: .24,
          maxChildSize: .82,
          snap: true,
          builder: (context, controller) => Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
              children: [
                if(_trip?['ride_category_id_v3']!=null)...[if(const {'accepted','arriving','arrived'}.contains(status))CustomerTripSafetyCode(tripId:_trip!['id'].toString()),TripPromisePanel(tripId:_trip!['id'].toString(),status:'${_trip!['trip_status']}')],
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: .3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                if(status=='completed')_buildPaymentCard(status),
                _buildCaptainCard(
                  name: captainName,
                  phone: phone,
                  photo: photo,
                ),
                const SizedBox(height: 12),
                _buildTripInfoCard(),
                const SizedBox(height: 12),
                _buildChatCard(),

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
    final accent = _statusColor(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xEE10192B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: .55)),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .16),
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
                  style: const TextStyle(
                    
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusSubtitle(status),
                  style: const TextStyle(
                    
                    color: Color(0xFFC9D3E7),
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

  Widget _buildCaptainCard({
    required String name,
    required String? phone,
    required String? photo,
  }) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => CaptainProfileSheetV10(tripId: widget.tripId),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            _ProfileAvatar(imageUrl: photo, radius: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    context.strings.live2f225a03,
                    style: TextStyle(
                      
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (phone != null && phone.trim().isNotEmpty)
                    Text(
                      phone,
                      style: const TextStyle(
                        
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (phone != null && phone.trim().isNotEmpty)
              IconButton(
                tooltip: context.strings.live606af07c,
                onPressed: () {
                  _callNumber(phone);
                },
                icon: const Icon(
                  Icons.phone_rounded,
                  color: AppTheme.successLight,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TRIP INFO
  // ===========================================================================

  Widget _buildTripInfoCard() {
    final pickup =
        _firstString(_trip, const ['pickup_address', 'pickup_name']) ??
        context.strings.live5a0374f3;

    final destination =
        _firstString(_trip, const [
          'destination_address',
          'destination_name',
        ]) ??
        context.strings.live5a0374f3;

    final service =
        _trip?['service_type']?.toString() ??
        _trip?['vehicle_type']?.toString() ??
        context.strings.livea674a023;

    final distance = _numberOrNull(_trip?['distance_km']);

    final duration = _numberOrNull(_trip?['duration_minutes']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car_rounded, color: AppTheme.gold),
              const SizedBox(width: 8),
               Text(
                context.strings.liveb075cda8,
                style: TextStyle(
                  
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                tripCategoryLabel(context,_trip??{},_serviceLabel(service)),
                style: const TextStyle(
                  
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: context.strings.liveae7ae56d,
            value: pickup,
            icon: Icons.my_location_rounded,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: context.strings.live8b068efc,
            value: destination,
            icon: Icons.location_on_rounded,
          ),
          if (distance != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: context.strings.livedd00b654,
              value: context.strings.distanceValue(distance.toStringAsFixed(1)),
              icon: Icons.route_rounded,
            ),
          ],
          if (duration != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: context.strings.livea7947509,
              value: context.strings.durationValue(duration.toStringAsFixed(0)),
              icon: Icons.schedule_rounded,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoteCard(String note) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.gold.withAlpha(18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.gold.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sticky_note_2_rounded, color: AppTheme.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(
                  context.strings.live65fc6a0a,
                  style: TextStyle(
                    
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  note,
                  style: const TextStyle(
                    
                    color: AppTheme.textSecondary,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successLight.withAlpha(18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.successLight.withAlpha(90)),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: AppTheme.successLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.strings.liveIncentive(incentive.toStringAsFixed(2)),
              style: const TextStyle(
                
                color: AppTheme.textPrimary,
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

  Widget _buildChatCard() =>
      TripChatButton(tripId: widget.tripId, label: context.strings.live15d8bb61);

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _canceling ? null : _cancelTrip,
        icon: _canceling
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cancel_outlined),
        label:  Text(
          context.strings.live6aef022f,
          style: TextStyle( fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.errorLight,
          side: const BorderSide(color: AppTheme.errorLight),
          padding: const EdgeInsets.symmetric(vertical: 13),
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

  Color _statusColor(String? status) {
    switch (status) {
      case 'accepted':
        return const Color(0xFF64B5F6);
      case 'arriving':
        return AppTheme.gold;
      case 'arrived':
      case 'started':
      case 'completed':
        return AppTheme.successLight;
      case 'cancelled':
        return AppTheme.errorLight;
      default:
        return AppTheme.textSecondary;
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
      } else {
        _showError(context.strings.livec9a1bb1e);
      }
    } catch (_) {
      _showError(context.strings.livec9a1bb1e);
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
// INFO ROW
// ============================================================================

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.gold, size: 20),
        const SizedBox(width: 10),
        SizedBox(
          width: 65,
          child: Text(
            label,
            style: const TextStyle(
              
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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

