import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../presentation/admin/admin_alerts_screen.dart';
import '../presentation/admin/admin_dashboard_screen.dart';
import '../presentation/admin/admin_login_screen.dart';
import '../presentation/admin/admin_pricing_zones_screen.dart';
import '../presentation/admin/admin_trip_details_screen.dart';
import '../presentation/admin/staff_login_v16.dart';
import '../presentation/admin/team_entry_v17.dart';
import '../presentation/captain_dashboard_screen/captain_dashboard_screen.dart';
import '../presentation/captain_dashboard_screen/captain_debt_invoice_v17.dart';
import '../presentation/captain_dashboard_screen/captain_demand_map_screen.dart';
import '../presentation/captain_dashboard_screen/captain_live_trip_screen.dart';
import '../presentation/captain_dashboard_screen/captain_market_order_screen.dart';
import '../presentation/customer/customer_more_screen.dart';
import '../presentation/customer/customer_trips_screen.dart';
import '../presentation/feedback/feedback_screen.dart';
import '../presentation/home_screen/home_screen.dart';
import '../presentation/karizma/karizma_screen.dart';
import '../presentation/legal/legal_center_screen.dart';
import '../presentation/merchant/merchant_dashboard_screen.dart';
import '../presentation/notifications/customer_notifications_screen.dart';
import '../presentation/onboarding/onboarding_screen.dart';
import '../presentation/sign_up_login_screen/captain_registration_screen.dart';
import '../presentation/sign_up_login_screen/sign_up_login_screen.dart';
import '../presentation/trip_booking_screen/live_trip_screen.dart'
    as customer_live_trip;
import '../presentation/trip_booking_screen/trip_booking_screen.dart';
import '../presentation/trip_booking_screen/trip_chat_screen.dart';
import '../presentation/vito_market/vito_market_checkout_screen.dart';
import '../presentation/vito_market/vito_market_order_tracking_screen.dart';
import '../presentation/vito_market/vito_market_products_screen.dart';
import '../presentation/vito_market/vito_market_screen.dart';
import '../presentation/wallet/customer_wallet_screen.dart';
import '../presentation/wallet/wallet_topup_screen.dart';
import '../services/booking_address_seed.dart';
import '../services/staff_access_v16.dart';
import '../services/supabase_service.dart';
import '../services/veto_mode_v21.dart';
import '../widgets/app_scaffold.dart';

class AppRoutes {
  static const String initial = '/';
  static const String homeScreen = '/home-screen';
  static const String signUpLoginScreen = '/sign-up-login-screen';
  static const String tripBookingScreen = '/trip-booking-screen';
  static const String captainDashboardScreen = '/captain-dashboard';
  static const String captainLiveTrip = '/captain-live-trip';
  static const String captainMarketOrder = '/captain-market-order';
  static const String adminLogin = '/admin';
  static const String teamEntry = '/team-entry';
  static const String captainDebtInvoice = '/captain/debt-invoice';
  static const String adminDashboard = '/admin/dashboard';
  static const String merchantDashboard = '/merchant/dashboard';
  static const String liveTrip = '/live-trip';
  static const String notifications = '/notifications';
  static const String walletTopup = '/wallet/top-up';
  static const String captainRegistration = '/captain-registration';
  static const String vitoMarket = '/vito-market';
  static const String vitoMarketProducts = '/vito-market/products';
  static const String vitoMarketCheckout = '/vito-market/checkout';
  static const String vitoMarketOrderTracking = '/vito-market/order-tracking';
  static const String customerFeedback = '/feedback';
  static const String tripChat = '/trip-chat';
  static const String customerKarizma = '/karizma';
  static const String captainKarizma = '/captain-karizma';
  static const String legalCenter = '/legal';
  static const String privacyPolicy = '/privacy-policy';
  static const String termsOfService = '/terms-of-service';
  static const String deleteAccount = '/delete-account';
  static const String safetySupport = '/safety-support';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.initial,
  redirect: (context, state) async {
    final path = state.matchedLocation;

    // Block unauthenticated access to protected routes
    final user = SupabaseService.instance.currentUser;

    // Admin routes — require admin role (checked via auth metadata, no user_profiles query)
    if (path.startsWith('/admin/')) {
      if (user == null) return AppRoutes.adminLogin;
      // Use is_admin_safe() which reads auth.users metadata — avoids user_profiles RLS recursion
      try {
        final access = await StaffAccessV16.load();
        if (!access.active) return AppRoutes.signUpLoginScreen;
      } catch (_) {
        return AppRoutes.adminLogin;
      }
      return null;
    }

    // Captain dashboard — require captain role
    if (path == AppRoutes.captainDashboardScreen) {
      if (user == null) return AppRoutes.signUpLoginScreen;
      final role = await SupabaseService.instance.getUserRole(user.id);
      if (role != 'captain' ||
          VetoModeV21.customerView ||
          VetoModeV21.staffView) {
        return AppRoutes.homeScreen;
      }
      // Opening dashboard while on a live trip must restore the dedicated
      // captain trip screen; never show the customer trip screen here.
      final captain = await SupabaseService.instance.getCaptainByUserId(
        user.id,
      );
      if (captain != null) {
        final active = await SupabaseService.instance.getActiveTripForCaptain(
          captain['id'].toString(),
        );
        if (active != null) {
          return '${AppRoutes.captainLiveTrip}?tripId=${active['id']}';
        }
      }
      return null;
    }

    // Merchant area is part of the same app, but isolated to the store linked
    // to the authenticated merchant account by server-side RLS.
    if (path.startsWith('/merchant/')) {
      if (user == null) return AppRoutes.signUpLoginScreen;
      final role = await SupabaseService.instance.getUserRole(user.id);
      if (role != 'merchant') return AppRoutes.signUpLoginScreen;
      return null;
    }

    // Debt billing is private to the authenticated captain, never a customer.
    // Only an authenticated captain may open the dedicated captain screen.
    if (path == AppRoutes.captainDebtInvoice ||
        path == '/captain/demand-map' ||
        path == AppRoutes.captainLiveTrip ||
        path == AppRoutes.captainMarketOrder) {
      if (user == null) return AppRoutes.signUpLoginScreen;
      final role = await SupabaseService.instance.getUserRole(user.id);
      if (role != 'captain' ||
          VetoModeV21.customerView ||
          VetoModeV21.staffView) {
        return AppRoutes.homeScreen;
      }
      return null;
    }

    // Shared trip/chat routes: both customer and captain may enter.
    if (path == AppRoutes.liveTrip || path == AppRoutes.tripChat) {
      if (user == null) return AppRoutes.signUpLoginScreen;
      final role = await SupabaseService.instance.getUserRole(user.id);
      if (role != 'customer' && role != 'captain') {
        return AppRoutes.signUpLoginScreen;
      }
      // Old bookmarks/login builds incorrectly opened the customer trip UI
      // for captains. Repair the route on the server-checked captain role.
      if (path == AppRoutes.liveTrip &&
          role == 'captain' &&
          !VetoModeV21.customerView) {
        final captain = await SupabaseService.instance.getCaptainByUserId(
          user.id,
        );
        if (captain != null) {
          final active = await SupabaseService.instance.getActiveTripForCaptain(
            captain['id'].toString(),
          );
          if (active != null) {
            return '${AppRoutes.captainLiveTrip}?tripId=${active['id']}';
          }
        }
        return AppRoutes.captainDashboardScreen;
      }
      return null;
    }

    // Customer routes.
    if (path == '/onboarding') {
      if (user == null) return AppRoutes.signUpLoginScreen;
      final role = await SupabaseService.instance.getUserRole(user.id);
      if (role != 'customer' &&
          !(role == 'captain' &&
              VetoModeV21.customerView &&
              await VetoModeV21.canUseCustomer(user.id))) {
        return AppRoutes.homeScreen;
      }
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(OnboardingScreen.preferenceKey(user.id)) == true ||
          user.userMetadata?['veto_visual_onboarding_seen_v34'] == true) {
        return AppRoutes.homeScreen;
      }
      return null;
    }
    if (path == AppRoutes.homeScreen ||
        path == '/my-trips' ||
        path == '/wallet' ||
        path == AppRoutes.walletTopup ||
        path == '/more' ||
        path == AppRoutes.customerFeedback ||
        path == AppRoutes.customerKarizma) {
      if (user == null) return AppRoutes.signUpLoginScreen;
      final role = await SupabaseService.instance.getUserRole(user.id);
      if (role == 'admin' || role == 'staff') return AppRoutes.adminDashboard;
      if (role == 'applicant') return AppRoutes.captainRegistration;
      if (role == 'captain' &&
          !(VetoModeV21.customerView &&
              await VetoModeV21.canUseCustomer(user.id))) {
        return AppRoutes.captainDashboardScreen;
      }
      if (role == 'merchant') return AppRoutes.merchantDashboard;
      if (path == AppRoutes.homeScreen && role == 'customer') {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool(OnboardingScreen.preferenceKey(user.id)) != true &&
            user.userMetadata?['veto_visual_onboarding_seen_v34'] != true) {
          return '/onboarding';
        }
      }
      return null;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/staff-login',
      builder: (context, state) => const StaffLoginV16(),
    ),
    GoRoute(
      path: AppRoutes.teamEntry,
      builder: (_, __) => const TeamEntryV17(),
    ),
    GoRoute(
      path: AppRoutes.captainDebtInvoice,
      builder: (_, __) => const CaptainDebtInvoiceV17(),
    ),
    GoRoute(
      path: '/admin/pricing-zones',
      builder: (_, _) => const AdminPricingZonesScreen(),
    ),
    GoRoute(
      path: '/captain/demand-map',
      builder: (_, _) => const CaptainDemandMapScreen(),
    ),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(
      path: '/admin/alerts',
      builder: (_, __) => const AdminAlertsScreen(),
    ),
    GoRoute(
      path: '/admin/trip-details',
      builder: (_, state) {
        final id = state.uri.queryParameters['tripId'];
        if (id == null || !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) {
          return const Scaffold(
            body: Center(child: Text('رقم الرحلة غير صحيح')),
          );
        }
        return AdminTripDetailsScreen(tripId: id);
      },
    ),
    // Auth
    GoRoute(
      path: AppRoutes.initial,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SignUpLoginScreen(),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            ),
      ),
    ),
    GoRoute(
      path: AppRoutes.signUpLoginScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SignUpLoginScreen(),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: FadeTransition(opacity: animation, child: child),
            ),
      ),
    ),
    // Legal routes must remain accessible without a signed-in session.
    GoRoute(
      path: AppRoutes.legalCenter,
      builder: (context, state) => const VetoLegalCenterScreen(),
    ),
    GoRoute(
      path: AppRoutes.privacyPolicy,
      builder: (context, state) =>
          const VetoLegalCenterScreen(pageKey: 'privacy'),
    ),
    GoRoute(
      path: AppRoutes.termsOfService,
      builder: (context, state) =>
          const VetoLegalCenterScreen(pageKey: 'terms'),
    ),
    GoRoute(
      path: AppRoutes.deleteAccount,
      builder: (context, state) =>
          const VetoLegalCenterScreen(pageKey: 'deletion'),
    ),
    GoRoute(
      path: AppRoutes.safetySupport,
      builder: (context, state) =>
          const VetoLegalCenterScreen(pageKey: 'safety'),
    ),
    // Trip booking
    GoRoute(
      path: AppRoutes.tripBookingScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: TripBookingScreen(
          retryTripId: state.uri.queryParameters['retryTripId'],
          timeoutRetry: state.uri.queryParameters['timeoutRetry'] == '1',
          initialService: state.uri.queryParameters['service'],
          resumeTripId: state.uri.queryParameters['resumeTripId'],
          initialAddresses: state.extra is BookingAddressSelection
              ? state.extra as BookingAddressSelection
              : null,
        ),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: FadeTransition(opacity: animation, child: child),
            ),
      ),
    ),
    GoRoute(
      path: AppRoutes.captainRegistration,
      builder: (context, state) => const CaptainRegistrationScreen(),
    ),
    // Live trip
    GoRoute(
      path: AppRoutes.liveTrip,
      pageBuilder: (context, state) {
        final tripId = state.uri.queryParameters['tripId'] ?? '';
        return CustomTransitionPage(
          key: state.pageKey,
          child: customer_live_trip.LiveTripScreen(tripId: tripId),
          transitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: FadeTransition(opacity: animation, child: child),
              ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.notifications,
      builder: (context, state) => const CustomerNotificationsScreen(),
    ),
    GoRoute(
      path: AppRoutes.customerFeedback,
      builder: (context, state) => FeedbackScreen(
        initialType: state.uri.queryParameters['type'] == 'complaint'
            ? 'complaint'
            : 'suggestion',
      ),
    ),
    GoRoute(
      path: AppRoutes.tripChat,
      builder: (context, state) =>
          TripChatScreen(tripId: state.uri.queryParameters['tripId'] ?? ''),
    ),
    GoRoute(
      path: AppRoutes.captainKarizma,
      builder: (context, state) => const KarizmaScreen(audience: 'captain'),
    ),
    GoRoute(
      path: AppRoutes.captainLiveTrip,
      builder: (context, state) => CaptainLiveTripScreen(
        tripId: state.uri.queryParameters['tripId'] ?? '',
      ),
    ),
    // Vito Market routes (completely separate from ride booking)
    GoRoute(
      path: AppRoutes.vitoMarket,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const VitoMarketScreen(),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: FadeTransition(opacity: animation, child: child),
            ),
      ),
    ),
    GoRoute(
      path: AppRoutes.vitoMarketProducts,
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final supermarket = extra['supermarket'] as Map<String, dynamic>? ?? {};
        return CustomTransitionPage(
          key: state.pageKey,
          child: VitoMarketProductsScreen(supermarket: supermarket),
          transitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: FadeTransition(opacity: animation, child: child),
              ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.vitoMarketCheckout,
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final supermarket = extra['supermarket'] as Map<String, dynamic>? ?? {};
        final cart = extra['cart'] as Map<String, Map<String, dynamic>>? ?? {};
        return CustomTransitionPage(
          key: state.pageKey,
          child: VitoMarketCheckoutScreen(supermarket: supermarket, cart: cart),
          transitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: FadeTransition(opacity: animation, child: child),
              ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.vitoMarketOrderTracking,
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final orderId = extra['orderId'] as String? ?? '';
        return CustomTransitionPage(
          key: state.pageKey,
          child: VitoMarketOrderTrackingScreen(orderId: orderId),
          transitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
                child: child,
              ),
        );
      },
    ),
    // Captain dashboard (separate from customer nav)
    GoRoute(
      path: AppRoutes.captainDashboardScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const CaptainDashboardScreen(),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: FadeTransition(opacity: animation, child: child),
            ),
      ),
    ),
    GoRoute(
      path: AppRoutes.captainMarketOrder,
      pageBuilder: (context, state) {
        final orderId = state.uri.queryParameters['orderId'] ?? '';
        return CustomTransitionPage(
          key: state.pageKey,
          child: CaptainMarketOrderScreen(orderId: orderId),
          transitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, .06),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
        );
      },
    ),
    // Admin routes
    GoRoute(
      path: AppRoutes.adminLogin,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const AdminLoginScreen(),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            ),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminDashboard,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const AdminDashboardScreen(),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            ),
      ),
    ),
    GoRoute(
      path: AppRoutes.merchantDashboard,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const MerchantDashboardScreen(),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
    // Additive customer top-up route; authenticated customer guard above.
    GoRoute(
      path: AppRoutes.walletTopup,
      builder: (context, state) => WalletTopupScreen(
        initialOfferId: state.extra is String ? state.extra as String : null,
      ),
    ),
    // Customer shell with bottom nav (NO captain/admin access)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.homeScreen,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/my-trips',
              builder: (context, state) => const CustomerTripsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/wallet',
              builder: (context, state) => const CustomerWalletScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.customerKarizma,
              builder: (context, state) => KarizmaScreen(
                audience: 'customer',
                onMenu: () => Scaffold.maybeOf(context)?.openDrawer(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/more',
              builder: (context, state) => const CustomerMoreScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

