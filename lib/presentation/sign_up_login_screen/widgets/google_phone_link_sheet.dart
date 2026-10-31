import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import '../../../services/phone_identity.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';

enum _LinkStep { phone, otp }

class GooglePhoneLinkSheet extends StatefulWidget {
  final String userId;
  final String? customerId;
  final String? userName;

  const GooglePhoneLinkSheet({
    super.key,
    required this.userId,
    this.customerId,
    this.userName,
  });

  static Future<bool> show(
    BuildContext context, {
    required String userId,
    String? customerId,
    String? userName,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => GooglePhoneLinkSheet(
        userId: userId,
        customerId: customerId,
        userName: userName,
      ),
    );
    return result ?? false;
  }

  @override
  State<GooglePhoneLinkSheet> createState() => _GooglePhoneLinkSheetState();
}

class _GooglePhoneLinkSheetState extends State<GooglePhoneLinkSheet> {
  _LinkStep _currentStep = _LinkStep.phone;
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Country _country = Country.parse('EG');
  bool _isLoading = false;
  String? _errorMessage;
  String _targetPhone = '';

  Timer? _resendTimer;
  int _resendCountdown = 60;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  String? _validatePhone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'يرجى إدخال رقم الهاتف';
    }
    try {
      PhoneIdentity.parse(
        text,
        IsoCode.values.byName(_country.countryCode),
      );
      return null;
    } catch (_) {
      if (_country.countryCode == 'EG') {
        return 'يرجى إدخال رقم هاتف مصري صحيح (11 رقم يبدأ بـ 01)';
      }
      return 'رقم الهاتف غير صحيح';
    }
  }

  Future<void> _sendOtp() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final identity = PhoneIdentity.parse(
        _phoneController.text.trim(),
        IsoCode.values.byName(_country.countryCode),
      );
      final phone = identity.legacyLookup;
      _targetPhone = phone;

      // Check if this phone is already registered to another account
      final available = await SupabaseService.instance.isPhoneAvailable(
        phone,
        excludeCustomerId: widget.customerId,
      );
      if (!available) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'هذا الرقم مسجل بالفعل بحساب آخر على فيتو ثانية. يرجى تسجيل الدخول برقم الهاتف مباشرة، ثم ربط حساب Google من شاشة الإعدادات.';
        });
        return;
      }

      // Send SMS OTP via MSGCloud via Supabase Edge Function
      await SupabaseService.instance.createVerificationRequest(phone);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = _LinkStep.otp;
          _otpController.clear();
        });
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'تعذر إرسال رمز التحقق. يرجى التأكد من الرقم والمحاولة مرة أخرى.';
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_isLoading || _resendCountdown > 0) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.instance.createVerificationRequest(_targetPhone);
      if (mounted) {
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رمز تحقق جديد في رسالة نصية'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر إعادة إرسال الرمز. يرجى المحاولة بعد قليل.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOtp([String? directCode]) async {
    if (_isLoading) return;
    final code =
        PhoneIdentity.normalizeDigits(directCode ?? _otpController.text).trim();
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      setState(() => _errorMessage = 'يرجى إدخال رمز التحقق المكون من 4 أرقام');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final verified = await SupabaseService.instance.verifyPhoneOtp(
        _targetPhone,
        code,
      );

      if (!verified) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'رمز التحقق غير صحيح أو انتهت صلاحيته';
            _otpController.clear();
          });
        }
        return;
      }

      // OTP verified successfully: link and save phone number
      if (widget.customerId != null && widget.customerId!.isNotEmpty) {
        await SupabaseService.instance.linkAndSavePhoneForUser(
          userId: widget.userId,
          customerId: widget.customerId!,
          phone: _targetPhone,
        );
      } else {
        await SupabaseService.instance.ensureCustomerProfile(
          userId: widget.userId,
          phone: _targetPhone,
          fullName: widget.userName,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        final isConflict = errStr.contains('customers_phone_key') ||
            errStr.contains('23505') ||
            errStr.contains('duplicate key');
        setState(() {
          _isLoading = false;
          _errorMessage = isConflict
              ? 'هذا الرقم مسجل بالفعل بحساب آخر على فيتو ثانية. يرجى استخدام رقم آخر.'
              : 'تعذر إتمام الربط. حاول مرة أخرى.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final displayName = (widget.userName ?? '').trim();
    final greeting = displayName.isNotEmpty
        ? 'أهلاً بك يا $displayName 👋'
        : 'أهلاً بك في فيتو ثانية 👋';

    return PopScope(
      canPop: false,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 80 : 30),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (_currentStep == _LinkStep.phone) ...[
                  // Title
                  Text(
                    greeting,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'رقم الهاتف مطلوب لتفعيل حسابك وحجز الرحلات والتواصل مع الكباتن',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Phone input field
                  TextFormField(
                    controller: _phoneController,
                    autofocus: true,
                    enabled: !_isLoading,
                    validator: _validatePhone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9٠-٩۰-۹+\s()-]'),
                      ),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    onFieldSubmitted: (_) => _sendOtp(),
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف',
                      hintText:
                          _country.countryCode == 'EG' ? '01xxxxxxxxx' : null,
                      prefixIcon: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => showCountryPicker(
                                context: context,
                                showPhoneCode: true,
                                countryFilter: const ['EG', 'GB', 'SA', 'AE'],
                                countryListTheme: CountryListThemeData(
                                  inputDecoration: const InputDecoration(
                                    labelText: 'بحث عن الدولة',
                                  ),
                                ),
                                onSelect: (country) {
                                  setState(() => _country = country);
                                },
                              ),
                        child: Text(
                          '${_country.flagEmoji} +${_country.phoneCode}',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colors.outlineVariant.withAlpha(120),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppTheme.gold,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.error, fontSize: 13),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Send OTP Button
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _sendOtp,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: const Color(0xFF0B0F1A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF0B0F1A),
                              ),
                            )
                          : const Text(
                              'إرسال رمز التحقق',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ] else ...[
                  // Step 2: OTP Verification
                  Text(
                    'تأكيد رقم الهاتف 📱',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'أدخل رمز التحقق المكون من 4 أرقام المرسل إلى هاتفك في رسالة نصية',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phone display and edit button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.outlineVariant.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _targetPhone,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                        InkWell(
                          onTap: _isLoading
                              ? null
                              : () {
                                  _resendTimer?.cancel();
                                  setState(() {
                                    _currentStep = _LinkStep.phone;
                                    _errorMessage = null;
                                  });
                                },
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              'تعديل الرقم',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.gold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // OTP 4-digit input
                  TextFormField(
                    controller: _otpController,
                    autofocus: true,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    maxLength: 4,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9٠-٩۰-۹]'),
                      ),
                    ],
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.gold : const Color(0xFF0B0F1A),
                      letterSpacing: 16,
                    ),
                    onChanged: (val) {
                      if (_errorMessage != null) {
                        setState(() => _errorMessage = null);
                      }
                      final normalized =
                          PhoneIdentity.normalizeDigits(val).trim();
                      if (normalized.length == 4) {
                        _verifyOtp(normalized);
                      }
                    },
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '----',
                      hintStyle: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: colors.onSurfaceVariant.withAlpha(120),
                        letterSpacing: 16,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colors.outlineVariant.withAlpha(120),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppTheme.gold,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.error, fontSize: 13),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Resend countdown / button
                  Center(
                    child: _resendCountdown > 0
                        ? Text(
                            'إعادة إرسال الرمز خلال $_resendCountdown ثانية',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          )
                        : TextButton.icon(
                            onPressed: _isLoading ? null : _resendOtp,
                            icon: const Icon(
                              Icons.refresh_rounded,
                              size: 16,
                              color: AppTheme.gold,
                            ),
                            label: const Text(
                              'إعادة إرسال رمز التحقق',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.gold,
                              ),
                            ),
                          ),
                  ),

                  const SizedBox(height: 20),

                  // Submit button
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _isLoading ? null : () => _verifyOtp(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: const Color(0xFF0B0F1A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF0B0F1A),
                              ),
                            )
                          : const Text(
                              'تأكيد ومتابعة',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // Cancel & Sign out button (mandatory flow)
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(
                    'إلغاء وتسجيل الخروج',
                    style: TextStyle(
                      color: colors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
