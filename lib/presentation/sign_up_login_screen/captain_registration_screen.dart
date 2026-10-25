import 'dart:async';
import '../../services/secure_draft_store.dart';
import '../../l10n/strings.dart';
import 'widgets/captain_application_copy.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/captain_application_v16.dart';
import '../../routes/app_routes.dart';

class CaptainRegistrationScreen extends StatefulWidget {
  const CaptainRegistrationScreen({super.key, this.applicationApi});
  final CaptainApplicationV16? applicationApi;
  @override
  State<CaptainRegistrationScreen> createState() =>
      _CaptainRegistrationScreenState();
}

class _CaptainRegistrationScreenState extends State<CaptainRegistrationScreen> {
  late final CaptainApplicationV16 _api;
  final _fields = {
    for (final k in [
      'phone',
      'code',
      'full_name',
      'national_id',
      'vehicle_brand',
      'vehicle_model',
      'vehicle_year',
      'vehicle_color',
      'vehicle_plate',
      'area',
      'address',
    ])
      k: TextEditingController(),
  };
  final _teamCodeV39 = TextEditingController();
  final _documents = <String, String>{};
  final _previews = <String, Uint8List>{};
  DateTime? _birth;
  String _vehicle = 'car';
  int _step = 0;
  bool _busy = false, _verified = false, _loading = true;
  String? _error;
  String _submitPhase = 'preparing';
  String? _uploadingKind;
  String? _teamName;
  String? _teamError;
  bool _teamChecking = false;
  bool _submitting = false;
  bool _teamSaved = false;
  Timer? _draftTimer;
  SecureDraftStore? _draftStore;
  String? _teamCheckedCode;
  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String _copy(String ar, String en) => _isArabic ? ar : en;
  List<String> get _missingDocs => CaptainApplicationV16.missingDocuments({
    ..._previews.keys,
    ..._documents.keys,
  });
  int get _completedDocCount =>
      CaptainApplicationV16.documentLabels.length - _missingDocs.length;
  String _documentName(String key) =>
      CaptainApplicationV16.documentLabels[key] ?? key;

  void _syncBirthFromId() {
    final derived = CaptainApplicationV16.birthDateFromNationalId(
      _fields['national_id']!.text.trim(),
    );
    if (derived == null || _birth == derived) return;
    if (mounted) setState(() => _birth = derived);
  }

  Map<String, dynamic>? _application;
  RealtimeChannel? _channel;
  final _form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    _api = widget.applicationApi ?? CaptainApplicationV16();
    _fields['national_id']!.addListener(_syncBirthFromId);
    for (final field in _fields.entries) {
      if (field.key != 'code') field.value.addListener(_scheduleDraftSave);
    }
    _teamCodeV39.addListener(() {
      // Never trust a confirmation for a different code after an edit.
      final code = _teamCodeV39.text.trim().toUpperCase();
      if (_teamCheckedCode != code) {
        _teamName = null;
        _teamCheckedCode = null;
        _teamError = null;
      }
      if (mounted) setState(() {});
    });
    final owner = _api.client.auth.currentUser?.id;
    if (owner != null) _draftStore = SecureDraftStore(owner);
    _restore();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    unawaited(_saveDraft());
    _teamCodeV39.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    if (_channel != null) {
      _api.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final identity = await _api.identity();
      final a = identity == null ? await _api.intakeMine() : await _api.mine();
      if (a == null) await _restoreLocalDraft();
      if (!mounted) return;
      setState(() {
        _verified = identity != null;
        if (identity != null) {
          _fields['phone']!.text = identity['phone'] as String;
        }
        _application = a;
        if (a != null) {
          for (final k in _fields.keys) {
            if (a[k] != null) _fields[k]!.text = a[k].toString();
          }
          _vehicle = a['vehicle_type'] as String;
          _birth =
              DateTime.tryParse(a['birth_date']?.toString() ?? '') ??
              CaptainApplicationV16.birthDateFromNationalId(
                _fields['national_id']!.text.trim(),
              );
          if (a['documents'] is Map) {
            _documents.addAll(Map<String, String>.from(a['documents'] as Map));
          }
        }
        _loading = false;
      });
      if (identity != null && _channel == null) {
        _channel = _api.client
            .channel('v16-application-${identity['user_id']}')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'v16_captain_applications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: identity['user_id'],
              ),
              callback: (_) {
                _restore();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.strings.registrationb214d2cc),
                    ),
                  );
                }
              },
            )
            .subscribe((s, e) {
              if (s == RealtimeSubscribeStatus.subscribed) _refreshStatus();
            });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = context.strings.registration9496b651;
        });
      }
    }
  }

  void _scheduleDraftSave() {
    if (_loading || _application != null) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(
      const Duration(milliseconds: 600),
      () => unawaited(_saveDraft()),
    );
  }

  Future<void> _saveDraft() async {
    if (_draftStore == null || _application != null || _loading) return;
    final data = <String, dynamic>{
      'fields': {
        for (final f in _fields.entries)
          if (f.key != 'code') f.key: f.value.text,
      },
      'vehicle': _vehicle,
      'step': _step,
      'documents': Map<String, String>.from(_documents),
      'team': _teamCodeV39.text,
    };
    try {
      await _draftStore!.save('captain_application', data);
    } catch (_) {
      /* Submission stays available if optional local storage fails. */
    }
  }

  Future<void> _restoreLocalDraft() async {
    try {
      final owner = _api.client.auth.currentUser?.id;
      final data = await _draftStore?.load('captain_application');
      if (!mounted || data == null || owner != _api.client.auth.currentUser?.id)
        return;
      final fields = data['fields'];
      if (fields is Map) {
        for (final entry in _fields.entries) {
          if (entry.key != 'code' && fields[entry.key] is String)
            entry.value.text = fields[entry.key] as String;
        }
      }
      if (const ['car', 'motorcycle'].contains(data['vehicle']))
        _vehicle = data['vehicle'] as String;
      if (data['step'] is int) _step = (data['step'] as int).clamp(0, 3);
      if (data['documents'] is Map)
        _documents.addAll(Map<String, String>.from(data['documents'] as Map));
      _teamCodeV39.text = data['team'] is String ? data['team'] as String : '';
      _syncBirthFromId();
    } catch (_) {
      /* A draft cannot authorize submission or replace server state. */
    }
  }

  Future<void> _refreshStatus() async {
    try {
      final a = await _api.mine();
      if (mounted) setState(() => _application = a);
    } catch (_) {}
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } catch (e) {
      // Never expose raw server messages or document paths to the applicant.
      // Keep enough detail in debug logs to distinguish deployment, document,
      // validation and connection failures instead of swallowing all errors.
      debugPrint('Captain join request failed during $_submitPhase: $e');
      if (mounted) {
        setState(() => _error = _describeApplicationError(e));
      }
    } finally {
      _uploadingKind = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  String _describeApplicationError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('national_id_birth_date_mismatch')) {
      return context.strings.registration3cfb232e;
    }
    if (raw.contains('invalid_birth_date') ||
        raw.contains('invalid_application_data') ||
        raw.contains('invalid_field') ||
        raw.contains('invalid_vehicle_year') ||
        raw.contains('invalid_phone') ||
        raw.contains('invalid_vehicle_type')) {
      return context.strings.registration3f4f4ac8;
    }
    if (raw.contains('customer_session_required') ||
        raw.contains('jwt expired') ||
        raw.contains('invalid jwt')) {
      return context.strings.registration0e85de07;
    }
    if (raw.contains('ineligible_account') ||
        raw.contains('conflict') ||
        raw.contains('phone_mismatch')) {
      return context.strings.registration8574ec84;
    }
    if (raw.contains('invalid_image') ||
        raw.contains('entitytoolarge') ||
        raw.contains('payload too large') ||
        raw.contains('file size')) {
      return context.strings.registrationad110af9;
    }
    if (raw.contains('application_locked')) {
      return context.strings.registration6d21b4e2;
    }
    if (raw.contains('partner_code_already_locked') ||
        raw.contains('partner_code_conflict')) {
      return _copy(
        'كود الفريق اتسجل قبل كده مع فريق تاني، ومينفعش تغيّره بنفسك. كلم الإدارة لو فيه مشكلة.',
        'Your team code is already locked to a different team. Contact support.',
      );
    }
    if (raw.contains('invalid_partner_code')) {
      return _copy(
        'كود الفريق مش صحيح أو الفريق متوقف. اتأكد من مسؤول الفريق.',
        'Invalid or inactive team code.',
      );
    }
    if (raw.contains('pending_application_required')) {
      return _copy(
        'لازم يكون عندك طلب كابتن قيد المراجعة عشان تثبّت الكود.',
        'A pending captain application is required.',
      );
    }
    if (raw.contains('document_required') ||
        raw.contains('storage') ||
        raw.contains('bucket not found') ||
        raw.contains('bucket_id')) {
      return context.strings.registrationb23d2d69;
    }
    if (raw.contains('pgrst202') ||
        raw.contains('42883') ||
        raw.contains('42p01') ||
        raw.contains('relation') ||
        raw.contains('function public.v19_submit_captain_intake') ||
        raw.contains('does not exist') ||
        raw.contains('404')) {
      return context.strings.registrationb4eecfa9;
    }
    if (raw.contains('permission denied') ||
        raw.contains('42501') ||
        raw.contains('row-level security') ||
        raw.contains('not authorized')) {
      return context.strings.registration6d45fa59;
    }
    if (raw.contains('timeout') ||
        raw.contains('socket') ||
        raw.contains('network') ||
        raw.contains('connection')) {
      return context.strings.registration6a52abd7;
    }
    if (_submitPhase == 'photos') {
      return _copy(
        'الصورة دي ما اترفعتش: ${_documentName(_uploadingKind ?? '')}. جرّب تصورها تاني أو اختارها من المعرض.',
        'Could not upload ${_documentName(_uploadingKind ?? '')}. Please retry.',
      );
    }
    return context.strings.registration53b824de;
  }

  bool _nationalIdMatchesBirthDate() {
    final nationalId = _fields['national_id']!.text.trim();
    final birth = _birth;
    if (birth == null || !RegExp(r'^[23]\d{13}$').hasMatch(nationalId)) {
      return false;
    }
    final century = birth.year >= 2000 ? '3' : '2';
    final datePart =
        '${(birth.year % 100).toString().padLeft(2, '0')}'
        '${birth.month.toString().padLeft(2, '0')}'
        '${birth.day.toString().padLeft(2, '0')}';
    return nationalId.startsWith('$century$datePart');
  }

  Future<void> _pick(String kind, ImageSource source) async {
    await _run(() async {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2200,
        maxHeight: 2200,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (CaptainApplicationV16.imageType(bytes) == null) {
        throw StateError('invalid_image');
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(CaptainApplicationV16.documentLabels[kind]!),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 240,
                width: 300,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
              const SizedBox(height: 12),
              Text(context.strings.registration3659b0f0),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(context.strings.registrationb99f84a8),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(context.strings.registration09a46335),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      // New applicants can prepare all 7 photos without a verification screen.
      // Protected Storage upload only happens after server-backed identity verification.
      _uploadingKind = kind;
      final signedIn = _api.client.auth.currentUser != null;
      final path = _verified
          ? await _api.upload(kind, bytes)
          : signedIn
          ? await _api.uploadIntake(kind, bytes)
          : null;
      _uploadingKind = null;
      if (mounted) {
        setState(() {
          if (path != null) {
            _documents[kind] = path;
          } else {
            _documents.remove(kind);
          }
          _previews[kind] = bytes;
        });
        await _saveDraft();
      }
    });
  }

  String? _checkPersonal() {
    final phone = _fields['phone']!.text.trim();
    final name = _fields['full_name']!.text.trim();
    final id = _fields['national_id']!.text.trim();
    final address = _fields['address']!.text.trim();
    if (!RegExp(r'^01[0125][0-9]{8}$').hasMatch(phone)) {
      return _copy(
        'اكتب رقم موبايل مصري صحيح مكوّن من 11 رقم.',
        'Enter a valid 11-digit Egyptian phone number.',
      );
    }
    if (name.length < 5)
      return _copy(
        'اكتب اسمك بالكامل زي البطاقة.',
        'Please enter your full legal name.',
      );
    if (!RegExp(r'^[23][0-9]{13}$').hasMatch(id)) {
      return _copy(
        'الرقم القومي لازم يكون 14 رقم.',
        'The national ID must contain 14 digits.',
      );
    }
    final birth = CaptainApplicationV16.birthDateFromNationalId(id);
    if (birth == null)
      return _copy(
        'الرقم القومي فيه تاريخ ميلاد غير صحيح.',
        'The national ID has an invalid birth date.',
      );
    if (!CaptainApplicationV16.isAdult(birth, DateTime.now())) {
      return _copy(
        'التقديم متاح لسن 18 سنة أو أكثر.',
        'You must be 18 or older to apply.',
      );
    }
    if (!_nationalIdMatchesBirthDate()) {
      return _copy(
        'تاريخ الميلاد مش مطابق للرقم القومي. راجع الاتنين.',
        'The date of birth does not match the national ID.',
      );
    }
    if (_fields['area']!.text.trim().isEmpty || address.length < 5) {
      return _copy(
        'اكتب المنطقة والعنوان بالتفصيل (5 حروف على الأقل).',
        'Please enter your area and full address.',
      );
    }
    return null;
  }

  String? _checkVehicle() {
    final y = int.tryParse(_fields['vehicle_year']!.text.trim());
    if (y == null || y < 1950 || y > DateTime.now().year + 1) {
      return _copy(
        'اكتب سنة موديل العربية أو الموتوسيكل، مثل 2022.',
        'Enter the vehicle model year, e.g. 2022.',
      );
    }
    for (final key in [
      'vehicle_brand',
      'vehicle_model',
      'vehicle_color',
      'vehicle_plate',
    ]) {
      if (_fields[key]!.text.trim().isEmpty) {
        return _copy(
          'لسه ناقص بيانات المركبة. كمّل كل الخانات.',
          'Please complete all vehicle fields.',
        );
      }
    }
    return null;
  }

  void _goToIssue(int step, String message) {
    if (mounted)
      setState(() {
        _step = step;
        _error = message;
      });
  }

  Future<bool> _previewTeamCode() async {
    final code = _teamCodeV39.text.trim().toUpperCase();
    if (code.isEmpty) return true;
    if (_teamChecking) return false;
    if (_teamCheckedCode == code && _teamName != null) return true;
    setState(() {
      _teamChecking = true;
      _teamError = null;
    });
    try {
      final raw = await _api.client
          .rpc('v64_partner_code_preview', params: {'p_code': code})
          .timeout(const Duration(seconds: 12));
      if (raw is! Map || raw['valid'] != true) {
        throw StateError('invalid_partner_code');
      }
      if (!mounted) return false;
      setState(() {
        _teamCheckedCode = code;
        _teamName = (raw['team_name'] ?? '').toString();
      });
      return true;
    } catch (e) {
      debugPrint('Partner code check failed: $e');
      if (mounted)
        setState(() {
          _teamCheckedCode = null;
          _teamName = null;
          _teamError =
              e.toString().toLowerCase().contains('invalid_partner_code')
              ? _copy(
                  'كود الفريق مش صحيح أو الفريق مش متاح. راجعه مع مسؤول الفريق.',
                  'Invalid or inactive team code.',
                )
              : _copy(
                  'ما قدرناش نتأكد من كود الفريق. تأكد إن SQL V64 اتثبت واتصل بالإنترنت.',
                  'Could not validate the team code. Check V64 SQL and your connection.',
                );
        });
      return false;
    } finally {
      if (mounted) setState(() => _teamChecking = false);
    }
  }

  Future<void> _claimTeamCode() async {
    final code = _teamCodeV39.text.trim().toUpperCase();
    if (code.isEmpty || _teamSaved) return;
    final raw = await _api.client
        .rpc('v64_claim_my_partner_code', params: {'p_code': code})
        .timeout(const Duration(seconds: 12));
    if (raw is! Map || raw['saved'] != true) {
      throw StateError('partner_code_not_saved');
    }
    if (mounted)
      setState(() {
        _teamSaved = true;
        _teamError = null;
        _teamName = (raw['team_name'] ?? _teamName ?? '').toString();
      });
  }

  Future<void> _retryTeamCode() async {
    if (_busy || _teamCodeV39.text.trim().isEmpty) return;
    await _run(() async {
      await _claimTeamCode();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _copy(
                'تمام! كود الفريق اتحفظ، والربط هيظهر بعد قبولك ككابتن.',
                'Team code saved. Your membership will show after approval.',
              ),
            ),
          ),
        );
    });
  }

  Future<void> _submit() async {
    if (_busy || _submitting || _teamChecking) return;
    _submitting = true;
    try {
      final personalError = _checkPersonal();
      if (personalError != null) {
        _goToIssue(0, personalError);
        return;
      }
      final vehicleError = _checkVehicle();
      if (vehicleError != null) {
        _goToIssue(1, vehicleError);
        return;
      }
      if (_missingDocs.isNotEmpty) {
        _goToIssue(
          2,
          _copy(
            'لسه ناقص ${_missingDocs.length} صورة: ${_missingDocs.map(_documentName).join('، ')}',
            'Missing documents: ${_missingDocs.map(_documentName).join(', ')}',
          ),
        );
        return;
      }
      if (!await _previewTeamCode()) {
        _goToIssue(
          0,
          _teamError ??
              _copy('راجع كود الفريق.', 'Please check the team code.'),
        );
        return;
      }
      _submitPhase = 'session';
      await _run(() async {
        if (_api.client.auth.currentUser == null) {
          throw StateError('customer_session_required');
        }
        if (_verified) {
          final identity = await _api.identity();
          if (identity?['phone'] != _fields['phone']!.text.trim()) {
            throw StateError('phone_mismatch');
          }
        }
        _submitPhase = 'photos';
        for (final kind in CaptainApplicationV16.documentLabels.keys) {
          if (_documents.containsKey(kind)) continue;
          _uploadingKind = kind;
          final bytes = _previews[kind];
          if (bytes == null) throw StateError('missing_photo');
          _documents[kind] = _verified
              ? await _api.upload(kind, bytes)
              : await _api.uploadIntake(kind, bytes);
        }
        _uploadingKind = null;
        final data = <String, dynamic>{
          for (final k in _fields.keys.where(
            (k) => k != 'code' && k != 'phone',
          ))
            k: _fields[k]!.text.trim(),
          'birth_date':
              '${_birth!.year.toString().padLeft(4, '0')}-${_birth!.month.toString().padLeft(2, '0')}-${_birth!.day.toString().padLeft(2, '0')}',
          'vehicle_type': _vehicle,
          'documents': _documents,
        };
        _submitPhase = 'submission';
        if (_verified) {
          await _api.submit(data);
        } else {
          data['phone'] = _fields['phone']!.text.trim();
          await _api.submitIntake(data);
        }
        _submitPhase = 'referral';
        if (_teamCodeV39.text.trim().isNotEmpty) {
          try {
            await _claimTeamCode();
          } catch (e) {
            debugPrint('Application submitted, but team claim failed: $e');
            if (mounted)
              setState(
                () => _teamError = _copy(
                  'طلبك اتبعت، لكن كود الفريق لسه ما اتحفظش. اضغط «تأكيد الكود» للمحاولة تاني.',
                  'Application sent, but team code needs confirmation. Please retry.',
                ),
              );
          }
        }
        _submitPhase = 'completed';
        await _draftStore?.clear('captain_application');
        await _restore();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _copy(
                  'طلبك وصل! هنراجعه ونبلغك بالنتيجة.',
                  'Your application has been submitted for review.',
                ),
              ),
            ),
          );
        }
      });
    } finally {
      _submitting = false;
    }
  }

  Widget _field(
    String key,
    String label, {
    bool numeric = false,
    int maxLength = 120,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: _fields[key],
      enabled: !_busy && !(key == 'phone' && _verified),
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        final value = v?.trim() ?? '';
        if (value.isEmpty) return context.strings.registrationd5a02f88;
        if (key == 'national_id' && !RegExp(r'^[23]\d{13}$').hasMatch(value)) {
          return context.strings.registrationcd844480;
        }
        if (key == 'phone' && !RegExp(r'^01[0125]\d{8}$').hasMatch(value)) {
          return context.strings.registration3190ac91;
        }
        if (key == 'vehicle_year') {
          final y = int.tryParse(value);
          if (y == null || y < 1950 || y > DateTime.now().year + 1) {
            return context.strings.registration056e90e2;
          }
        }
        if (key == 'full_name' && value.length < 5)
          return context.strings.registration50f73ca9;
        return null;
      },
    ),
  );
  Widget _identity() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SvgPicture.asset('assets/images/veto_sanya_logo_mark.svg', height: 72),
      const SizedBox(height: 10),
      Text(
        context.strings.registrationb44d35b0,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(context.strings.registration71763395, textAlign: TextAlign.center),
      const SizedBox(height: 18),
      _field(
        'phone',
        _copy('رقم موبايلك', 'Egyptian phone number'),
        numeric: true,
        maxLength: 11,
      ),
      _field(
        'full_name',
        _copy('اسمك بالكامل زي البطاقة', 'Full name as shown on ID'),
      ),
      _field(
        'national_id',
        _copy('الرقم القومي (14 رقم)', 'National ID (14 digits)'),
        numeric: true,
        maxLength: 14,
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: _teamCodeV39,
        maxLength: 40,
        enabled: !_busy,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: _copy(
            'كود الفريق (لو حد بعتلك كود)',
            'Team code (optional)',
          ),
          helperText: _copy(
            'ده كود فريق التسويق، مش كود خصم العميل.',
            'This is a marketing-team code, not a customer promo code.',
          ),
          prefixIcon: const Icon(Icons.groups_rounded),
          counterText: '',
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          final code = value?.trim() ?? '';
          if (code.isNotEmpty &&
              !RegExp(r'^[A-Za-z0-9_-]{2,40}$').hasMatch(code)) {
            return _copy(
              'كود الفريق فيه حروف أو أرقام غير صحيحة.',
              'Invalid team-code format.',
            );
          }
          return null;
        },
      ),
      if (_teamName != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_copy('الفريق: $_teamName', 'Team: $_teamName')),
              ),
            ],
          ),
        ),
      if (_teamError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _teamError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      OutlinedButton.icon(
        onPressed: _busy || _teamChecking || _teamCodeV39.text.trim().isEmpty
            ? null
            : _previewTeamCode,
        icon: _teamChecking
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.verified_outlined),
        label: Text(_copy('اتأكد من كود الفريق', 'Check team code')),
      ),
      const SizedBox(height: 14),
      ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
        leading: const Icon(Icons.calendar_month),
        title: Text(
          _birth == null
              ? _copy(
                  'تاريخ الميلاد (هيتحدد من الرقم القومي)',
                  'Date of birth (from national ID)',
                )
              : '${_birth!.day.toString().padLeft(2, '0')}/${_birth!.month.toString().padLeft(2, '0')}/${_birth!.year}',
        ),
        subtitle: Text(
          _copy(
            'هنجيب تاريخ ميلادك تلقائي من البطاقة. دوس هنا لو محتاج تراجعه.',
            'Automatically read from your ID. Tap to review.',
          ),
        ),
        onTap: _busy
            ? null
            : () async {
                final now = DateTime.now();
                final date = await showDatePicker(
                  context: context,
                  initialDate:
                      _birth != null &&
                          CaptainApplicationV16.isAdult(_birth!, now)
                      ? _birth!
                      : DateTime(now.year - 25, now.month, now.day),
                  initialDatePickerMode: DatePickerMode.year,
                  helpText: _copy(
                    'اختار سنة ميلادك وبعدها الشهر واليوم',
                    'Choose your year, month and day',
                  ),
                  fieldLabelText: _copy('تاريخ الميلاد', 'Date of birth'),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(now.year - 18, now.month, now.day),
                );
                if (date != null && mounted) setState(() => _birth = date);
              },
      ),
      const SizedBox(height: 14),
      _field('area', _copy('ساكن فين؟ (المنطقة)', 'Where do you live? (Area)')),
      _field('address', _copy('العنوان بالتفصيل', 'Full address')),
    ],
  );
  Widget _vehicleStep() => Column(
    children: [
      DropdownButtonFormField<String>(
        initialValue: _vehicle,
        decoration: InputDecoration(
          labelText: context.strings.registration9d55adc6,
        ),
        items: [
          DropdownMenuItem(
            value: 'car',
            child: Text(context.strings.registration89aef3a3),
          ),
          DropdownMenuItem(
            value: 'motorcycle',
            child: Text(context.strings.registration80a51d6a),
          ),
        ],
        onChanged: _busy ? null : (v) => setState(() => _vehicle = v!),
      ),
      const SizedBox(height: 16),
      _field(
        'vehicle_brand',
        _copy('ماركة المركبة (مثلاً شيري)', 'Vehicle brand'),
      ),
      _field('vehicle_model', _copy('موديل المركبة', 'Vehicle model')),
      _field(
        'vehicle_year',
        _copy('سنة الموديل (مثلاً 2022)', 'Model year'),
        numeric: true,
        maxLength: 4,
      ),
      _field('vehicle_color', _copy('لون المركبة', 'Vehicle color')),
      _field('vehicle_plate', _copy('رقم اللوحة', 'License plate')),
    ],
  );
  Widget _documentStep() => Column(
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _copy(
                  'صورت $_completedDocCount من 8 صور',
                  '$_completedDocCount of 8 photos ready',
                ),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _completedDocCount / 8),
              if (_missingDocs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _copy(
                      'ناقص: ${_missingDocs.map(_documentName).join('، ')}',
                      'Missing: ${_missingDocs.map(_documentName).join(', ')}',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),

      Text(context.strings.registration427f9e30, textAlign: TextAlign.center),
      for (final e in CaptainApplicationV16.documentLabels.entries)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  CaptainApplicationCopy.document(context, e.key, e.value),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 8),
                if (e.key == 'vehicle_photo')
                  Text(
                    _copy(
                      'صوّر العربية أو الموتوسيكل من برّه بالكامل وفي النور. دي غير صورة الرخصة.',
                      'Take a clear full photo of your vehicle. A license photo does not replace it.',
                    ),
                  ),
                const SizedBox(height: 8),
                if (_previews[e.key] != null)
                  Image.memory(
                    _previews[e.key]!,
                    height: 145,
                    fit: BoxFit.contain,
                  )
                else
                  SvgPicture.asset(
                    e.key == 'portrait'
                        ? 'assets/images/v16_portrait_guide.svg'
                        : 'assets/images/v16_document_guide.svg',
                    height: 120,
                  ),
                if (_documents.containsKey(e.key))
                  Text(
                    context.strings.registratione52577dc,
                    style: TextStyle(color: Colors.green),
                  )
                else if (_previews.containsKey(e.key))
                  Text(
                    context.strings.registration33b4d832,
                    style: TextStyle(color: Colors.green),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _pick(e.key, ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(context.strings.registrationb0014815),
                    ),
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _pick(e.key, ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        _documents.containsKey(e.key)
                            ? context.strings.registrationa3f9bb7c
                            : context.strings.registration3a375696,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ],
  );
  Widget _summary() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Icon(
        Icons.fact_check_outlined,
        size: 60,
        color: Theme.of(context).colorScheme.primary,
      ),
      Text(
        context.strings.registration0b2cbdfb,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      Text(
        '${_fields['full_name']!.text}\n${_fields['phone']!.text}\n${_fields['area']!.text} • ${_fields['address']!.text}\n${_fields['vehicle_brand']!.text} ${_fields['vehicle_model']!.text} • ${_fields['vehicle_year']!.text}\n${_copy('الصور', 'Photos')}: $_completedDocCount / 8',
      ),
      const SizedBox(height: 12),
      if (_teamCodeV39.text.trim().isNotEmpty)
        Text(
          _copy(
            'كود الفريق: ${_teamCodeV39.text.trim().toUpperCase()}${_teamName == null ? '' : ' — $_teamName'}',
            'Team code: ${_teamCodeV39.text.trim().toUpperCase()}',
          ),
        ),
      if (_missingDocs.isNotEmpty)
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _copy(
                    'عشان تبعت الطلب، كمّل الصور دي:',
                    'Please add the missing photos:',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final kind in _missingDocs)
                  Text('• ${_documentName(kind)}'),
                TextButton.icon(
                  onPressed: () => _goToIssue(
                    2,
                    _copy('كمّل الصور الناقصة', 'Add missing photos'),
                  ),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(_copy('ارجع للصور', 'Go to photos')),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 16),
      Text(context.strings.registration3a64c036),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _busy || _submitting ? null : _submit,
        child: Text(_copy('ابعت طلبي للمراجعة', 'Send application for review')),
      ),
    ],
  );
  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(AppRoutes.homeScreen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _application?['status'] as String?;
    final locked = status != null && status != 'needs_info';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Directionality(
        textDirection: Directionality.of(context),
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(context.strings.registrationb44d35b0),
            leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _handleBack,
            ),
            actions: [
            IconButton(
              onPressed: _busy ? null : _restore,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Form(
                    key: _form,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        if (_busy) const LinearProgressIndicator(),
                        if (_application != null)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    (status == 'reviewed'
                                        ? context.strings.registration12e27be4
                                        : CaptainApplicationCopy.status(
                                            context,
                                            status!,
                                          )),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_application!['review_reason'] != null)
                                    Text(
                                      _application!['review_reason'] as String,
                                    ),
                                  if (status == 'pending' && !_teamSaved) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _copy(
                                        'معاك كود فريق ولسه ما اتسجلش؟',
                                        'Have a team code to add?',
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _teamCodeV39,
                                      maxLength: 40,
                                      enabled: !_busy,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      decoration: InputDecoration(
                                        labelText: _copy(
                                          'كود الفريق (اختياري)',
                                          'Team code (optional)',
                                        ),
                                        border: const OutlineInputBorder(),
                                        counterText: '',
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed:
                                          _busy ||
                                              _teamCodeV39.text.trim().isEmpty
                                          ? null
                                          : _retryTeamCode,
                                      icon: const Icon(Icons.verified_outlined),
                                      label: Text(
                                        _copy(
                                          'تأكيد كود الفريق',
                                          'Confirm team code',
                                        ),
                                      ),
                                    ),
                                  ],

                                  if (_teamSaved && _teamName != null)
                                    Text(
                                      _copy(
                                        'كود الفريق اتحفظ: $_teamName. هتنضم للفريق بعد الموافقة على طلبك.',
                                        'Team code saved: $_teamName. You will join when approved.',
                                      ),
                                    ),
                                  if (!_teamSaved && _teamError != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _teamError!,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: _busy ? null : _retryTeamCode,
                                      icon: const Icon(Icons.refresh),
                                      label: Text(
                                        _copy(
                                          'تأكيد كود الفريق',
                                          'Retry team code',
                                        ),
                                      ),
                                    ),
                                  ],

                                  Text(
                                    status == 'approved'
                                        ? context.strings.registrationc7dac90b
                                        : status == 'pending'
                                        ? context.strings.registration6a4555f7
                                        : status == 'reviewed'
                                        ? context.strings.registration541ca893
                                        : context.strings.registration2a0486aa,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (!locked) ...[
                          LinearProgressIndicator(
                            value: (_step + 1) / 4,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.strings.applicationStep(
                              _step + 1,
                              [
                                context.strings.applicationPersonalStep,
                                context.strings.applicationVehicleStep,
                                context.strings.applicationDocumentsStep,
                                context.strings.applicationReviewStep,
                              ][_step],
                            ),
                          ),
                          const SizedBox(height: 22),
                          [
                            _identity,
                            _vehicleStep,
                            _documentStep,
                            _summary,
                          ][_step](),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              if (_step > 0)
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() => _step--),
                                  child: Text(
                                    context.strings.registrationa9e9d067,
                                  ),
                                ),
                              const Spacer(),
                              if (_step < 3)
                                FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () {
                                          if (!_form.currentState!.validate()) {
                                            return;
                                          }
                                          if (_step == 0) {
                                            final error = _checkPersonal();
                                            if (error != null) {
                                              setState(() => _error = error);
                                              return;
                                            }
                                          }
                                          if (_step == 1) {
                                            final error = _checkVehicle();
                                            if (error != null) {
                                              setState(() => _error = error);
                                              return;
                                            }
                                          }
                                          if (_step == 2 &&
                                              _missingDocs.isNotEmpty) {
                                            setState(
                                              () => _error = _copy(
                                                'لسه ناقص: ${_missingDocs.map(_documentName).join('، ')}',
                                                'Missing: ${_missingDocs.map(_documentName).join(', ')}',
                                              ),
                                            );
                                            return;
                                          }
                                          setState(() {
                                            _error = null;
                                            _step++;
                                            _scheduleDraftSave();
                                          });
                                        },
                                  child: Text(
                                    context.strings.registration322b7b61,
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }
}
