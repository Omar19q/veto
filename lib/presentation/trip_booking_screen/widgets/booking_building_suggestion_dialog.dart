import 'dart:async';
import '../../../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../services/pickup_building_suggestion_backend.dart';
import '../../../theme/app_theme.dart';

class _BuildingLocationFailure implements Exception {
  final String code;
  final String? accuracy;
  const _BuildingLocationFailure(this.code, [this.accuracy]);
}

/// Only a pickup helper. A customer GPS reading is submitted for admin review;
/// it does not publicly verify a building or replace an existing admin location.
class PickupBuildingSuggestion {
  final String area;
  final int number;
  final double latitude;
  final double longitude;

  const PickupBuildingSuggestion({
    required this.area,
    required this.number,
    required this.latitude,
    required this.longitude,
  });
}

class BookingBuildingSuggestionDialog extends StatefulWidget {
  final PickupBuildingSuggestionBackend? backend;
  final String initialArea;
  final String initialNumber;

  const BookingBuildingSuggestionDialog({
    super.key,
    this.backend,
    required this.initialArea,
    required this.initialNumber,
  });

  @override
  State<BookingBuildingSuggestionDialog> createState() =>
      _BookingBuildingSuggestionDialogState();
}

class _BookingBuildingSuggestionDialogState
    extends State<BookingBuildingSuggestionDialog> {
  static const _areas = <String>[
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
  ];

  late final PickupBuildingSuggestionBackend _backend;
  StreamSubscription<String?>? _auth;
  String? _owner;
  bool _invalidated = false;
  bool get _current =>
      mounted &&
      !_invalidated &&
      _owner != null &&
      _backend.accountId == _owner;
  late final TextEditingController _number;
  late String _area;
  Position? _position;
  bool _atBuilding = false;
  bool _locating = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _backend = widget.backend ?? PickupBuildingSuggestionBackend();
    _owner = _backend.accountId;
    _auth = _backend.accountChanges.listen((id) {
      if (!mounted || id == _owner) return;
      _invalidated = true;
      _number.clear();
      setState(() {
        _position = null;
        _error = null;
      });
      Navigator.of(context).pop();
    });
    _area = _areas.contains(widget.initialArea)
        ? widget.initialArea
        : _areas.first;
    _number = TextEditingController(text: widget.initialNumber);
  }

  @override
  void dispose() {
    _auth?.cancel();
    _number.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    if (!_current) return;
    final n = int.tryParse(_number.text.trim());
    if (n == null || n < 1 || n > 590) {
      setState(() => _error = context.strings.buildingNumberFirst);
      return;
    }
    if (!_atBuilding) {
      setState(() => _error = context.strings.buildingConfirmFirst);
      return;
    }
    setState(() {
      _locating = true;
      _error = null;
      _position = null;
    });

    try {
      if (!await _backend.locationEnabled()) {
        throw const _BuildingLocationFailure('disabled');
      }
      if (!_current) return;
      var permission = await _backend.permission();
      if (!_current) return;
      if (permission == LocationPermission.denied) {
        permission = await _backend.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const _BuildingLocationFailure('permission');
      }

      if (!_current) return;
      final position = await _backend.locate();
      if (!_current) return;
      if (!position.accuracy.isFinite ||
          position.accuracy <= 0 ||
          position.accuracy > 100) {
        throw _BuildingLocationFailure(
          'accuracy',
          position.accuracy.toStringAsFixed(0),
        );
      }
      if (!position.latitude.isFinite ||
          !position.longitude.isFinite ||
          position.latitude < 29.90 ||
          position.latitude > 30.10 ||
          position.longitude < 30.95 ||
          position.longitude > 31.25) {
        throw const _BuildingLocationFailure('outside');
      }
      setState(() => _position = position);
    } catch (e) {
      if (_current) {
        final message = switch (e) {
          _BuildingLocationFailure(code: 'disabled') =>
            context.strings.buildingGpsEnable,
          _BuildingLocationFailure(code: 'permission') =>
            context.strings.buildingGpsAllow,
          _BuildingLocationFailure(code: 'outside') =>
            context.strings.buildingOutside,
          _BuildingLocationFailure(code: 'accuracy', :final accuracy) =>
            context.strings.buildingAccuracyWeak(accuracy ?? '—'),
          _ => context.strings.buildingLocationInvalid,
        };
        setState(() => _error = message);
      }
    } finally {
      if (_current) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (!_current) return;
    final n = int.tryParse(_number.text.trim());
    if (n == null || n < 1 || n > 590) {
      setState(() => _error = context.strings.buildingNumberInvalid);
      return;
    }
    if (!_atBuilding || _position == null) {
      setState(() => _error = context.strings.buildingLocateFirst);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _backend.submit(area: _area, number: n, position: _position!);
      if (!_current) return;
      Navigator.of(context).pop(
        PickupBuildingSuggestion(
          area: _area,
          number: n,
          latitude: _position!.latitude,
          longitude: _position!.longitude,
        ),
      );
    } catch (e) {
      if (!_current) return;
      final raw = e.toString();
      final message = raw.contains('building_already_reviewed')
          ? context.strings.buildingReviewed
          : raw.contains('daily_submission_limit')
          ? context.strings.buildingDailyLimit
          : raw.contains('session_required')
          ? context.strings.buildingSession
          : raw.contains('gps_location_or_accuracy_invalid')
          ? context.strings.buildingLocationInvalid
          : raw.contains('customer_account_required')
          ? context.strings.buildingCustomerRequired
          : context.strings.buildingUnconfirmed;
      setState(() => _error = message);
    } finally {
      if (_current) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: 13,
    );
    return Directionality(
      textDirection: Directionality.of(context),
      child: AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          context.strings.buildingTitle,
          style: TextStyle(
            
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        scrollable: true,
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.strings.buildingIntro, style: textStyle),
              SizedBox(height: 14),
              Text(context.strings.buildingAreaLetter, style: textStyle),
              SizedBox(height: 5),
              DropdownButtonFormField<String>(
                value: _area,
                isExpanded: true,
                dropdownColor: Theme.of(context).colorScheme.surfaceContainer,
                style: textStyle,
                items: _areas
                    .map(
                      (letter) => DropdownMenuItem<String>(
                        value: letter,
                        child: Text(
                          context.strings.buildingAreaValue(letter),
                          style: textStyle,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (_locating || _saving)
                    ? null
                    : (v) {
                        if (v != null)
                          setState(() {
                            _area = v;
                            _position = null;
                            _error = null;
                          });
                      },
              ),
              SizedBox(height: 12),
              Text(context.strings.buildingNumber, style: textStyle),
              SizedBox(height: 5),
              TextField(
                controller: _number,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                style: textStyle,
                enabled: !_locating && !_saving,
                decoration: InputDecoration(
                  hintText: context.strings.buildingNumberHint,
                  hintStyle: TextStyle(
                    
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                onChanged: (_) => setState(() {
                  _position = null;
                  _error = null;
                }),
              ),
              SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _atBuilding,
                onChanged: (_locating || _saving)
                    ? null
                    : (v) => setState(() {
                        _atBuilding = v ?? false;
                        if (!_atBuilding) _position = null;
                      }),
                activeColor: AppTheme.gold,
                title: Text(
                  context.strings.buildingAtLocation,
                  style: textStyle,
                ),
              ),
              OutlinedButton.icon(
                onPressed: (_locating || _saving) ? null : _locate,
                icon: _locating
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.my_location_rounded),
                label: Text(
                  _locating
                      ? context.strings.buildingLocating
                      : context.strings.buildingLocate,
                  style: TextStyle(),
                ),
              ),
              if (_position != null) ...[
                SizedBox(height: 8),
                Text(
                  context.strings.buildingAccuracyCaptured(
                    _position!.accuracy.toStringAsFixed(0),
                  ),
                  style: TextStyle(
                    
                    color: AppTheme.successLight,
                  ),
                ),
              ],
              SizedBox(height: 8),
              Text(
                context.strings.buildingReviewNotice,
                style: TextStyle(
                  
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (_error != null) ...[
                SizedBox(height: 9),
                Text(
                  _error!,
                  style: TextStyle(
                    
                    fontSize: 12,
                    color: AppTheme.errorLight,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(
              context.strings.buildingCancel,
              style: TextStyle(),
            ),
          ),
          ElevatedButton(
            onPressed:
                (_position == null || !_atBuilding || _locating || _saving)
                ? null
                : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.primary,
            ),
            child: Text(
              _saving
                  ? context.strings.buildingSaving
                  : context.strings.buildingSave,
              style: TextStyle(
                
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
