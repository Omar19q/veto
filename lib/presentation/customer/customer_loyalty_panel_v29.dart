import '../../widgets/ride_preference_label.dart';
import 'customer_name_editor.dart';
import 'dart:async';
import '../../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/customer_profile_backend.dart';
import '../../widgets/customer_identity_v29.dart';

/// V31: customer's personal account and V29 loyalty frames in one place.
/// Financial/ride logic is not used here; all tier counts and frame entitlements
/// are read from the pre-existing authenticated V29 server functions.
enum CustomerProfileError {
  load,
  frame,
  photo,
  name,
  gender,
  limit,
  preferences,
}

class CustomerLoyaltyPanelV29 extends StatefulWidget {
  final VoidCallback? onPhotoEdit;
  final CustomerProfileBackend? backend;
  const CustomerLoyaltyPanelV29({super.key, this.onPhotoEdit, this.backend});

  @override
  State<CustomerLoyaltyPanelV29> createState() =>
      _CustomerLoyaltyPanelV29State();
}

class _CustomerLoyaltyPanelV29State extends State<CustomerLoyaltyPanelV29> {
  late final CustomerProfileBackend _backend =
      widget.backend ?? CustomerProfileBackend();
  static const gold = Color(0xFFFFCA46);
  Color get goldInk => Theme.of(context).brightness == Brightness.dark
      ? gold
      : Theme.of(context).colorScheme.primary;
  Color get navy => Theme.of(context).brightness == Brightness.dark
      ? Color(0xFF0B111E)
      : Theme.of(context).scaffoldBackgroundColor;
  Color get surface => Theme.of(context).brightness == Brightness.dark
      ? Color(0xFF172238)
      : Theme.of(context).colorScheme.surfaceContainer;
  Color get muted => Theme.of(context).brightness == Brightness.dark
      ? Color(0xFFA5B3C7)
      : Theme.of(context).colorScheme.onSurfaceVariant;
  static const interestsCatalog = <String>[
    'أفضل الهدوء',
    'بدون موسيقى',
    'أفضل التكييف الهادئ',
    'أفضل عدم المكالمات',
    'أفضل الطريق الأسرع',
    'مساعدة في حمل الأمتعة',
  ];

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _customer;
  List<String> _interests = [];
  bool _preferencesAvailable = false;
  bool _loading = true;
  bool _saving = false;
  CustomerProfileError? _error;
  String? _accountId;
  int _readRevision = 0;
  StreamSubscription? _authSubscription;
  BuildContext? _nameDialogContext;
  bool _ownsAccount(String? id) =>
      mounted && id != null && _accountId == id && _backend.accountId == id;

  String _errorLabel(CustomerProfileError error) => switch (error) {
    CustomerProfileError.load => context.strings.profileErrorLoad,
    CustomerProfileError.frame => context.strings.profileErrorFrame,
    CustomerProfileError.photo => context.strings.profileErrorPhoto,
    CustomerProfileError.name => context.strings.profileErrorName,
    CustomerProfileError.gender => context.strings.profileErrorGender,
    CustomerProfileError.limit => context.strings.profileErrorLimit,
    CustomerProfileError.preferences => context.strings.profileErrorPreferences,
  };

  @override
  void initState() {
    super.initState();
    _accountId = _backend.accountId;
    _authSubscription = _backend.accountChanges.listen((_) {
      final next = _backend.accountId;
      if (!mounted || next == _accountId) return;
      final dialog = _nameDialogContext;
      if (dialog != null && dialog.mounted) {
        FocusScope.of(dialog).unfocus();
        Navigator.of(dialog).pop();
      }
      _nameDialogContext = null;
      _readRevision++;
      setState(() {
        _accountId = next;
        _profile = null;
        _customer = null;
        _interests = [];
        _preferencesAvailable = false;
        _loading = true;
        _saving = false;
        _error = null;
      });
      unawaited(_refresh());
    });
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _readRevision++;
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final revision = ++_readRevision;
    final accountId = _backend.accountId;
    bool ownsRead() =>
        mounted &&
        revision == _readRevision &&
        _accountId == accountId &&
        _backend.accountId == accountId;
    try {
      final userId = _backend.accountId;
      if (userId == null) throw StateError('authentication_required');
      final response = await _backend.profile();
      final customer = await _backend.customer(userId);
      if (!ownsRead()) return;
      setState(() {
        _profile = response is Map ? Map<String, dynamic>.from(response) : null;
        _customer = customer == null
            ? null
            : Map<String, dynamic>.from(customer);
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (ownsRead())
        setState(() {
          _loading = false;
          _error = CustomerProfileError.load;
        });
    }
    if (!ownsRead() || accountId == null) return;
    try {
      final data = await _backend.preferences();
      if (!ownsRead()) return;
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      setState(() {
        _preferencesAvailable = true;
        _interests = (map['interests'] as List? ?? [])
            .whereType<String>()
            .where(interestsCatalog.contains)
            .toList();
      });
    } catch (_) {
      // V31 preferences are additive, never block the working V29 profile.
      if (ownsRead()) setState(() => _preferencesAvailable = false);
    }
  }

  Future<void> _chooseFrame(String key) async {
    final accountId = _backend.accountId;
    if (!_ownsAccount(accountId)) return;
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _backend.chooseFrame(key);
      if (_ownsAccount(accountId)) await _refresh();
    } catch (_) {
      if (_ownsAccount(accountId))
        setState(() => _error = CustomerProfileError.frame);
    } finally {
      if (_ownsAccount(accountId)) setState(() => _saving = false);
    }
  }

  Future<void> _changePhoto() async {
    final accountId = _backend.accountId;
    if (!_ownsAccount(accountId)) return;
    if (_saving) return;
    if (widget.onPhotoEdit != null) {
      widget.onPhotoEdit!();
      return;
    }
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 900,
    );
    if (image == null || !_ownsAccount(accountId)) return;
    final customer = _customer;
    final userId = _backend.accountId;
    if (customer == null || userId == null) return;
    setState(() => _saving = true);
    try {
      final url = await _backend.uploadPhoto(userId, await image.readAsBytes());
      if (!_ownsAccount(accountId)) return;
      await _backend.photo(customer['id'].toString(), url);
      if (_ownsAccount(accountId)) await _refresh();
    } catch (_) {
      if (_ownsAccount(accountId))
        setState(() => _error = CustomerProfileError.photo);
    } finally {
      if (_ownsAccount(accountId)) setState(() => _saving = false);
    }
  }

  Future<void> _changeName() async {
    final accountId = _backend.accountId;
    if (!_ownsAccount(accountId)) return;
    if (_saving || _customer == null) return;
    final customerId = _customer!['id'].toString();
    final initialName = _customer?['full_name']?.toString() ?? '';
    try {
      final newName = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          _nameDialogContext = dialogContext;
          return CustomerNameEditor(initialName: initialName);
        },
      );
      if (newName == null || !_ownsAccount(accountId)) return;
      setState(() => _saving = true);
      try {
        await _backend.name(customerId, newName);
        if (_ownsAccount(accountId)) await _refresh();
      } catch (_) {
        if (_ownsAccount(accountId))
          setState(() => _error = CustomerProfileError.name);
      } finally {
        if (_ownsAccount(accountId)) setState(() => _saving = false);
      }
    } finally {
      _nameDialogContext = null;
    }
  }

  Future<void> _changeGender(String? gender) async {
    final accountId = _backend.accountId;
    if (!_ownsAccount(accountId)) return;
    if (_saving || _customer == null || gender == null) return;
    setState(() => _saving = true);
    try {
      await _backend.gender(_customer!['id'].toString(), gender);
      if (_ownsAccount(accountId)) await _refresh();
    } catch (_) {
      if (_ownsAccount(accountId))
        setState(() => _error = CustomerProfileError.gender);
    } finally {
      if (_ownsAccount(accountId)) setState(() => _saving = false);
    }
  }

  Future<void> _toggleInterest(String interest) async {
    final accountId = _backend.accountId;
    if (!_ownsAccount(accountId)) return;
    if (_saving || !_preferencesAvailable) return;
    final changed = List<String>.from(_interests);
    if (changed.contains(interest)) {
      changed.remove(interest);
    } else {
      if (changed.length >= 4) {
        setState(() => _error = CustomerProfileError.limit);
        return;
      }
      changed.add(interest);
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _backend.savePreferences(changed);
      if (_ownsAccount(accountId)) setState(() => _interests = changed);
    } catch (_) {
      if (_ownsAccount(accountId))
        setState(() => _error = CustomerProfileError.preferences);
    } finally {
      if (_ownsAccount(accountId)) setState(() => _saving = false);
    }
  }

  Widget _metric(IconData icon, String title, String value) => Expanded(
    child: Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: goldInk, size: 23),
          SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle( fontSize: 11, color: muted),
          ),
        ],
      ),
    ),
  );

  Widget _heading(String value) => Padding(
    padding: EdgeInsets.only(top: 23, bottom: 10),
    child: Text(
      value,
      style: TextStyle(
        
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final frames = (p?['frames'] as List?) ?? [];
    Map<String, dynamic>? selected;
    for (final raw in frames) {
      if (raw is Map && raw['key'] == p?['selected_frame']) {
        selected = Map<String, dynamic>.from(raw);
        break;
      }
    }
    final rating = (p?['rating'] as num?)?.toDouble();
    final ratingCount = (p?['rating_count'] as num?)?.toInt() ?? 0;
    final name =
        _customer?['full_name']?.toString() ??
        p?['name']?.toString() ??
        context.strings.profile0b9ef884;
    final image =
        _customer?['profile_photo_url']?.toString() ?? p?['photo']?.toString();
    final gender = _customer?['gender']?.toString() ?? '';
    final currentTrips = (p?['completed_trips'] as num?)?.toInt() ?? 0;

    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: navy,
        appBar: AppBar(
          backgroundColor: navy,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          title: Text(
            context.strings.profiled256b773,
            style: TextStyle( fontWeight: FontWeight.w900),
          ),
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: gold))
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(17, 8, 17, 34),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).brightness == Brightness.dark
                                ? Color(0xFF263852)
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            surface,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(27),
                        border: Border.all(color: Color(0xFF4A5160)),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 24,
                      ),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CustomerFrameAvatarV29(
                                size: 120,
                                photo: image,
                                accentHex: selected?['accent_hex']?.toString(),
                                glyph: selected?['glyph']?.toString(),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Material(
                                  color: gold,
                                  shape: CircleBorder(),
                                  child: IconButton(
                                    onPressed: _saving ? null : _changePhoto,
                                    tooltip: context.strings.profileba69e2b8,
                                    icon: Icon(
                                      Icons.camera_alt_rounded,
                                      color: Color(0xFF0B111E),
                                      size: 21,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 11),
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            p?['tier']?.toString() ??
                                context.strings.profile05f99bc8,
                            style: TextStyle(
                              
                              color: goldInk,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _saving ? null : _changeName,
                            icon: Icon(Icons.edit_rounded, size: 18),
                            label: Text(
                              context.strings.profile9cb77234,
                              style: TextStyle(),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 13),
                    Row(
                      children: [
                        _metric(
                          Icons.route_rounded,
                          context.strings.profile995846e9,
                          '$currentTrips',
                        ),
                        SizedBox(width: 10),
                        _metric(
                          Icons.star_rounded,
                          context.strings.profile957084b6,
                          ratingCount == 0 || rating == null
                              ? context.strings.profiled51f9d8d
                              : rating.toStringAsFixed(1),
                        ),
                      ],
                    ),
                    _heading(context.strings.profilea7b2860b),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wc_rounded, color: goldInk),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.strings.profilecaa3f2bb,
                              style: TextStyle(
                                
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: ['male', 'female'].contains(gender)
                                  ? gender
                                  : null,
                              hint: Text(
                                context.strings.profilefdcd3da0,
                                style: TextStyle(
                                  color: muted,
                                  
                                ),
                              ),
                              dropdownColor: surface,
                              onChanged: _saving ? null : _changeGender,
                              items: [
                                DropdownMenuItem(
                                  value: 'male',
                                  child: Text(
                                    context.strings.profile2f13379b,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'female',
                                  child: Text(
                                    context.strings.profiled2ee47ec,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _heading(context.strings.profile163e063e),
                    Text(
                      context.strings.profilead0b4e2d,
                      style: TextStyle(
                        
                        fontSize: 11,
                        color: muted,
                      ),
                    ),
                    SizedBox(height: 9),
                    if (!_preferencesAvailable)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 7),
                        child: Text(
                          context.strings.profile57141c0a,
                          style: TextStyle(
                            
                            color: Colors.orangeAccent,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final interest in interestsCatalog)
                          FilterChip(
                            label: Text(
                              ridePreferenceLabel(context, interest),
                              style: TextStyle(),
                            ),
                            selected: _interests.contains(interest),
                            onSelected: !_preferencesAvailable || _saving
                                ? null
                                : (_) => _toggleInterest(interest),
                            selectedColor: Color(0xFFFFDE8A),
                            checkmarkColor: Color(0xFF0B111E),
                            backgroundColor: surface,
                            labelStyle: TextStyle(
                              color: _interests.contains(interest)
                                  ? Color(0xFF0B111E)
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            side: BorderSide(
                              color: _interests.contains(interest)
                                  ? gold
                                  : Color(0xFF394860),
                            ),
                          ),
                      ],
                    ),
                    _heading(context.strings.profile17ed4b4f),
                    Text(
                      context.strings.profile4a630f62,
                      style: TextStyle(
                        
                        fontSize: 11,
                        color: muted,
                      ),
                    ),
                    SizedBox(height: 9),
                    ...frames.whereType<Map>().map((raw) {
                      final frame = Map<String, dynamic>.from(raw);
                      final unlocked = frame['unlocked'] == true;
                      final chosen = frame['key'] == p?['selected_frame'];
                      final color = CustomerFrameAvatarV29.parseColor(
                        frame['accent_hex']?.toString(),
                      );
                      return Container(
                        margin: EdgeInsets.only(bottom: 10),
                        padding: EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                            color: chosen ? color : Color(0xFF2E3A51),
                            width: chosen ? 1.6 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            CustomerFrameAvatarV29(
                              size: 66,
                              photo: image,
                              accentHex: frame['accent_hex']?.toString(),
                              glyph: frame['glyph']?.toString(),
                            ),
                            SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    frame['title']?.toString() ??
                                        context.strings.profile60e389c8,
                                    style: TextStyle(
                                      
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    unlocked
                                        ? context.strings.profiled520070b
                                        : context.strings.profileUnlockAfter(
                                            '${frame['min_trips']}',
                                          ),
                                    style: TextStyle(
                                      
                                      fontSize: 11,
                                      color: unlocked ? color : muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (chosen)
                              Icon(Icons.check_circle_rounded, color: color)
                            else if (!unlocked)
                              Icon(Icons.lock_outline_rounded, color: muted)
                            else
                              FilledButton(
                                onPressed: _saving
                                    ? null
                                    : () =>
                                          _chooseFrame(frame['key'].toString()),
                                style: FilledButton.styleFrom(
                                  backgroundColor: gold,
                                  foregroundColor: Color(0xFF0B111E),
                                ),
                                child: Text(
                                  context.strings.profilefdcd3da0,
                                  style: TextStyle(),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    if (_error != null)
                      Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          _errorLabel(_error!),
                          style: TextStyle(
                            
                            color: Colors.orangeAccent,
                          ),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _saving ? null : _refresh,
                      icon: Icon(Icons.refresh_rounded),
                      label: Text(
                        context.strings.profile774eeef9,
                        style: TextStyle(),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
