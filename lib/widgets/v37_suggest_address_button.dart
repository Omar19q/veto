import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/strings.dart';
import '../services/customer_city_scope_v38.dart';
import '../services/customer_location_state.dart';
import '../services/address_suggestion_service.dart';
import '../services/pending_address_draft.dart';
import '../services/supabase_service.dart';

/// Same entry points and Hadayek restriction; submission is independent of ride coverage.
class V37SuggestAddressButton extends StatelessWidget {
  static Future<void> correct(
    BuildContext context,
    Map<String, dynamic> original,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SuggestionForm(
        city: '${original['city_label'] ?? ''}',
        building: '${original['building_number'] ?? ''}',
        lat: double.tryParse('${original['latitude']}'),
        lng: double.tryParse('${original['longitude']}'),
        original: original,
      ),
    );
  }

  const V37SuggestAddressButton({
    super.key,
    this.cityHint,
    this.buildingHint,
    this.isDestination = false,
    this.latitude,
    this.longitude,
  });
  final String? cityHint, buildingHint;
  final bool isDestination;
  final double? latitude, longitude;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: CustomerCityScopeV38.isHadayek
        ? null
        : () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => _SuggestionForm(
              city: cityHint ?? CustomerCityScopeV38.name ?? '',
              building: buildingHint ?? '',
              lat: latitude,
              lng: longitude,
            ),
          ),
    icon: const Icon(Icons.add_location_alt_outlined, size: 18),
    label: Text(context.strings.suggestAddress),
  );
}

class _SuggestionForm extends StatefulWidget {
  const _SuggestionForm({
    required this.city,
    required this.building,
    this.lat,
    this.lng,
    this.original,
  });
  final String city, building;
  final double? lat, lng;
  final Map<String, dynamic>? original;
  @override
  State<_SuggestionForm> createState() => _SuggestionFormState();
}

class _SuggestionFormState extends State<_SuggestionForm> {
  final _form = GlobalKey<FormState>();
  String _requestKey = AddressSuggestionService.requestKey();
  Map<String, dynamic>? _submitted;
  bool _uncertain = false, _confirmed = false;
  late final TextEditingController _city = TextEditingController(
    text: widget.city,
  );
  late final TextEditingController _number = TextEditingController(
    text: widget.building,
  );
  late final _area = TextEditingController(
        text: widget.original?['area_label']?.toString(),
      ),
      _letter = TextEditingController(
        text: widget.original?['building_letter']?.toString(),
      ),
      _name = TextEditingController(
        text:
            widget.original?['suggested_name']?.toString() ??
            widget.original?['place_label']?.toString(),
      ),
      _address = TextEditingController(
        text: widget.original?['written_address']?.toString(),
      ),
      _note = TextEditingController(
        text: widget.original?['customer_note']?.toString(),
      );
  late double? _lat = widget.lat, _lng = widget.lng;
  late String _kind =
      const [
        'area',
        'building',
        'landmark',
      ].contains(widget.original?['address_kind'])
      ? widget.original!['address_kind'].toString()
      : widget.original == null || widget.building.isNotEmpty
      ? 'building'
      : 'landmark';
  bool _sending = false, _locating = false;
  bool _draftLoading = true, _draftLoadFailed = false;
  String? _account;
  StreamSubscription<AuthState>? _auth;
  String? _error;
  String? get _correction => widget.original?['id']?.toString();
  @override
  void initState() {
    super.initState();
    _account = SupabaseService.instance.currentUser?.id;
    _auth = SupabaseService.instance.authStateChanges.listen((event) {
      if (mounted && event.session?.user.id != _account) {
        Navigator.of(context).maybePop();
      }
    });
    _restore();
  }
  Future<void> _restore() async {
    try {
      if (_account == null) throw StateError('address_requires_session');
      final pending = await PendingAddressDraft.load(_account!, correction: _correction);
      if (!mounted) return;
      if (pending != null) {
        _submitted = pending;
        _requestKey = pending['p_request_key'] as String;
        _uncertain = true;
        _city.text = pending['p_city'] as String;
        _kind = pending['p_kind'] as String;
        for (final entry in {
          'p_area': _area, 'p_letter': _letter, 'p_number': _number,
          'p_name': _name, 'p_address': _address, 'p_note': _note,
        }.entries) { entry.value.text = pending[entry.key]?.toString() ?? ''; }
        _lat = (pending['p_lat'] as num).toDouble();
        _lng = (pending['p_lng'] as num).toDouble();
      }
      setState(() { _draftLoading = false; _draftLoadFailed = false; });
    } catch (_) {
      if (mounted) setState(() {
        _draftLoading = false; _draftLoadFailed = true;
        _error = context.strings.pendingDraftUnavailable;
      });
    }
  }
  @override
  void dispose() {
    _auth?.cancel();
    for (final c in [_city, _area, _number, _letter, _name, _address, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final fix = await CustomerLocationState.locate();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (fix != null) {
        _lat = fix.latitude;
        _lng = fix.longitude;
        _error = null;
      } else {
        _error = switch (CustomerLocationState.state.value.phase) {
          CustomerLocationPhase.denied => context.strings.gpsPermission,
          CustomerLocationPhase.gpsOff => context.strings.gpsDisabled,
          _ => context.strings.gpsFailed,
        };
      }
    });
  }

  Future<void> _send() async {
    if (_draftLoading || _draftLoadFailed || _sending) return;
    if (!_form.currentState!.validate()) return;
    if (_lat == null || _lng == null) {
      setState(() => _error = context.strings.suggestionInvalid);
      return;
    }
    if (CustomerCityScopeV38.isHadayekName(_city.text)) {
      setState(() => _error = context.strings.suggestionCityMismatch);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      if (_account == null || SupabaseService.instance.currentUser?.id != _account) {
        throw StateError('address_session_changed');
      }
      _submitted ??= {
        'p_city': _city.text.trim(),
        'p_area': _area.text.trim(),
        'p_kind': _kind,
        'p_letter': _letter.text.trim(),
        'p_number': _number.text.trim(),
        'p_name': _name.text.trim(),
        'p_lat': _lat,
        'p_lng': _lng,
        'p_request_key': _requestKey,
        'p_address': _address.text.trim(),
        'p_note': _note.text.trim(),
        if (widget.original != null &&
            _city.text.trim() == widget.original!['city_label'])
          'p_city_id': widget.original!['selected_city_id'],
      };
      // Save the immutable retry receipt before any server mutation. Closing
      // the app cannot turn an uncertain response into a fresh request key.
      if (!_confirmed) {
        await PendingAddressDraft.save(_account!, _submitted!, correction: _correction);
        if (!mounted || SupabaseService.instance.currentUser?.id != _account) return;
        if (widget.original == null) {
          await AddressSuggestionService().submit(_submitted!);
        } else {
          await AddressSuggestionService().correct({
            ..._submitted!,
            'p_id': widget.original!['id'],
          });
        }
        _confirmed = true;
      }
      await PendingAddressDraft.clear(_account!, correction: _correction);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final message = context.strings.suggestionSent;
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      // A definite server rejection permits editing. An ambiguous transport
      // failure must replay the original payload and key, never a new mutation.
      if (e is PostgrestException) {
        try {
          await PendingAddressDraft.clear(_account!, correction: _correction);
          _submitted = null;
          _requestKey = AddressSuggestionService.requestKey();
          _uncertain = false;
        } catch (_) { _uncertain = true; }
      } else {
        _uncertain = true;
      }
      if (mounted)
        setState(
          () => _error = _confirmed
              ? context.strings.suggestionConfirmedStorage
              : e is PostgrestException
              ? switch (e.message) {
                  'suggestion_rate_limit' =>
                    context.strings.suggestionRateLimit,
                  'selected_city_mismatch' || 'select_unambiguous_city' =>
                    context.strings.suggestionCityMismatch,
                  'invalid_address_suggestion' ||
                  'building_number_must_be_numeric' ||
                  'place_name_required' ||
                  'invalid_building_letter' =>
                    context.strings.suggestionInvalid,
                  _ => context.strings.suggestionFailed,
                }
              : context.strings.suggestionFailed,
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.strings;
    Widget field(
      TextEditingController c,
      String label,
      int length, {
      bool required = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: c,
        maxLength: length,
        enabled: !_sending && !_uncertain && !_draftLoading && !_draftLoadFailed,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) => (v ?? '').trim().isEmpty ? l.suggestionInvalid : null
            : null,
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.suggestionTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(l.suggestionInfo),
              if (widget.original?['review_reason'] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('${widget.original!['review_reason']}'),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: InputDecoration(labelText: l.address),
                items: [
                  DropdownMenuItem(
                    value: 'building',
                    child: Text(l.buildingNumber),
                  ),
                  DropdownMenuItem(value: 'area', child: Text(l.area)),
                  DropdownMenuItem(value: 'landmark', child: Text(l.address)),
                ],
                onChanged: _sending || _uncertain || _draftLoading || _draftLoadFailed
                    ? null
                    : (v) => setState(() => _kind = v!),
              ),
              field(_city, l.city, 80, required: true),
              field(_area, l.area, 100, required: true),
              if (_kind == 'building') ...[
                field(_letter, l.buildingLetter, 5),
                field(_number, l.buildingNumber, 25, required: true),
              ],
              if (_kind == 'landmark')
                field(_name, l.address, 150, required: true),
              field(_address, l.address, 300),
              field(_note, l.note, 500),
              OutlinedButton.icon(
                onPressed: _locating || _sending || _uncertain || _draftLoading || _draftLoadFailed ? null : _locate,
                icon: const Icon(Icons.my_location),
                label: Text(l.useLocation),
              ),
              if (_lat != null && _lng != null) Text(l.locationUnconfirmed),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_uncertain && !_confirmed) Text(l.suggestionReplay),
              if (_draftLoading) const LinearProgressIndicator(),
              if (_draftLoadFailed) TextButton(onPressed: _restore, child: Text(l.retry)),
              FilledButton(
                onPressed: _sending || _locating || _draftLoading || _draftLoadFailed ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_confirmed ? l.close : l.sendReview),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
