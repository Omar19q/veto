import '../../../services/phone_identity.dart';
import '../../../l10n/strings.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/supabase_service.dart';
import '../../../services/veto_mode_v21.dart';
import '../../../theme/app_theme.dart';

class AuthOtpStepWidget extends StatefulWidget {
  final String phone;
  final void Function(bool isNewUser, String? customerId) onVerified;
  final VoidCallback onBack;

  const AuthOtpStepWidget({
    super.key,
    required this.phone,
    required this.onVerified,
    required this.onBack,
  });

  @override
  State<AuthOtpStepWidget> createState() => _AuthOtpStepWidgetState();
}

class _AuthOtpStepWidgetState extends State<AuthOtpStepWidget> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showSupport = false;
  int _secondsElapsed = 0;
  Timer? _timer;
  String? _supportPhone;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadSupportPhone();
  }

  Future<void> _loadSupportPhone() async {
    try {
      final phone = await SupabaseService.instance.getSetting('support_phone');
      if (mounted && phone != null) {
        setState(() => _supportPhone = phone);
      }
    } catch (_) {
      if (mounted) setState(() => _supportPhone = '');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _secondsElapsed++;
        if (_secondsElapsed >= 30) _showSupport = true;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  String? _validateOtp(String? value) {
    if (value == null || value.isEmpty) return context.strings.auth4b6a0d56;
    if (!RegExp(r'^\d{4}$').hasMatch(PhoneIdentity.normalizeDigits(value))) {
      return context.strings.auth94b8b549;
    }
    return null;
  }

  Future<void> _resend() async {
    if (_isLoading || _secondsElapsed < 60) return;
    setState(() => _isLoading = true);
    try {
      await SupabaseService.instance.createVerificationRequest(widget.phone);
      if (mounted) {
        setState(() {
          _secondsElapsed = 0;
          _hasError = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.authRequestPendingV2)),
        );
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _hasError = true;
          _errorMessage = context.strings.verificationFailed;
        });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _submit() async {
    if (_isLoading) return;
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final code = PhoneIdentity.normalizeDigits(_otpController.text).trim();
      final phone = widget.phone.trim();
      final normalizedPhone = _normalizePhone(phone);

      // Resolve the role only to select the matching secure backend. Neither
      // customer nor captain codes are ever compared inside the mobile app.
      final loginRole = await SupabaseService.instance.getLoginRoleByPhone(
        normalizedPhone,
      );

      if (loginRole == 'ambiguous') {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = context.strings.auth8ba78f82;
          });
        }
        return;
      }

      if (loginRole == 'verification_staff') {
        final response = await SupabaseService.instance.client.functions.invoke(
          'staff-code-login',
          body: {'phone': normalizedPhone, 'code': code},
        );
        final data = response.data;
        if (data is! Map ||
            data['success'] != true ||
            data['email'] is! String ||
            data['token'] is! String) {
          throw StateError('staff_verification_failed');
        }
        final authenticated = await SupabaseService.instance.client.auth
            .verifyOTP(
              email: data['email'] as String,
              token: data['token'] as String,
              type: OtpType.magiclink,
            );
        if (authenticated.session == null)
          throw StateError('staff_session_failed');
        await SupabaseService.instance.activateSessionV25();
        VetoModeV21.staffView = true;
        VetoModeV21.customerView = false;
        if (mounted) widget.onVerified(false, null);
        return;
      }

      final isCaptain = loginRole == 'captain';
      final isMerchant = loginRole == 'merchant';

      if (isMerchant) {
        final response = await SupabaseService.instance.client.functions.invoke(
          'merchant-code-login',
          body: {'phone': normalizedPhone, 'code': code},
        );
        if (response.data == null || response.data is! Map) {
          throw Exception('invalid_server_response');
        }
        final data = Map<String, dynamic>.from(response.data as Map);
        if (data['success'] != true) {
          final serverError = data['error']?.toString();
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = switch (serverError) {
                'verification_pending' => context.strings.auth877ec1c8,
                'verification_expired' => context.strings.auth2fb0282a,
                'verification_attempts_exceeded' =>
                  context.strings.authf4eb3c84,
                'verification_invalid' => context.strings.auth7cf0e2f5,
                'merchant_not_found' => context.strings.auth5063b733,
                'merchant_auth_creation_failed' => context.strings.auth00d3d260,
                'merchant_profile_sync_failed' => context.strings.authc9ff542b,
                'merchant_session_generation_failed' =>
                  context.strings.auth9736c215,
                _ => context.strings.auth7525bff1,
              };
            });
          }
          return;
        }
        final email = data['email']?.toString().trim() ?? '';
        final token = data['token']?.toString().trim() ?? '';
        if (email.isEmpty || token.isEmpty)
          throw Exception('missing_auth_token');
        final authResponse = await SupabaseService.instance.client.auth
            .verifyOTP(email: email, token: token, type: OtpType.magiclink);
        if (authResponse.session == null)
          throw Exception('merchant_session_not_created');
        await SupabaseService.instance.activateSessionV25();
        if (mounted) {
          setState(() => _isLoading = false);
          widget.onVerified(false, null);
        }
        return;
      }

      if (isCaptain) {
        // Captain verification + authentication happen together on the
        // secure backend. This prevents consuming the verification request
        // twice and prevents Captain from entering the customer flow.
        final response = await SupabaseService.instance.client.functions.invoke(
          'captain-code-login',
          body: {'phone': normalizedPhone, 'code': code},
        );

        if (response.data == null || response.data is! Map) {
          throw Exception('invalid_server_response');
        }

        final data = Map<String, dynamic>.from(response.data as Map);

        if (data['success'] != true) {
          final serverError = data['error']?.toString();
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = switch (serverError) {
                'verification_pending' => context.strings.auth877ec1c8,
                'verification_expired' => context.strings.authac9e317b,
                'verification_attempts_exceeded' =>
                  context.strings.auth7474039f,
                'verification_invalid' => context.strings.auth7cf0e2f5,
                'captain_not_found' => context.strings.authef7a895a,
                'captain_inactive' => context.strings.auth8d4c6591,
                'captain_auth_not_found' => context.strings.authe1e92bab,
                'captain_auth_hardening_failed' => context.strings.authbf47817e,
                'captain_profile_sync_failed' => context.strings.auth095e455e,
                _ => context.strings.auth767a6bf3,
              };
            });
          }
          return;
        }

        final email = data['email']?.toString().trim() ?? '';
        final token = data['token']?.toString().trim() ?? '';

        if (email.isEmpty || token.isEmpty) {
          throw Exception('missing_auth_token');
        }

        final authResponse = await SupabaseService.instance.client.auth
            .verifyOTP(email: email, token: token, type: OtpType.magiclink);

        if (authResponse.session == null || authResponse.user == null) {
          throw Exception('captain_session_not_created');
        }
        // V25: activate the new Auth session before touching any trip data.
        await SupabaseService.instance.activateSessionV25();

        if (mounted) {
          setState(() => _isLoading = false);
          widget.onVerified(false, null);
        }
        return;
      }

      // Customer verification and authentication happen together on the
      // trusted backend. The app never reads or compares the admin's code and
      // never derives a reusable password from the customer's phone number.
      final data = await SupabaseService.instance.customerCodeLogin(
        normalizedPhone,
        code,
      );

      if (data['success'] != true) {
        final serverError = data['error']?.toString();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = switch (serverError) {
              'verification_pending' => context.strings.auth877ec1c8,
              'verification_expired' => context.strings.authac9e317b,
              'verification_attempts_exceeded' => context.strings.auth7474039f,
              'captain_account' => context.strings.autha18be99f,
              'customer_inactive' => context.strings.auth9ec825fc,
              'customer_auth_not_found' => context.strings.auth6c804eff,
              'customer_auth_creation_failed' => context.strings.auth6dd32123,
              'customer_auth_hardening_failed' => context.strings.authe2341633,
              'customer_profile_creation_failed' =>
                context.strings.auth51953e13,
              'customer_profile_sync_failed' => context.strings.authd7cba707,
              'customer_session_generation_failed' =>
                context.strings.authc15acdd8,
              'customer_auth_link_failed' => context.strings.authd41a26b6,
              'account_blocked' => context.strings.authe4a12e31,
              'account_role_mismatch' => context.strings.auth517e8c1a,
              'verification_lookup_failed' => context.strings.authac51cf01,
              _ => context.strings.authf7179060,
            };
          });
        }
        return;
      }

      final email = data['email']?.toString().trim() ?? '';
      final token = data['token']?.toString().trim() ?? '';
      if (email.isEmpty || token.isEmpty) {
        throw Exception('missing_auth_token');
      }

      final authResponse = await SupabaseService.instance.client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.magiclink,
      );

      if (authResponse.session == null || authResponse.user == null) {
        throw Exception('customer_session_not_created');
      }

      final user = SupabaseService.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = context.strings.auth51721be4;
          });
        }
        return;
      }

      // V25: must happen before first authenticated customer/profile query.
      await SupabaseService.instance.activateSessionV25();

      final serverCustomerId = data['customer_id']?.toString().trim() ?? '';
      if (serverCustomerId.isNotEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          widget.onVerified(false, serverCustomerId);
        }
        return;
      }

      Map<String, dynamic>? customer = await SupabaseService.instance
          .getCustomerByUserId(user.id);
      customer ??= await SupabaseService.instance.getCustomerByPhone(
        normalizedPhone,
      );

      if (customer != null) {
        // Link an existing phone profile to this Auth user when needed.
        if (customer['user_id'] == null) {
          await SupabaseService.instance.client
              .from('customers')
              .update({'user_id': user.id})
              .eq('id', customer['id'] as String);
        }

        if (mounted) {
          setState(() => _isLoading = false);
          widget.onVerified(false, customer['id'] as String?);
        }
        return;
      }

      // First customer login: create the profile without asking for a name.
      final created = await SupabaseService.instance.createCustomer(
        userId: user.id,
        phone: normalizedPhone,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        widget.onVerified(true, created['id'] as String?);
      }
    } on FunctionException catch (error) {
      debugPrint(
        'Login Edge Function failed: status=${error.status} details=${error.details}',
      );
      final details = error.details;
      final serverError = details is Map ? details['error']?.toString() : null;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = _serverErrorMessage(serverError);
        });
      }
    } catch (error) {
      debugPrint('Customer/captain login failed: $error');
      final rawError = error.toString().toLowerCase();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage =
              rawError.contains('socket') ||
                  rawError.contains('network') ||
                  rawError.contains('connection') ||
                  rawError.contains('failed host lookup')
              ? context.strings.auth160e784b
              : rawError.contains('404') ||
                    rawError.contains('requested function was not found')
              ? context.strings.auth54d4f443
              : context.strings.auth51721be4;
        });
      }
    }
  }

  String _serverErrorMessage(String? error) {
    return switch (error) {
      'verification_pending' => context.strings.auth877ec1c8,
      'verification_expired' => context.strings.authac9e317b,
      'verification_attempts_exceeded' => context.strings.auth7474039f,
      'verification_invalid' => context.strings.auth7cf0e2f5,
      'captain_not_found' => context.strings.authef7a895a,
      'captain_inactive' => context.strings.auth8d4c6591,
      'captain_account' => context.strings.autha18be99f,
      'captain_profile_sync_failed' => context.strings.auth095e455e,
      'customer_inactive' => context.strings.auth9ec825fc,
      'customer_profile_sync_failed' => context.strings.authd7cba707,
      'server_not_configured' => context.strings.auth7b3824d7,
      'customer_auth_link_failed' => context.strings.auth7513ec76,
      'customer_auth_creation_failed' => context.strings.authd2227474,
      'customer_session_generation_failed' => context.strings.auth010fd34d,
      'account_blocked' => context.strings.auth31654349,
      'account_role_mismatch' => context.strings.auth517e8c1a,
      'verification_lookup_failed' => context.strings.auth334c0562,
      _ => context.strings.auth51721be4,
    };
  }

  String _normalizePhone(String phone) {
    try {
      return PhoneIdentity.lookup(phone);
    } catch (_) {
      return PhoneIdentity.normalizeDigits(phone).trim();
    }
  }

  Future<void> _openWhatsAppSupport() async {
    final raw = (_supportPhone ?? '').replaceAll(RegExp(r'\D'), '');
    if (raw.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.strings.auth4c5573f4)));
      }
      return;
    }
    final international = raw.startsWith('20')
        ? raw
        : '20${raw.replaceFirst(RegExp(r'^0+'), '')}';
    final uri = Uri.parse('https://wa.me/$international');
    if (!await launchUrl(uri, mode: LaunchMode.platformDefault) && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.auth56a1b88a)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            context.strings.auth653fd437,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.gold.withAlpha(20) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppTheme.gold.withAlpha(70) : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.hourglass_top_rounded,
                  color: isDark ? AppTheme.gold : const Color(0xFFB45309),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.strings.auth4bf997e8,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.gold : const Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.strings.authaff91568,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${context.strings.authPhoneLabelV2}: ${widget.phone}',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _otpController,
            enabled: !_isLoading,
            validator: _validateOtp,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            maxLength: 4,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹]')),
            ],
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.gold : const Color(0xFF0B0F1A),
              letterSpacing: 12,
            ),
            onChanged: (v) {
              if (_hasError) setState(() => _hasError = false);
              if (v.length == 4) _submit();
            },
            decoration: InputDecoration(
              counterText: '',
              hintText: '----',
              hintStyle: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 12,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.gold : const Color(0xFF0B0F1A),
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.errorLight),
              ),
              errorStyle: const TextStyle(color: AppTheme.errorLight),
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
          ),
          if (_hasError) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorLight.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.errorLight.withAlpha(77)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppTheme.errorLight,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.errorLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: AppTheme.primary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      context.strings.authc1717a62,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          TextButton.icon(
            onPressed: _isLoading || _secondsElapsed < 60 ? null : _resend,
            icon: const Icon(Icons.refresh),
            label: Text(context.strings.authResendV2),
          ),
          if (_showSupport) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _openWhatsAppSupport,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.whatsapp.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.whatsapp.withAlpha(77)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.chat_rounded,
                      color: AppTheme.whatsapp,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.strings.authec6b1f69,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.whatsapp,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
