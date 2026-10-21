import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../../theme/admin_theme.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  // ─── Session restore ───────────────────────────────────────────────────────

  Future<void> _checkExistingSession() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    final isAdmin = await _isAdminUser(user.id);

    if (isAdmin && mounted) {
      context.go('/admin/dashboard');
    }
  }

  Future<bool> _isAdminUser(String userId) async {
    try {
      final result = await SupabaseService.instance.client.rpc('is_admin_safe');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  // ─── Login ─────────────────────────────────────────────────────────────────

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final code = _codeController.text.trim();

      final response = await SupabaseService.instance.client.functions.invoke(
        'admin-code-login',
        body: {'code': code},
      );

      final raw = response.data;

      final result = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};

      if (result['success'] != true) {
        _setError(_adminErrorMessage(result['error']?.toString()));
        return;
      }

      final email = result['email'] as String?;
      final token = result['token'] as String?;

      if (email == null || token == null) {
        _setError('تعذر إنشاء جلسة الأدمن');
        return;
      }

      final auth = await SupabaseService.instance.client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.magiclink,
      );

      if (auth.session == null || auth.user == null) {
        _setError('تعذر إنشاء جلسة الأدمن');
        return;
      }

      // V25: register this newly created session before the admin data check.
      await SupabaseService.instance.activateSessionV25();
      final isAdmin = await SupabaseService.instance.client.rpc(
        'is_admin_safe',
      );

      if (isAdmin != true) {
        await SupabaseService.instance.client.auth.signOut();
        _setError('الحساب غير مصرح له بالدخول كأدمن');
        return;
      }

      if (mounted) {
        setState(() => _isLoading = false);
        context.go('/admin/dashboard');
      }
    } on FunctionException catch (error) {
      final details = error.details;
      final serverError = details is Map ? details['error']?.toString() : null;
      _setError(_adminErrorMessage(serverError));
    } catch (error) {
      debugPrint('Admin login failed: $error');
      _setError('تعذر تسجيل الدخول كأدمن، حاول مرة أخرى.');
    }
  }

  String _adminErrorMessage(String? error) {
    return switch (error) {
      'invalid_code' => 'كود التحقق غير صحيح.',
      'too_many_attempts' => 'محاولات كثيرة. انتظر 15 دقيقة ثم حاول مرة أخرى.',
      'server_not_configured' =>
        'دخول الأدمن يحتاج استكمال إعداد أسرار الخادم.',
      'rate_limit_not_configured' => 'حماية محاولات الدخول لم تُفعّل بعد.',
      _ => 'تعذر تسجيل الدخول كأدمن، حاول مرة أخرى.',
    };
  }

  void _setError(String msg) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = AdminTheme.theme;
    final isDark = AdminTheme.dark.value;

    return Theme(
      data: AdminTheme.theme,
      child: Scaffold(
        backgroundColor: isDark ? Color(0xFF0F1117) : Color(0xFFF5F7FA),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(isDark),
                  SizedBox(height: 3.h),
                  _buildCard(theme, isDark),
                  TextButton.icon(
                    onPressed: () => context.push('/staff-login'),
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('دخول الموظفين والمشرفين'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return Column(
      children: [
        Container(
          width: 18.w,
          height: 18.w,
          decoration: BoxDecoration(
            color: AdminTheme.goldDark,
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: [
              BoxShadow(
                color: AdminTheme.goldDark.withAlpha(89),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.admin_panel_settings_rounded,
            color: AdminTheme.ink,
            size: 9.w,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          'لوحة الإدارة',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Color(0xFF1A1D2E),
          ),
          textDirection: TextDirection.rtl,
        ),
        SizedBox(height: 0.5.h),
        Text(
          'أدخل كود التحقق للدخول',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12.sp,
            color: isDark ? Colors.white54 : Color(0xFF6B7280),
          ),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }

  Widget _buildCard(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: 420),
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF1C1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 32,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCodeField(isDark),
            if (_errorMessage != null) ...[
              SizedBox(height: 1.5.h),
              _buildError(),
            ],
            SizedBox(height: 2.5.h),
            _buildLoginButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'كود التحقق',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Color(0xFF374151),
          ),
          textDirection: TextDirection.rtl,
        ),
        SizedBox(height: 0.8.h),
        TextFormField(
          controller: _codeController,
          focusNode: _codeFocus,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 10,
          obscureText: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.robotoMono(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
            color: isDark ? Colors.white : Color(0xFF1A1D2E),
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            hintStyle: GoogleFonts.robotoMono(
              fontSize: 16.sp,
              letterSpacing: 6,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            filled: true,
            fillColor: isDark ? Color(0xFF252840) : Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : Color(0xFFE5E7EB),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : Color(0xFFE5E7EB),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: AdminTheme.goldDark, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: Colors.redAccent),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 4.w,
              vertical: 1.8.h,
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'يرجى إدخال كود التحقق';
            }

            if (v.trim().length < 6) {
              return 'الكود يجب أن يكون من 6 إلى 10 أرقام';
            }

            return null;
          },
          onFieldSubmitted: (_) => _login(),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.sp,
                color: Colors.red.shade700,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 6.h,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminTheme.gold,
          foregroundColor: AdminTheme.ink,
          disabledBackgroundColor: AdminTheme.goldDark.withAlpha(128),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AdminTheme.ink.withAlpha(230),
                  ),
                ),
              )
            : Text(
                'دخول',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
