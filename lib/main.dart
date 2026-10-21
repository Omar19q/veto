import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:sizer/sizer.dart';
import 'package:country_picker/country_picker.dart';
import 'l10n/app_localizations.dart';
import 'services/product_preferences.dart';
import 'widgets/product_preference_account_bridge.dart';
import 'services/product_session_timing.dart';

import './services/supabase_service.dart';
import './presentation/growth/growth_startup.dart';
import './services/push_notification_service.dart';
import './services/post_trip_checkin_onesignal_v26.dart';
import './services/app_session_guard.dart';
import './services/network_guard.dart';
import './services/trip_chat_inbox.dart';
import './services/captain_ban_guard.dart';
import './widgets/custom_error_widget.dart';
import 'core/app_export.dart';

const String _oneSignalAppId = 'cd7162a5-5426-4bdd-b0f6-41decc5000a9';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Notification payloads are displayed by the OS in background.
  if (message.notification != null) return;
  await PushNotificationService.instance.showBackgroundData(message);
}

Future<void> _requestOneSignalPermission() async {
  try {
    await OneSignal.Notifications.requestPermission(false);
  } catch (e) {
    debugPrint('OneSignal notification permission request failed: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ProductSessionTiming.instance.start();
  await ProductPreferences.instance.load();

  // Android notifications are owned by OneSignal; avoid processing the
  // underlying FCM envelope twice through the legacy background handler.
  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Initialize Supabase
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Failed to initialize Supabase: $e');
  }

  // Initialize OneSignal on Android only for the first device push test.
  // Keep the existing Firebase handlers until push delivery is verified.
  final useOneSignal =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool oneSignalInitialized = false;
  if (useOneSignal) {
    try {
      OneSignal.initialize(_oneSignalAppId);
      PostTripCheckinOneSignalV26.instance.start();
      oneSignalInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize OneSignal: $e');
    }
  }

  await PushNotificationService.instance.initialize();
  try {
    await TripChatInbox.instance.initialize(appRouter.routeInformationProvider);
  } catch (error) {
    debugPrint('Chat inbox initialization deferred: $error');
  }

  bool hasShownError = false;

  // 🚨 CRITICAL: Custom error handling - DO NOT REMOVE
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (!hasShownError) {
      hasShownError = true;

      // Reset flag after 5 seconds to allow error widget on new screens
      Future.delayed(Duration(seconds: 5), () {
        hasShownError = false;
      });

      return CustomErrorWidget(errorDetails: details);
    }
    return SizedBox.shrink();
  };

  // 🚨 CRITICAL: Device orientation lock - skip on web (not supported)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(MyApp());

  // Ask for notification permission after Flutter draws the first frame.
  // This avoids blocking startup and does not change app navigation.
  if (oneSignalInitialized) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestOneSignalPermission();
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, screenType) {
        return AnimatedBuilder(
          animation: Listenable.merge([
            ProductPreferences.instance,
            appRouter.routeInformationProvider,
          ]),
          builder: (context, _) {
            final path = appRouter.routeInformationProvider.value.uri.path;
            final admin =
                path.startsWith('/admin') ||
                path.startsWith('/team-entry') ||
                path.startsWith('/staff');
            return MaterialApp.router(
              title: 'VETO SANYA',
              theme: admin ? AppTheme.lightTheme : AppTheme.productTheme(
                Brightness.light, ProductPreferences.instance.locale.languageCode),
              darkTheme: admin ? AppTheme.darkTheme : AppTheme.productTheme(
                Brightness.dark, ProductPreferences.instance.locale.languageCode),
              themeMode: admin
                  ? ThemeMode.dark
                  : ProductPreferences.instance.themeMode,
              locale: admin
                  ? const Locale('ar')
                  : ProductPreferences.instance.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: [
                ...AppLocalizations.localizationsDelegates,
                CountryLocalizations.delegate,
              ],
              // 🚨 CRITICAL: NEVER REMOVE OR MODIFY
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: admin ? TextScaler.noScaling : MediaQuery.textScalerOf(context)),
                  child: NetworkGuard(
                    child: AppSessionGuard(
                      child: ProductPreferenceAccountBridge(
                        child: CaptainBanGuard(
                          child: GrowthStartup(child: child!),
                        ),
                      ),
                    ),
                  ),
                );
              },
              // 🚨 END CRITICAL SECTION
              debugShowCheckedModeBanner: false,
              routerConfig: appRouter,
            );
          },
        );
      },
    );
  }
}
