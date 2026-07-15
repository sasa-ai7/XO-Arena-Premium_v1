import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/keys.dart';
import '../core/firebase_bootstrap.dart';
import '../screens/home/home_hub.dart';
import '../screens/login_screen.dart';
import '../screens/offline_player_setup_screen.dart';
import '../screens/welcome_screen.dart';
import '../services/local_store.dart';
import '../services/app_mode_service.dart';
import '../services/mission_service.dart';
import '../widgets/full_avatar_display.dart';

Future<String>? _startupRouteFuture;

Future<String> getStartupRouteFuture() {
  return _startupRouteFuture ??= _prepareStartupRoute();
}

Future<String> _prepareStartupRoute() async {
  await FirebaseBootstrap.ready;
  final warmupFuture = _warmStartupServices();
  final routeName = await _resolveStartupRouteName();
  await warmupFuture;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future<void>.delayed(
      const Duration(milliseconds: 700),
      () => unawaited(_runDeferredStartupJobs()),
    );
  });
  return routeName;
}

Future<void> _runDeferredStartupJobs() async {
  Future<void> runSafely(String name, Future<void> Function() job) async {
    try {
      await job();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[startup] deferred $name failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  // These jobs are deliberately independent. A slow local migration or plugin
  // call in one must never delay the first usable Home frame or the other job.
  unawaited(runSafely('missions', MissionService.instance.init));
  unawaited(runSafely(
    'date formatting',
    () => Future.wait<void>(<Future<void>>[
      _initializeDateFormattingSafely('en_US'),
      _initializeDateFormattingSafely('pt_BR'),
    ]),
  ));
}

Future<void> _warmStartupServices() async {
  // Select the data namespace before any wallet/cosmetic notifier loads.
  // A local-only player must never read or write the signed-in cache.
  final signedIn =
      Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null;
  AppModeService.setMode(signedIn ? AppMode.online : AppMode.offline);

  FullAvatarDisplay.bindNotifier(LocalStore.profilePhotoUrlNotifier);
  FullAvatarDisplay.bindLocalPathNotifier(LocalStore.profileImagePathNotifier);
  FullAvatarDisplay.bindOfflineAvatarAssetNotifier(
      LocalStore.offlineAvatarAssetNotifier);

  try {
    await LocalStore.ensureDefaults();
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[startup] ensureDefaults failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // Load persisted language preference before rendering UI.
  try {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString(Keys.appLanguage) ?? 'en';
    LocalStore.localeNotifier.value = Locale(lang);
  } catch (_) {}

  // One-time online→offline data split: seed the offline namespace from the
  // shared keys so existing offline players keep their cosmetics/missions when
  // offline. Must run BEFORE the notifiers/missions load so they read the
  // seeded offline values. No-op for online-only or already-seeded installs.
  try {
    await LocalStore.seedOfflineNamespaceIfNeeded();
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[startup] offline seed failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  try {
    await Future.wait<void>([
      LocalStore.initCoinsNotifier(),
      LocalStore.initProfileNotifier(),
    ]);
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[startup] local notifiers failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // Offline-first: when there is no signed-in user but a local offline profile
  // exists, seed the Home avatar with the chosen boy/girl portrait so it
  // persists across launches. Signed-in users keep their online avatar (the
  // notifier stays null and is re-cleared by HomeHub on mount).
  try {
    final hasUser =
        Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null;
    if (!hasUser) {
      final profile = await LocalStore.getOfflineProfile();
      if (profile != null) {
        LocalStore.offlineAvatarAssetNotifier.value = profile.avatarAssetPath;
      }
    }
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[startup] offline avatar seed failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // SoundService init is intentionally NOT part of the startup warmup
  // anymore. Initializing MediaPlayer (and on iOS the audio session) during
  // route resolution caused 100+ skipped frames during the first home
  // entrance animation. SoundService is now initialized lazily on the
  // first request via its own internal `ensureInitialized()` gate (see
  // SoundService implementation) and a deferred warm-up runs after the
  // home entrance via the post-frame callback in HomeHub.
  if (kDebugMode) {
    debugPrint('[PERF] delayed SoundService init — lazy on first use');
  }
  // Avatar analysis is also lazy — runs only when the avatar shop/display is
  // opened. Pre-analyzing all avatars at startup caused 150+ skipped frames
  // on first launch because the flood-fill algorithm runs on the main thread.
}

Future<void> _initializeDateFormattingSafely(String locale) async {
  try {
    await initializeDateFormatting(locale, null);
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[startup] Date formatting failed for $locale: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

Future<String> _resolveStartupRouteName() async {
  final prefs = await SharedPreferences.getInstance();

  bool hasUser = false;
  try {
    if (Firebase.apps.isNotEmpty) {
      hasUser = FirebaseAuth.instance.currentUser != null;
    }
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[startup] Failed to inspect auth session: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // Offline-first: a completed offline profile (or a signed-in user) goes
  // straight to Home. A legacy guest that only has guestName/offlineGuest but
  // no full profile (no character chosen yet) is routed through setup so it can
  // be migrated into a full OfflinePlayerProfile — the setup screen pre-fills
  // the saved name and just asks the player to pick a character.
  final offlineProfileExists =
      prefs.getBool(Keys.offlineProfileExists) ?? false;

  if (hasUser || offlineProfileExists) {
    return '/home';
  }

  // New install OR legacy guest → one-page offline player setup. We NEVER force
  // welcome/login at startup anymore — sign-in is optional and only needed
  // later for online / store features.
  return '/offlineSetup';
}

Route<void> buildStartupPageRoute(String routeName) {
  Widget page;
  switch (routeName) {
    case '/home':
      page = const HomeHub();
      break;
    case '/login':
      page = const LoginScreen();
      break;
    case '/welcome':
      page = const WelcomeScreen();
      break;
    case '/offlineSetup':
      page = const OfflinePlayerSetupScreen();
      break;
    default:
      if (kDebugMode) {
        debugPrint(
            '[startup] Unknown route "$routeName", defaulting to /offlineSetup');
      }
      routeName = '/offlineSetup';
      page = const OfflinePlayerSetupScreen();
      break;
  }

  return PageRouteBuilder<void>(
    settings: RouteSettings(name: routeName),
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.02),
        end: Offset.zero,
      ).animate(fade);
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: child,
        ),
      );
    },
  );
}

// ==========================
//   APP ENTRY
// ==========================
