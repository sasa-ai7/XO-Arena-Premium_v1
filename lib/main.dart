import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/app_l10n.dart';
import 'core/app_theme.dart';
import 'core/firebase_bootstrap.dart';
import 'core/startup.dart';
import 'firebase_options.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/home/home_hub.dart';
import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'screens/maintenance_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/fcm_service.dart';
import 'services/local_store.dart';
import 'services/online_reconnect_controller.dart';
import 'widgets/weak_connection_overlay.dart';

/// App Check is intentionally DISABLED until Firebase Blaze + App Check
/// (Play Integrity attestation) are configured for project 928308967161.
///
/// The IAP coin flow now uses a Google Play *client-only* fulfillment path that
/// does NOT depend on Cloud Functions or App Check, so nothing in the purchase
/// flow needs App Check to grant coins. Activating an unconfigured provider only
/// causes log spam / failures, so we never call FirebaseAppCheck.instance
/// .activate() while this is false. Do NOT flip to true without first enabling
/// the App Check API in Firebase Console and configuring the Play Integrity
/// attestation provider.
const bool kEnableAppCheck = false;

Future<void> main() async {
  Zone? startupZone;

  void runAppInStartupZone(Widget app) {
    final zone = startupZone;
    if (zone == null) {
      if (kDebugMode) {
        debugPrint(
            '[main] Startup zone was unavailable for runApp(${app.runtimeType}).');
      }
      return;
    }
    zone.run<void>(() => runApp(app));
  }

  await runZonedGuarded(() async {
    startupZone = Zone.current;

    WidgetsFlutterBinding.ensureInitialized();

    // Hard kill switch for google_fonts: never fetch from fonts.gstatic.com
    // at runtime. All text uses locally bundled Inter / Orbitron families
    // registered in pubspec.yaml. Leaving this enabled previously caused
    // unhandled zone errors and crash spam whenever the device was offline.
    GoogleFonts.config.allowRuntimeFetching = false;
    if (kDebugMode) {
      debugPrint('[FONT] runtime Google Fonts fetching disabled');
      debugPrint('[FONT] using bundled Inter + Orbitron families');
    }

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (shouldShowMaintenanceScreen(details.exception)) {
        runAppInStartupZone(const MaintenanceScreen());
      }
    };

    final firebaseReady = Completer<void>();
    FirebaseBootstrap.configure(firebaseReady.future);
    runAppInStartupZone(const NewYorkXOApp());

    // Paint the existing Intro screen before invoking FlutterFire's native
    // initialization. Startup route resolution awaits [FirebaseBootstrap], so
    // auth state remains correct while the first visible frame is no longer
    // withheld by plugin/network setup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 300), () async {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          FirebaseMessaging.onBackgroundMessage(
              firebaseMessagingBackgroundHandler);
          OnlineReconnectController.instance.init();
          if (kDebugMode) {
            debugPrint(
                '[main] App Check disabled until Blaze/App Check setup is ready. '
                '(kEnableAppCheck=$kEnableAppCheck)');
          }
        } catch (error, stackTrace) {
          if (kDebugMode) {
            debugPrint('[main] Firebase initialization failed: $error');
            debugPrintStack(stackTrace: stackTrace);
          }
          if (shouldShowMaintenanceScreen(error)) {
            runAppInStartupZone(const MaintenanceScreen());
          }
        } finally {
          if (!firebaseReady.isCompleted) firebaseReady.complete();
        }
      });
    });
  }, (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[main] Unhandled zone error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    if (shouldShowMaintenanceScreen(error)) {
      runAppInStartupZone(const MaintenanceScreen());
    }
  });
}

class NewYorkXOApp extends StatelessWidget {
  const NewYorkXOApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocalStore.localeNotifier,
      builder: (_, locale, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'XO Arena',
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppL10nDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppPalette.homeBgBase,
            // Default family must be one that is actually bundled (see
            // pubspec.yaml fonts:). 'Rajdhani' was never bundled and silently
            // fell back to the platform default; 'Inter' matches the app's
            // safeInter()/homeInter() helpers.
            fontFamily: 'Inter',
          ),
          routes: {
            '/home': (context) => const HomeHub(),
            '/login': (context) => const LoginScreen(),
            '/welcome': (context) => const WelcomeScreen(),
            // Admin dashboard (Flutter web). Gated by AdminGate inside the
            // screen — non-admins are bounced to /home.
            '/admin': (context) => const AdminHomeScreen(),
          },
          // Mount the Weak Connection overlay above every route. It only
          // appears when AppMode.connectionProblem is active; otherwise it
          // is invisible and zero-cost.
          builder: (context, child) =>
              AppModeOverlayHost(child: child ?? const SizedBox.shrink()),
          home: const _AppEntry(),
        );
      },
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  late final Future<String> _startupRouteFuture;

  @override
  void initState() {
    super.initState();
    _startupRouteFuture = getStartupRouteFuture();
  }

  @override
  Widget build(BuildContext context) {
    // Proper animated intro on every cold launch. It resolves the startup route
    // in parallel and replaces itself with Home / Offline Setup when done —
    // a visual gate, never an auth gate, never gated by a "seen" flag.
    return IntroScreen(
      startupRouteFuture: _startupRouteFuture,
      startupRouteBuilder: buildStartupPageRoute,
    );
  }
}
