import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import '../../../services/phone_identity.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';

enum _PhoneChangeStep { inputPhone, verifyOtp }

class ChangePhoneSheet extends StatefulWidget {
  final String userId;
  final String customerId;
  final String currentPhone;

  const ChangePhoneSheet({
    super.key,
    required this.userId,
    required this.customerId,
    required this.currentPhone,
  });

  static Future<String?> show(
    BuildContext context, {
    required String userId,
    required String customerId,
    required String currentPhone,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => ChangePhoneSheet(
        userId: userId,
        customerId: customerId,
        currentPhone: currentPhone,
      ),
    );
  }

  @override
  State<ChangePhoneSheet> createState() => _ChangePhoneSheetState();
}

class _ChangePhoneSheetState extends State<ChangePhoneSheet> {
  _PhoneChangeStep _step = _PhoneChangeStep.inputPhone;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  Country _country = Country.parse('EG');
  bool _isLoading = false;
  String? _errorMessage;
  String _targetPhone = '';

  Timer? _countdownTimer;
  int _secondsRemaining = 60;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    setState(() => _secondsRemaining = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  String? _validatePhone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'يرجى إدخال رقم الهاتف الجديد';
    }
    try {
      final identity = PhoneIdentity.parse(
        text,
        IsoCode.values.byName(_country.countryCode),
      );
      if (identity.legacyLookup == widget.currentPhone.trim()) {
        return 'هذا هو رقم هاتفك الحالي بالفعل';
      }
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
    if (!_phoneFormKey.currentState!.validate()) return;

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

      // Check if user entered their own current phone
      if (widget.currentPhone.trim().isNotEmpty) {
        bool isCurrent = false;
        try {
          final currentParsed = PhoneIdentity.parse(
            widget.currentPhone.trim(),
            IsoCode.values.byName(_country.countryCode),
          );
          if (currentParsed.legacyLookup == phone) {
            isCurrent = true;
          }
        } catch (_) {
          if (phone == widget.currentPhone.trim()) {
            isCurrent = true;
          }
        }
        if (isCurrent) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'هذا هو رقم هاتفك الحالي بالفعل.';
          });
          return;
        }
      }

      // Check if another customer is already using this phone
      final available = await SupabaseService.instance.isPhoneAvailable(
        phone,
        excludeCustomerId: widget.customerId,
      );
      if (!available) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'هذا الرقم مسجل بالفعل بحساب آخر على فيتو ثانية. إذا كان هذا حسابك، يرجى تسجيل الدخول به مباشرة.';
        });
        return;
      }

      await SupabaseService.instance.createVerificationRequest(phone);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _targetPhone = phone;
          _step = _PhoneChangeStep.verifyOtp;
          _otpController.clear();
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر إرسال رمز التحقق. يرجى التأكد من الرقم والمحاولة مرة أخرى.';
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_isLoading || _secondsRemaining > 0) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.instance.createVerificationRequest(_targetPhone);
      if (mounted) {
        setState(() => _isLoading = false);
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إعادة إرسال رمز التحقق')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر إعادة إرسال الرمز حالياً.';
        });
      }
    }
  }

  Future<void> _verifyAndChangePhone() async {
    if (_isLoading) return;
    if (!_otpFormKey.currentState!.validate()) return;

    final code = _otpController.text.trim();
    if (code.length != 4) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await SupabaseService.instance.verifyPhoneOtpWithResult(
        _targetPhone,
        code,
      );

      if (result['success'] != true || result['verified'] != true) {
        final err = result['error']?.toString();
        final message = switch (err) {
          'verification_expired' => 'انتهت صلاحية رمز التحقق. اطلب رمزاً جديداً.',
          'verification_attempts_exceeded' => 'تم تجاوز الحد الأقصى للمحاولات.',
          'verification_pending' => 'الرمز قيد الإرسال، انتظر لحظات.',
          _ => 'رمز التحقق غير صحيح. يرجى التأكد والمحاولة ثانية.',
        };
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = message;
          });
        }
        return;
      }

      // Code is valid and consumed! Update customer phone in database
      await SupabaseService.instance.linkAndSavePhoneForUser(
        userId: widget.userId,
        customerId: widget.customerId,
        phone: _targetPhone,
      );

      if (mounted) {
        Navigator.of(context).pop(_targetPhone);
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
              : 'تعذر تحديث رقم الهاتف. يرجى المحاولة مرة أخرى.';
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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182A) : Colors.white,
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

            if (_step == _PhoneChangeStep.inputPhone)
              _buildInputPhoneStep(theme, isDark, colors)
            else
              _buildVerifyOtpStep(theme, isDark, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildInputPhoneStep(ThemeData theme, bool isDark, ColorScheme colors) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.gold.withAlpha(isDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.phone_iphone_rounded,
                  color: AppTheme.gold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تغيير رقم الهاتف',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.currentPhone.isNotEmpty
                          ? 'الرقم الحالي: ${widget.currentPhone}'
                          : 'أدخل رقم هاتفك الجديد',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text(
            'سيتم إرسال رمز تحقق (OTP) إلى الرقم الجديد لتأكيد ملكيته.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          TextFormField(
            controller: _phoneController,
            autofocus: true,
            enabled: !_isLoading,
            validator: _validatePhone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹+\s()-]')),
              LengthLimitingTextInputFormatter(20),
            ],
            onFieldSubmitted: (_) => _sendOtp(),
            decoration: InputDecoration(
              labelText: 'رقم الهاتف الجديد',
              hintText: _country.countryCode == 'EG' ? '01xxxxxxxxx' : null,
              prefixIcon: TextButton(
                onPressed: _isLoading
                    ? null
                    : () => showCountryPicker(
                          context: context,
                          showPhoneCode: true,
                          countryFilter: const ['EG', 'GB', 'SA', 'AE'],
                          countryListTheme: const CountryListThemeData(
                            inputDecoration: InputDecoration(
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
                  ? const Color(0xFF0B0F1A)
                  : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: colors.outlineVariant.withAlpha(100),
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
          const SizedBox(height: 8),

          TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyOtpStep(ThemeData theme, bool isDark, ColorScheme colors) {
    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.gold.withAlpha(isDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppTheme.gold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أدخل رمز التحقق',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _targetPhone,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _step = _PhoneChangeStep.inputPhone;
                                    _errorMessage = null;
                                  });
                                },
                          child: const Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: AppTheme.gold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text(
            'أدخل الكود المكون من 4 أرقام لتأكيد رقمك الجديد:',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),

          // 4-digit OTP Field
          TextFormField(
            controller: _otpController,
            autofocus: true,
            enabled: !_isLoading,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            maxLength: 4,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 14,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            validator: (val) {
              if ((val ?? '').trim().length != 4) {
                return 'يرجى إدخال كود التحقق المكون من 4 أرقام';
              }
              return null;
            },
            onFieldSubmitted: (_) => _verifyAndChangePhone(),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              hintStyle: TextStyle(
                letterSpacing: 14,
                color: colors.onSurfaceVariant.withAlpha(80),
              ),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF0B0F1A)
                  : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: colors.outlineVariant.withAlpha(100),
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

          const SizedBox(height: 16),

          // Resend Timer Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_secondsRemaining > 0)
                Text(
                  'إعادة الإرسال بعد $_secondsRemaining ثانية',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                TextButton.icon(
                  onPressed: _isLoading ? null : _resendOtp,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('إعادة إرسال الكود الآن'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.gold),
                ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isLoading ? null : _verifyAndChangePhone,
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
                      'تأكيد وتحديث الرقم',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),

          TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
