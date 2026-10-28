import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import '../../../services/phone_identity.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';

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
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Country _country = Country.parse('EG');
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
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

  Future<void> _submit() async {
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

      if (widget.customerId != null && widget.customerId!.isNotEmpty) {
        await SupabaseService.instance.linkAndSavePhoneForUser(
          userId: widget.userId,
          customerId: widget.customerId!,
          phone: phone,
        );
      } else {
        await SupabaseService.instance.ensureCustomerProfile(
          userId: widget.userId,
          phone: phone,
          fullName: widget.userName,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر حفظ رقم الهاتف. حاول مرة أخرى.';
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
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹+\s()-]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف',
                  hintText: _country.countryCode == 'EG' ? '01xxxxxxxxx' : null,
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

              // Submit button
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
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
