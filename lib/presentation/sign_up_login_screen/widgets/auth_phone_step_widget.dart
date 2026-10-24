import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/phone_identity.dart';
import '../../../l10n/strings.dart';

import '../../../services/supabase_service.dart';
import '../../../routes/app_routes.dart';
import 'package:go_router/go_router.dart';

class AuthPhoneStepWidget extends StatefulWidget {
  final void Function(String phone) onSubmit;

  const AuthPhoneStepWidget({
    super.key,
    required this.onSubmit,
    this.requestVerification,
  });
  final Future<void> Function(String phone)? requestVerification;

  @override
  State<AuthPhoneStepWidget> createState() => _AuthPhoneStepWidgetState();
}

class _AuthPhoneStepWidgetState extends State<AuthPhoneStepWidget> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  Country _country = Country.parse('EG');
  bool _countryChosen = false;
  @override
  void initState() {
    super.initState();
    _restoreCountry();
  }

  Future<void> _restoreCountry() async {
    try {
      final code = (await SharedPreferences.getInstance()).getString(
        'auth.country',
      );
      if (!mounted || _countryChosen || code == null) return;
      setState(() => _country = Country.parse(code));
    } catch (_) {
      /* Egypt remains the default if preferences fail. */
    }
  }

  Future<void> _selectCountry(Country value) async {
    setState(() {
      _countryChosen = true;
      _country = value;
      _errorMessage = null;
    });
    try {
      await (await SharedPreferences.getInstance()).setString(
        'auth.country',
        value.countryCode,
      );
    } catch (_) {
      /* A country choice must remain usable without storage. */
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    try {
      PhoneIdentity.parse(
        value ?? '',
        IsoCode.values.byName(_country.countryCode),
      );
      return null;
    } catch (_) {
      return context.strings.phoneInvalid;
    }
  }

  void _submit() async {
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
      final phone = identity.e164;
      if (mounted && identity.iso.name != _country.countryCode) {
        setState(() => _country = Country.parse(identity.iso.name));
      }
      if (!identity.verificationSupported) {
        throw StateError('international_phone_not_enabled');
      }
      // Original owner/team entry does not create a customer OTP request.
      // This only navigates to a separate authentication screen.
      if (identity.legacyLookup == '01091372888') {
        if (mounted) {
          setState(() => _isLoading = false);
          widget.onSubmit(identity.legacyLookup);
        }
        return;
      }
      // Create verification request in Supabase
      if (widget.requestVerification != null) {
        await widget.requestVerification!(phone);
      } else {
        await SupabaseService.instance.createVerificationRequest(phone);
      }
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onSubmit(phone);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              e.toString().contains('international_phone_not_enabled')
              ? context.strings.internationalUnavailable
              : context.strings.verificationFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.strings, colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.authWelcomeV2,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.authPhoneHintV2,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _phoneController,
            enabled: !_isLoading,
            validator: _validatePhone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹+\s()-]')),
              LengthLimitingTextInputFormatter(24),
            ],
            onFieldSubmitted: (_) {
              if (!_isLoading) _submit();
            },
            decoration: InputDecoration(
              labelText: l.phone,
              hintText: _country.countryCode == 'EG' ? '01xxxxxxxxx' : null,
              prefixIcon: TextButton(
                onPressed: _isLoading
                    ? null
                    : () => showCountryPicker(
                        context: context,
                        showPhoneCode: true,
                        countryFilter: const ['EG', 'GB', 'SA', 'AE'],
                        countryListTheme: CountryListThemeData(
                          inputDecoration: InputDecoration(
                            labelText: l.countrySearch,
                          ),
                        ),
                        onSelect: _selectCountry,
                      ),
                child: Text(
                  '${_country.flagEmoji} +${_country.phoneCode}',
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
          ),
          if (!PhoneIdentity.verifiedCountries.contains(
            IsoCode.values.byName(_country.countryCode),
          ))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l.internationalUnavailable,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          if (_errorMessage != null &&
              !(_country.countryCode != 'EG' &&
                  _errorMessage == l.internationalUnavailable))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: colors.error),
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.arrow_forward_rounded,
                      color: isDark ? const Color(0xFF0B0F1A) : const Color(0xFFFFC107),
                    ),
              label: Text(
                l.requestCode,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l.continueConsent),
              TextButton(
                onPressed: () => context.push(AppRoutes.termsOfService),
                child: Text(l.terms),
              ),
              Text(l.and),
              TextButton(
                onPressed: () => context.push(AppRoutes.privacyPolicy),
                child: Text(l.privacy),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
