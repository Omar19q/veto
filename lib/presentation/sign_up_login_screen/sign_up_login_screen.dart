import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../services/staff_access_v16.dart';
import '../../services/veto_mode_v21.dart';
import '../../theme/app_theme.dart';
import './widgets/auth_logo_widget.dart';
import './widgets/auth_otp_step_widget.dart';
import './widgets/auth_phone_step_widget.dart';

enum _AuthStep { phone, otp }

class SignUpLoginScreen extends StatefulWidget {
  const SignUpLoginScreen({super.key});

  @override
  State<SignUpLoginScreen> createState() => _SignUpLoginScreenState();
}

class _SignUpLoginScreenState extends State<SignUpLoginScreen>
    with SingleTickerProviderStateMixin {
  _AuthStep _currentStep = _AuthStep.phone;
  String _phone = '';
  bool _isCheckingSession = true;
  String? _sessionError;

  late AnimationController _stepController;
  late Animation<double> _stepFade;
  late Animation<Offset> _stepSlide;

  @override
  void initState() {
    super.initState();
    _stepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _stepFade = CurvedAnimation(
      parent: _stepController,
      curve: Curves.easeOutCubic,
    );
    _stepSlide = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _stepController, curve: Curves.easeOutCubic),
        );
    _stepController.forward();
    _checkExistingSession();
  }

  /// Route an authenticated customer directly to Home or their active trip.
  /// Customer name is optional profile data and is never part of authentication.
  Future<bool> _routeCustomer(String userId) async {
    final customer = await SupabaseService.instance.getCustomerByUserId(userId);

    if (customer == null) {
      // No customer profile yet. The OTP flow is responsible for creating it.
      if (mounted) context.go(AppRoutes.homeScreen);
      return true;
    }

    final activeTrip = await SupabaseService.instance.getActiveTrip(
      customer['id'] as String,
    );
    final status = activeTrip?['trip_status']?.toString();
    final hasLiveTrip =
        activeTrip != null &&
        activeTrip['captain_id'] != null &&
        const {'accepted', 'arriving', 'arrived', 'started'}.contains(status);
    if (hasLiveTrip && mounted) {
      context.go('${AppRoutes.liveTrip}?tripId=${activeTrip['id']}');
      return true;
    }

    if (mounted) context.go(AppRoutes.homeScreen);
    return true;
  }

  Future<void> _checkExistingSession() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) {
      setState(() => _isCheckingSession = false);
      return;
    }

    try {
      // Never reactivate a session the admin ended or another device replaced.
      final sessionState = await SupabaseService.instance.sessionStatusV25();
      if (sessionState['active'] != true) {
        await SupabaseService.instance.signOut();
        if (mounted)
          setState(() {
            _isCheckingSession = false;
            _currentStep = _AuthStep.phone;
            _sessionError = sessionState['reason'] == 'admin_ended'
                ? 'تم إنهاء الجلسة من الإدارة. سجل الدخول مجددًا.'
                : 'تم تسجيل الدخول من جهاز آخر. سجل الدخول مجددًا.';
          });
        return;
      }
      if (sessionState['registered'] == false) {
        await SupabaseService.instance.activateSessionV25();
      }
      if (VetoModeV21.staffView) {
        final access = await StaffAccessV16.load();
        if (access.active && mounted) {
          context.go(AppRoutes.adminDashboard);
          return;
        }
        VetoModeV21.staffView = false;
      }
      final earlyRole = await SupabaseService.instance.getUserRole(user.id);
      if (earlyRole == 'staff' || earlyRole == 'applicant') {
        if (mounted)
          context.go(
            earlyRole == 'staff'
                ? AppRoutes.adminDashboard
                : AppRoutes.captainRegistration,
          );
        return;
      }
      final access = await SupabaseService.instance.getMyAccountAccessV16();
      if (access['allowed'] != true) {
        await SupabaseService.instance.signOut();
        if (mounted)
          setState(() {
            _isCheckingSession = false;
            _currentStep = _AuthStep.phone;
            _sessionError = access['reason'] == 'account_blocked'
                ? 'حسابك محظور. يرجى التواصل مع الدعم الفني.'
                : 'الحساب غير نشط. يرجى التواصل مع الدعم الفني.';
          });
        return;
      }
      final role = await SupabaseService.instance.getUserRole(user.id);
      if (!mounted) return;
      // A customer who is also an authorized verification moderator opens
      // the verification desk by default. Approved captains still start in
      // captain mode, and can open the desk explicitly from More.
      if (role == 'customer' && !VetoModeV21.customerView) {
        try {
          final staff = await StaffAccessV16.load();
          if (staff.active &&
              staff.can('verification.view') &&
              staff.can('verification.manage')) {
            VetoModeV21.staffView = true;
            if (mounted) context.go(AppRoutes.adminDashboard);
            return;
          }
        } catch (_) {}
      }

      if (role == 'applicant') {
        context.go(AppRoutes.captainRegistration);
        return;
      } else if (role == 'admin' || role == 'staff') {
        context.go(AppRoutes.adminDashboard);
        return;
      } else if (role == 'merchant') {
        context.go(AppRoutes.merchantDashboard);
        return;
      } else if (role == 'captain') {
        final captain = await SupabaseService.instance.getCaptainByUserId(
          user.id,
        );
        if (captain != null) {
          final activeTrip = await SupabaseService.instance
              .getActiveTripForCaptain(captain['id'] as String);
          if (activeTrip != null && mounted) {
            context.go(
              '${AppRoutes.captainLiveTrip}?tripId=${activeTrip['id']}',
            );
            return;
          }
        }
        if (mounted) context.go(AppRoutes.captainDashboardScreen);
        return;
      } else {
        // Customer
        await _routeCustomer(user.id);
        return;
      }
    } catch (_) {
      setState(() => _isCheckingSession = false);
    }
  }

  @override
  void dispose() {
    _stepController.dispose();
    super.dispose();
  }

  void _transitionTo(_AuthStep step) {
    _stepController.reverse().then((_) {
      setState(() => _currentStep = step);
      _stepController.forward();
    });
  }

  void _onPhoneSubmitted(String phone) {
    // Restore V17 owner/team choice for the designated entry number.
    // This does NOT authenticate anyone: the owner's code and role are
    // verified by the unchanged admin-code-login backend and admin route.
    if (phone.replaceAll(RegExp(r'\D'), '') == '01091372888') {
      context.go(AppRoutes.teamEntry);
      return;
    }
    VetoModeV21.reset();
    setState(() {
      _phone = phone;
      _sessionError = null;
    });
    _transitionTo(_AuthStep.otp);
  }

  void _onOtpVerified(bool isNewUser, String? customerId) {
    // The OTP widget passes true only after creating a new customer profile.
    // Existing accounts continue to their original role/active-trip flow.
    // Gift eligibility remains server-side; the Home gate uses the claimed
    // enrollment and never treats this local boolean as financial authority.
    _routeAfterLogin();
  }

  Future<void> _routeAfterLogin() async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) {
        if (mounted) context.go(AppRoutes.homeScreen);
        return;
      }

      if (VetoModeV21.staffView) {
        final staff = await StaffAccessV16.load();
        if (staff.active) {
          if (mounted) context.go(AppRoutes.adminDashboard);
          return;
        }
        VetoModeV21.staffView = false;
      }
      final access = await SupabaseService.instance.getMyAccountAccessV16();
      if (access['allowed'] != true) {
        await SupabaseService.instance.signOut();
        if (mounted)
          setState(() {
            _isCheckingSession = false;
            _currentStep = _AuthStep.phone;
            _sessionError = access['reason'] == 'account_blocked'
                ? 'حسابك محظور. يرجى التواصل مع الدعم الفني.'
                : 'الحساب غير نشط. يرجى التواصل مع الدعم الفني.';
          });
        return;
      }
      if (VetoModeV21.staffView) {
        final access = await StaffAccessV16.load();
        if (access.active && mounted) {
          context.go(AppRoutes.adminDashboard);
          return;
        }
        VetoModeV21.staffView = false;
      }
      final role = await SupabaseService.instance.getUserRole(user.id);
      if (!mounted) return;
      // A customer who is also an authorized verification moderator opens
      // the verification desk by default. Approved captains still start in
      // captain mode, and can open the desk explicitly from More.
      if (role == 'customer' && !VetoModeV21.customerView) {
        try {
          final staff = await StaffAccessV16.load();
          if (staff.active &&
              staff.can('verification.view') &&
              staff.can('verification.manage')) {
            VetoModeV21.staffView = true;
            if (mounted) context.go(AppRoutes.adminDashboard);
            return;
          }
        } catch (_) {}
      }

      if (role == 'applicant') {
        context.go(AppRoutes.captainRegistration);
        return;
      } else if (role == 'admin' || role == 'staff') {
        context.go(AppRoutes.adminDashboard);
        return;
      }

      if (role == 'merchant') {
        context.go(AppRoutes.merchantDashboard);
        return;
      }

      if (role == 'captain') {
        final captain = await SupabaseService.instance.getCaptainByUserId(
          user.id,
        );
        if (captain != null && mounted) {
          final activeTrip = await SupabaseService.instance
              .getActiveTripForCaptain(captain['id'] as String);
          if (activeTrip != null && mounted) {
            context.go(
              '${AppRoutes.captainLiveTrip}?tripId=${activeTrip['id']}',
            );
            return;
          }
        }
        if (mounted) context.go(AppRoutes.captainDashboardScreen);
        return;
      }

      await _routeCustomer(user.id);
    } catch (e) {
      await SupabaseService.instance.signOut();
      if (mounted)
        setState(() {
          _sessionError =
              'تعذر التأكد من صلاحية الحساب. حاول تسجيل الدخول مجددًا.';
          _currentStep = _AuthStep.phone;
        });
    }
  }

  void _onBack() {
    if (_currentStep == _AuthStep.otp) {
      _transitionTo(_AuthStep.phone);
    } else {
      _transitionTo(_AuthStep.otp);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.gold),
        ),
      );
    }

    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 480 : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthLogoWidget(),
                    if (_sessionError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _sessionError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    FadeTransition(
                      opacity: _stepFade,
                      child: SlideTransition(
                        position: _stepSlide,
                        child: _buildCurrentStep(),
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

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case _AuthStep.phone:
        return AuthPhoneStepWidget(onSubmit: _onPhoneSubmitted);
      case _AuthStep.otp:
        return AuthOtpStepWidget(
          phone: _phone,
          onVerified: _onOtpVerified,
          onBack: _onBack,
        );
    }
  }
}
