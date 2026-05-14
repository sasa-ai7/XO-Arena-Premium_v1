import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/app_l10n.dart';
import 'core/app_theme.dart';
import 'core/startup.dart';
import 'firebase_options.dart';
import 'screens/home/home_hub.dart';
import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'screens/maintenance_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/local_store.dart';
import 'widgets/weak_connection_overlay.dart';

/// Set to true only after enabling the Firebase App Check API in Google Cloud Console
/// for project 928308967161. Activating without enabling the API causes log spam.
const bool kEnableAppCheck = false;

Future<void> main() async {
  Zone? startupZone;

  void runAppInStartupZone(Widget app) {
    final zone = startupZone;
    if (zone == null) {
      if (kDebugMode) {
        debugPrint('[main] Startup zone was unavailable for runApp(${app.runtimeType}).');
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

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[main] Firebase initialization failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (shouldShowMaintenanceScreen(error)) {
        runAppInStartupZone(const MaintenanceScreen());
        return;
      }
    }

    if (kEnableAppCheck) {
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
        );
        if (kDebugMode) debugPrint('[main] App Check activated');
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('[main] App Check activation failed (non-fatal): $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    } else if (kDebugMode) {
      debugPrint(
          '[main] App Check skipped (kEnableAppCheck=false). Enable in Firebase Console first.');
    }

    runAppInStartupZone(const NewYorkXOApp());
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
            fontFamily: 'Rajdhani',
          ),
          routes: {
            '/home': (context) => const HomeHub(),
            '/login': (context) => const LoginScreen(),
            '/welcome': (context) => const WelcomeScreen(),
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
    return IntroScreen(
      startupRouteFuture: _startupRouteFuture,
      startupRouteBuilder: buildStartupPageRoute,
    );
  }
}
