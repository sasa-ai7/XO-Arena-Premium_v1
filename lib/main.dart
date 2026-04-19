import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'core/app_config.dart';
import 'core/app_theme.dart';
import 'core/keys.dart';
import 'firebase_options.dart';
import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'services/audit_service.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/sound_service.dart';
import 'services/session_service.dart';
import 'services/user_repo.dart';
import 'models/user_data.dart';
import 'models/game_avatar.dart';
import 'widgets/app_ui.dart';
import 'widgets/avatar_store_tab.dart';
import 'widgets/full_avatar_display.dart';
import 'coins/coins_screen.dart';
import 'coins/iap_coins_service.dart';
// match_reward_service.dart removed — rewards are now handled directly via LocalStore

Future<String>? _startupRouteFuture;

Future<String> _getStartupRouteFuture() {
  return _startupRouteFuture ??= _prepareStartupRoute();
}

Future<String> _prepareStartupRoute() async {
  final warmupFuture = _warmStartupServices();
  final routeName = await _resolveStartupRouteName();
  await warmupFuture;
  return routeName;
}

Future<void> _warmStartupServices() async {
  FullAvatarDisplay.bindNotifier(LocalStore.profilePhotoUrlNotifier);

  try {
    await LocalStore.ensureDefaults();
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[startup] ensureDefaults failed: $error');
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

  await Future.wait<void>([
    _initializeDateFormattingSafely('en_US'),
    _initializeDateFormattingSafely('pt_BR'),
    _initializeSoundServiceSafely(),
  ]);
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

Future<void> _initializeSoundServiceSafely() async {
  try {
    await SoundService().init();
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[startup] SoundService init failed: $error');
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

  final hasGuestName =
      (prefs.getString(Keys.guestName) ?? '').trim().isNotEmpty;
  final offlineGuest = prefs.getBool(Keys.offlineGuest) ?? false;
  final goHome = hasUser || hasGuestName || offlineGuest;

  return goHome ? '/home' : '/login';
}

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

    // Flutter requires binding initialization and runApp to share one zone.
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (_shouldShowMaintenanceScreen(details.exception)) {
        runAppInStartupZone(const _MaintenanceScreen());
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
      if (_shouldShowMaintenanceScreen(error)) {
        runAppInStartupZone(const _MaintenanceScreen());
        return;
      }
    }

    runAppInStartupZone(const NewYorkXOApp());
  }, (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[main] Unhandled zone error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    if (_shouldShowMaintenanceScreen(error)) {
      runAppInStartupZone(const _MaintenanceScreen());
    }
  });
}

/// Simple maintenance screen shown when app encounters an error.
class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.build,
                    size: 80,
                    color: Colors.orange,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Under Maintenance',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'The program has an error and is under maintenance',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _shouldShowMaintenanceScreen(Object error) {
  final msg = error.toString().toLowerCase();
  if (msg.contains('missingpluginexception') ||
      msg.contains('platformexception')) {
    return false;
  }
  if (msg.contains('socket') ||
      msg.contains('network') ||
      msg.contains('timeout') ||
      msg.contains('host lookup') ||
      msg.contains('connection')) {
    return false;
  }
  if (msg.contains('permission') ||
      msg.contains('firestore') ||
      msg.contains('firebase') ||
      msg.contains('auth') ||
      msg.contains('500') ||
      msg.contains('502') ||
      msg.contains('503')) {
    return false;
  }
  if (msg.contains('parsing') ||
      msg.contains('parse') ||
      msg.contains('malformed')) {
    return false;
  }
  if (msg.contains('binding') ||
      msg.contains('flutter error') ||
      msg.contains('assertion')) {
    return true;
  }
  return false;
}

/// =======================================================
///  XO ARENA (FIXED, CONSISTENT UI DESIGN)
///  - UI chrome/theme is fixed (does NOT change with X/O color)
///  - Only the X and O pieces use the selected neon colors
///  - Setup screen: choose symbol + difficulty, no weird bottom space
///  - Game screen: board centered, coins top, next player top
///  - AI taps are ignored while AI is thinking / moving
///  - Validation errors appear under fields (not snackbars)
///  - Rounded/oval buttons everywhere
/// =======================================================

const String kAppName = "XO ARENA";

const int kThemePriceCoins = 100;
const int kWinRewardCoins = 15;

/// First color 100, +50 per index, max 1000.
int priceForColorIndex(int index) => (100 + index * 50).clamp(100, 1000);

final _rng = Random();

/// ==========================
///   NEON COLOR COLLECTIONS
///   (Only affects pieces, not UI chrome)
/// ==========================
class NeonColors {
  static final List<Color> xColors = [
    const Color(0xFFFF3B30),
    const Color(0xFFFF2D55),
    const Color(0xFFFF375F),
    const Color(0xFFFF6B6B),
    const Color(0xFFFF9500),
    const Color(0xFFFFD60A),
    const Color(0xFF32D74B),
    const Color(0xFF64D2FF),
    const Color(0xFF5E5CE6),
    const Color(0xFFBF5AF2),
    const Color(0xFFFF3AA6),
    const Color(0xFF00FFFF),
    const Color(0xFF30E0A1),
    const Color(0xFFFF0040),
    const Color(0xFFFF8C00),
    const Color(0xFFADFF2F),
    const Color(0xFF00FF7F),
    const Color(0xFF40E0D0),
    const Color(0xFF9370DB),
    const Color(0xFFFF1493),
  ];

  static final List<Color> oColors = [
    const Color(0xFF0A84FF),
    const Color(0xFF32D74B),
    const Color(0xFF64D2FF),
    const Color(0xFF5E5CE6),
    const Color(0xFFBF5AF2),
    const Color(0xFFFFD60A),
    const Color(0xFFFF375F),
    const Color(0xFF30E0A1),
    const Color(0xFFFF6B6B),
    const Color(0xFF00FFFF),
    const Color(0xFFADFF2F),
    const Color(0xFFFF00FF),
    const Color(0xFF00FF7F),
    const Color(0xFFFF8C00),
    const Color(0xFF9370DB),
    const Color(0xFF40E0D0),
    const Color(0xFFFF1493),
    const Color(0xFF7FFF00),
    const Color(0xFFDC143C),
    const Color(0xFF20B2AA),
  ];

  static String colorToString(Color color) =>
      color.value.toRadixString(16).padLeft(8, '0');

  static Color stringToColor(String hex) => Color(int.parse(hex, radix: 16));
}

/// ==========================
///   LOCAL STORAGE
/// ==========================
class LocalStore {
  static Future<SharedPreferences> _p() => SharedPreferences.getInstance();
  static String? get _uid => AuthService().currentUser?.uid;

  /// Reactive coin balance — screens listen to this for real-time updates.
  static final ValueNotifier<int> coinsNotifier = ValueNotifier<int>(0);

  /// Bumped whenever owned cosmetics change (purchase or equip).
  /// VaultPage listens to this so it reloads when returning from the Store tab.
  static final ValueNotifier<int> cosmeticsVersion = ValueNotifier<int>(0);

  /// Reactive equipped avatar id - Top Bar and Profile listen to this.
  static final ValueNotifier<int> equippedAvatarNotifier =
      ValueNotifier<int>(1);

  /// Reactive local profile image path.
  static final ValueNotifier<String?> profileImagePathNotifier =
      ValueNotifier<String?>(null);

  /// Reactive Google/Firebase profile photo URL - all avatar composites listen.
  static final ValueNotifier<String?> profilePhotoUrlNotifier =
      ValueNotifier<String?>(null);

  static List<int> _parseOwnedList(String raw, {required int fallback}) {
    final parsed = raw
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
    return parsed.isEmpty ? <int>[fallback] : parsed;
  }

  static Map<String, dynamic> _cosmeticsPayload(
    SharedPreferences p, {
    String? xColor,
    String? oColor,
    List<int>? ownedX,
    List<int>? ownedO,
    List<int>? ownedAvatars,
    int? equippedAvatar,
  }) {
    final customXConfigs = p.getString(Keys.customXConfigs);
    final customOConfigs = p.getString(Keys.customOConfigs);

    return {
      'xColor': xColor ??
          p.getString(Keys.xColor) ??
          NeonColors.colorToString(NeonColors.xColors[0]),
      'oColor': oColor ??
          p.getString(Keys.oColor) ??
          NeonColors.colorToString(NeonColors.oColors[0]),
      'ownedXColors': ownedX ??
          _parseOwnedList(p.getString(Keys.ownedXColors) ?? '0', fallback: 0),
      'ownedOColors': ownedO ??
          _parseOwnedList(p.getString(Keys.ownedOColors) ?? '0', fallback: 0),
      'equippedAvatar': equippedAvatar ?? p.getInt(Keys.equippedAvatar) ?? 1,
      'ownedAvatars': ownedAvatars ??
          _parseOwnedList(p.getString(Keys.ownedAvatars) ?? '1', fallback: 1),
      if (customXConfigs != null && customXConfigs.isNotEmpty)
        'customXConfigsV2': customXConfigs,
      if (customOConfigs != null && customOConfigs.isNotEmpty)
        'customOConfigsV2': customOConfigs,
    };
  }

  /// Call once at app startup to seed notifiers from SharedPreferences.
  static Future<void> initCoinsNotifier() async {
    final p = await _p();
    coinsNotifier.value = p.getInt(Keys.coins) ?? 200;
    equippedAvatarNotifier.value = p.getInt(Keys.equippedAvatar) ?? 1;
  }

  /// Call once at app startup to seed the profile image/photo notifiers.
  static Future<void> initProfileNotifier() async {
    final p = await _p();
    profileImagePathNotifier.value = p.getString(Keys.profilePhotoPath);
    profilePhotoUrlNotifier.value = p.getString(Keys.profilePhotoUrl);
  }

  static Future<void> _syncToFirestore(Map<String, dynamic> updates) async {
    final uid = _uid;
    if (uid == null || updates.isEmpty) return;

    try {
      await UserRepo().syncToFirestore(uid, updates);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[LocalStore] Firestore sync error: $error');
      }
    }
  }

  static Future<void> ensureDefaults() async {
    final p = await _p();

    await p.setInt(Keys.coins, p.getInt(Keys.coins) ?? 200);
    await p.setString(
      Keys.xColor,
      p.getString(Keys.xColor) ??
          NeonColors.colorToString(NeonColors.xColors[0]),
    );
    await p.setString(
      Keys.oColor,
      p.getString(Keys.oColor) ??
          NeonColors.colorToString(NeonColors.oColors[0]),
    );
    await p.setString(Keys.ownedXColors, p.getString(Keys.ownedXColors) ?? '0');
    await p.setString(Keys.ownedOColors, p.getString(Keys.ownedOColors) ?? '0');
    await p.setInt(Keys.equippedAvatar, p.getInt(Keys.equippedAvatar) ?? 1);
    await p.setString(Keys.ownedAvatars, p.getString(Keys.ownedAvatars) ?? '1');

    final currentLevel = p.getInt(Keys.levelGameCurrentLevel) ?? 1;
    await p.setInt(
      Keys.levelGameCurrentLevel,
      currentLevel <= 0 ? 1 : currentLevel,
    );
    await p.setBool(
      Keys.levelGameCompleted,
      p.getBool(Keys.levelGameCompleted) ?? false,
    );

    coinsNotifier.value = p.getInt(Keys.coins) ?? 200;
    equippedAvatarNotifier.value = p.getInt(Keys.equippedAvatar) ?? 1;
  }

  static Future<int> coins() async {
    final p = await _p();
    return p.getInt(Keys.coins) ?? 200;
  }

  static Future<void> setCoins(int amount) async {
    final p = await _p();
    final safeAmount = max(0, amount);
    await p.setInt(Keys.coins, safeAmount);
    coinsNotifier.value = safeAmount;
    await _syncToFirestore({
      'Wallet': {'coins': safeAmount}
    });
  }

  static Future<void> updateCoins(int delta) async {
    final p = await _p();
    final current = p.getInt(Keys.coins) ?? 200;
    final next = max(0, current + delta);
    await p.setInt(Keys.coins, next);
    coinsNotifier.value = next;
    await _syncToFirestore({
      'Wallet': {'coins': next}
    });
  }

  static Future<int> applyCoinDeltaLocally(int delta) async {
    final p = await _p();
    final current = p.getInt(Keys.coins) ?? 200;
    final next = max(0, current + delta);
    await p.setInt(Keys.coins, next);
    coinsNotifier.value = next;
    return next;
  }

  static Future<void> syncCoinBalance() async {
    final p = await _p();
    final current = p.getInt(Keys.coins) ?? coinsNotifier.value;
    await _syncToFirestore({
      'Wallet': {'coins': current}
    });
  }

  static Future<void> addCoins(int amount) async {
    await updateCoins(amount);
  }

  static Future<void> addResult({required String result}) async {
    final p = await _p();
    final normalized = result.toLowerCase();
    final gp = (p.getInt(Keys.gamesPlayed) ?? 0) + 1;
    await p.setInt(Keys.gamesPlayed, gp);

    int w = p.getInt(Keys.wins) ?? 0;
    int l = p.getInt(Keys.losses) ?? 0;
    int d = p.getInt(Keys.draws) ?? 0;

    if (normalized == 'win') {
      w++;
      await p.setInt(Keys.wins, w);
    } else if (normalized == 'loss') {
      l++;
      await p.setInt(Keys.losses, l);
    } else {
      d++;
      await p.setInt(Keys.draws, d);
    }

    await _syncToFirestore({
      'Stats': {'gamesPlayed': gp, 'wins': w, 'losses': l, 'draws': d}
    });
  }

  static Future<Color> xPieceColor() async {
    final p = await _p();
    final hex = p.getString(Keys.xColor) ??
        NeonColors.colorToString(NeonColors.xColors[0]);
    return NeonColors.stringToColor(hex);
  }

  static Future<Color> oPieceColor() async {
    final p = await _p();
    final hex = p.getString(Keys.oColor) ??
        NeonColors.colorToString(NeonColors.oColors[0]);
    return NeonColors.stringToColor(hex);
  }

  static Future<void> setXPieceColor(Color c) async {
    final p = await _p();
    final hex = NeonColors.colorToString(c);
    await p.setString(Keys.xColor, hex);
    cosmeticsVersion.value++;
    await _syncToFirestore({'Cosmetics': _cosmeticsPayload(p, xColor: hex)});
  }

  static Future<void> setOPieceColor(Color c) async {
    final p = await _p();
    final hex = NeonColors.colorToString(c);
    await p.setString(Keys.oColor, hex);
    cosmeticsVersion.value++;
    await _syncToFirestore({'Cosmetics': _cosmeticsPayload(p, oColor: hex)});
  }

  static Future<List<int>> ownedXColors() async {
    final p = await _p();
    final s = p.getString(Keys.ownedXColors) ?? "0";
    return s.split(",").map(int.tryParse).whereType<int>().toSet().toList()
      ..sort();
  }

  static Future<List<int>> ownedOColors() async {
    final p = await _p();
    final s = p.getString(Keys.ownedOColors) ?? "0";
    return s.split(",").map(int.tryParse).whereType<int>().toSet().toList()
      ..sort();
  }

  static Future<void> addOwnedXColor(int index) async {
    final p = await _p();
    final set = (p.getString(Keys.ownedXColors) ?? "0")
        .split(",")
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    set.add(index);
    final list = set.toList()..sort();
    await p.setString(Keys.ownedXColors, list.join(","));
    cosmeticsVersion.value++;
    await _syncToFirestore({'Cosmetics': _cosmeticsPayload(p, ownedX: list)});
  }

  static Future<void> addOwnedOColor(int index) async {
    final p = await _p();
    final set = (p.getString(Keys.ownedOColors) ?? "0")
        .split(",")
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    set.add(index);
    final list = set.toList()..sort();
    await p.setString(Keys.ownedOColors, list.join(","));
    cosmeticsVersion.value++;
    await _syncToFirestore({'Cosmetics': _cosmeticsPayload(p, ownedO: list)});
  }

  static Future<List<int>> ownedAvatars() async {
    final p = await _p();
    final s = p.getString(Keys.ownedAvatars) ?? '1';
    return s.split(',').map(int.tryParse).whereType<int>().toSet().toList()
      ..sort();
  }

  static Future<int> equippedAvatar() async {
    final p = await _p();
    return p.getInt(Keys.equippedAvatar) ?? 1;
  }

  static Future<void> addOwnedAvatar(int id) async {
    final p = await _p();
    final set = (p.getString(Keys.ownedAvatars) ?? '1')
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    set.add(id);
    final list = set.toList()..sort();
    await p.setString(Keys.ownedAvatars, list.join(','));
    cosmeticsVersion.value++;
    await _syncToFirestore(
        {'Cosmetics': _cosmeticsPayload(p, ownedAvatars: list)});
  }

  static Future<void> setEquippedAvatar(int id) async {
    final p = await _p();
    await p.setInt(Keys.equippedAvatar, id);
    equippedAvatarNotifier.value = id;
    cosmeticsVersion.value++;
    await _syncToFirestore(
        {'Cosmetics': _cosmeticsPayload(p, equippedAvatar: id)});
  }

  static Future<String?> profilePhotoPath() async {
    final p = await _p();
    return p.getString(Keys.profilePhotoPath);
  }

  static Future<void> setProfilePhotoPath(String? path) async {
    final p = await _p();
    if (path == null || path.isEmpty) {
      await p.remove(Keys.profilePhotoPath);
      profileImagePathNotifier.value = null;
      return;
    }
    await p.setString(Keys.profilePhotoPath, path);
    profileImagePathNotifier.value = path;
  }

  /// Get or set the Google/Firebase profile photo URL.
  static Future<String?> profilePhotoUrl() async {
    final p = await _p();
    return p.getString(Keys.profilePhotoUrl);
  }

  static Future<void> setProfilePhotoUrl(String? url) async {
    final p = await _p();
    if (url == null || url.isEmpty) {
      await p.remove(Keys.profilePhotoUrl);
      profilePhotoUrlNotifier.value = null;
      return;
    }
    await p.setString(Keys.profilePhotoUrl, url);
    profilePhotoUrlNotifier.value = url;
  }

  static Future<void> addTopupHistory(
      {required double usd,
      required int coins,
      required String type,
      String? description,
      String? transactionId,
      int? balanceBefore,
      int? balanceAfter}) async {
    final p = await _p();
    if (transactionId != null && transactionId.isNotEmpty) {
      final logged = p.getString(Keys.loggedTransactionIds) ?? '';
      final loggedSet = logged.split(',').where((s) => s.isNotEmpty).toSet();
      if (loggedSet.contains(transactionId)) {
        if (kDebugMode) {
          debugPrint(
              '[LocalStore] Duplicate transactionId skipped: $transactionId');
        }
        return;
      }
      loggedSet.add(transactionId);
      await p.setString(Keys.loggedTransactionIds, loggedSet.join(','));
    }
    final nowIso = DateTime.now().toIso8601String();
    final entry =
        "$nowIso|$usd|$coins|$type|${balanceBefore ?? ''}|${balanceAfter ?? ''}|${description ?? ''}";
    final old = p.getString(Keys.topupHistory) ?? "";
    final combined = old.isEmpty ? entry : "$entry,$old";
    await p.setString(Keys.topupHistory, combined);
    // Only sync to Firestore when online - never throw on offline
    final uid = _uid;
    if (uid != null) {
      try {
        if (await ConnectivityService().online) {
          await UserRepo().addTransaction(uid, usd, coins, type,
              transactionId: transactionId,
              balanceBefore: balanceBefore,
              balanceAfter: balanceAfter,
              description: description);
        }
      } catch (_) {
        if (kDebugMode) {
          debugPrint(
              '[LocalStore] addTopupHistory Firestore sync error (ignored): $_');
        }
      }
    }
  }

  static Future<List<Map<String, dynamic>>> getTopupHistory() async {
    final uid = _uid;
    if (uid != null) {
      try {
        final tx = await UserRepo().getTransactions(uid);
        if (tx.isNotEmpty) return _dedupeHistoryList(tx);
      } catch (_) {}
    }
    final p = await _p();
    final historyStr = p.getString(Keys.topupHistory) ?? "";
    if (historyStr.isEmpty) return [];
    final entries = historyStr.split(',');
    final parsed = <Map<String, dynamic>>[];
    for (final entry in entries) {
      final parts = entry.split('|');
      if (parts.length < 4) continue;
      final dateTime = DateTime.tryParse(parts[0]);
      if (dateTime == null) continue;
      final usd = double.tryParse(parts[1]) ?? 0;
      final rawCoins = int.tryParse(parts[2]) ?? 0;
      final type = TransactionRecord.mapLegacyType(parts[3]);
      final balanceBefore = parts.length > 4 && parts[4].isNotEmpty
          ? int.tryParse(parts[4])
          : null;
      final balanceAfter = parts.length > 5 && parts[5].isNotEmpty
          ? int.tryParse(parts[5])
          : null;
      final description =
          parts.length > 6 && parts[6].isNotEmpty ? parts[6] : null;

      parsed.add({
        'dateTime': dateTime,
        'usd': usd,
        'coins': rawCoins,
        'type': type,
        if (balanceBefore != null) 'balanceBefore': balanceBefore,
        if (balanceAfter != null) 'balanceAfter': balanceAfter,
        if (description != null) 'description': description,
      });
    }
    return _dedupeHistoryList(parsed);
  }

  static List<Map<String, dynamic>> _dedupeHistoryList(
      List<Map<String, dynamic>> list) {
    final seen = <String>{};
    final deduped = list.where((entry) {
      final dateTime = entry['dateTime'] as DateTime?;
      final coins = entry['coins'] as int? ?? 0;
      final type = entry['type'] as String? ?? '';
      final key = '${dateTime?.millisecondsSinceEpoch ?? 0}_${coins}_$type';
      if (!seen.add(key)) return false;
      return true;
    }).toList();
    deduped.sort((a, b) {
      final aDate =
          a['dateTime'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          b['dateTime'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return deduped;
  }

  static Future<int> getLevelGameCurrentLevel() async {
    final p = await _p();
    final level = p.getInt(Keys.levelGameCurrentLevel) ?? 1;
    return level == 0 ? 1 : level;
  }

  static Future<void> setLevelGameCurrentLevel(int level) async {
    final p = await _p();
    final safeLevel = level.clamp(1, 20);
    await p.setInt(Keys.levelGameCurrentLevel, safeLevel);
    await p.setBool(Keys.levelGameCompleted, false);
    await _syncToFirestore({
      'Progress': {
        'levelGameCurrentLevel': safeLevel,
        'levelGameCompleted': false,
      }
    });
  }

  static Future<void> setLevelGameCompleted(bool completed) async {
    final p = await _p();
    await p.setBool(Keys.levelGameCompleted, completed);
    await _syncToFirestore({
      'Progress': {'levelGameCompleted': completed}
    });
  }

  static Future<void> incrementLevelGameCompletions() async {
    final p = await _p();
    final current = p.getInt(Keys.levelGameCompletions) ?? 0;
    await p.setInt(Keys.levelGameCompletions, current + 1);
    await _syncToFirestore({
      'Progress': {'levelGameCompletions': current + 1}
    });
  }

  static Future<void> resetLevelGame() async {
    final p = await _p();
    await p.setInt(Keys.levelGameCurrentLevel, 1);
    await p.setBool(Keys.levelGameCompleted, false);
    await _syncToFirestore({
      'Progress': {
        'levelGameCurrentLevel': 1,
        'levelGameCompleted': false,
      }
    });
  }
}

/// ==========================

class _ProfileHeader extends StatelessWidget {
  final String username;
  final String email;
  final String provider;
  final int games;
  final int wins;
  final int losses;
  final int draws;
  final int topLevel;
  final GameAvatar avatar;
  final bool editingName;
  final TextEditingController usernameController;
  final VoidCallback onCameraTap;
  final VoidCallback onEditName;
  final VoidCallback onCancelEdit;
  final Future<void> Function() onSaveName;

  const _ProfileHeader({
    required this.username,
    required this.email,
    required this.provider,
    required this.games,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.topLevel,
    required this.avatar,
    required this.editingName,
    required this.usernameController,
    required this.onCameraTap,
    required this.onEditName,
    required this.onCancelEdit,
    required this.onSaveName,
  });

  @override
  Widget build(BuildContext context) {
    final avatarWidget = SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Hero(
            tag: 'profile_avatar',
            child: FullAvatarDisplay(
              size: 130,
              avatar: avatar,
              fallbackName: username,
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppPalette.primary2, AppPalette.primary],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppPalette.gold.withValues(alpha: 0.40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.primary.withValues(alpha: 0.30),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 28, height: 28),
                onPressed: onCameraTap,
                icon:
                    const Icon(Icons.camera_alt, size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );

    return AppGlassCard(
      padding: const EdgeInsets.all(22),
      radius: 24,
      borderColor: AppPalette.strokeStrong.withValues(alpha: 0.72),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppPalette.panelElevated.withValues(alpha: 0.98),
          AppPalette.panelDeep.withValues(alpha: 0.98),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.34),
          blurRadius: 30,
          offset: const Offset(0, 18),
        ),
        BoxShadow(
          color: AppPalette.primary.withValues(alpha: 0.10),
          blurRadius: 30,
          spreadRadius: -8,
        ),
      ],
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              avatarWidget,
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'XO ARENA ID',
            style: safeOrbitron(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
              color: AppPalette.goldHighlight,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: editingName
                ? Row(
                    key: const ValueKey('edit-name'),
                    children: [
                      Expanded(
                        child: TextField(
                          controller: usernameController,
                          maxLength: 20,
                          style: safeOrbitron(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor:
                                AppPalette.panelDeep.withValues(alpha: 0.90),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: AppPalette.strokeStrong
                                    .withValues(alpha: 0.60),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(14)),
                              borderSide: BorderSide(
                                color: AppPalette.goldHighlight
                                    .withValues(alpha: 0.92),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                          onPressed: onCancelEdit,
                          icon: const Icon(Icons.close, color: Colors.white70)),
                      IconButton(
                          onPressed: () => onSaveName(),
                          icon: const Icon(Icons.check,
                              color: AppPalette.primary)),
                    ],
                  )
                : Row(
                    key: const ValueKey('view-name'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: safeOrbitron(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color:
                                    AppPalette.primary.withValues(alpha: 0.26),
                                blurRadius: 18,
                              ),
                              Shadow(
                                color: AppPalette.accentPurple
                                    .withValues(alpha: 0.18),
                                blurRadius: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onEditName,
                        icon: const Icon(Icons.edit_rounded,
                            size: 16, color: AppPalette.primary),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 4),
          Text(email,
              style: safeInter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppPalette.textSubtle)),
          const SizedBox(height: 6),
          _ProviderBadge(provider: provider),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppPalette.panelSoft.withValues(alpha: 0.96),
                  AppPalette.panelDeep.withValues(alpha: 0.98),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppPalette.strokeSoft),
            ),
            child: Row(
              children: [
                Expanded(child: _StatChip(value: games, label: 'GAMES')),
                const _VerticalStatDivider(),
                Expanded(child: _StatChip(value: wins, label: 'WINS')),
                const _VerticalStatDivider(),
                Expanded(child: _StatChip(value: losses, label: 'LOSSES')),
                const _VerticalStatDivider(),
                Expanded(child: _StatChip(value: draws, label: 'DRAWS')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppPalette.primary2.withValues(alpha: 0.94),
                  AppPalette.accentPurple.withValues(alpha: 0.86),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppPalette.gold.withValues(alpha: 0.34),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.primary.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.military_tech,
                    color: AppPalette.goldHighlight, size: 20),
                const SizedBox(width: 8),
                Text(
                  'TOP LEVEL: ${topLevel} / 20',
                  style: safeOrbitron(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderBadge extends StatelessWidget {
  final String provider;

  const _ProviderBadge({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isGoogle = provider == 'google';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isGoogle
            ? AppPalette.success.withValues(alpha: 0.14)
            : AppPalette.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isGoogle
              ? AppPalette.success.withValues(alpha: 0.34)
              : AppPalette.gold.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isGoogle ? Icons.verified : Icons.email_outlined,
              size: 13,
              color: isGoogle ? AppPalette.success : AppPalette.goldHighlight),
          const SizedBox(width: 6),
          Text(
            isGoogle ? 'GOOGLE VERIFIED' : 'EMAIL',
            style: safeOrbitron(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isGoogle ? AppPalette.success : AppPalette.goldHighlight,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final int value;
  final String label;

  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: safeOrbitron(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: safeOrbitron(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: AppPalette.textSubtle),
        ),
      ],
    );
  }
}

class _VerticalStatDivider extends StatelessWidget {
  const _VerticalStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: AppPalette.strokeSoft,
    );
  }
}

class _DangerZoneCard extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _DangerZoneCard(
      {required this.expanded, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x08FF3B30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x30FF3B30)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppPalette.danger),
                  const SizedBox(width: 10),
                  Text(
                    'DANGER ZONE',
                    style: safeOrbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppPalette.danger),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 280),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: AppPalette.danger),
                  ),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            height: expanded ? 64 : 0,
            padding: EdgeInsets.fromLTRB(
                14, expanded ? 0 : 0, 14, expanded ? 12 : 0),
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                child: expanded
                    ? SizedBox(
                        width: double.infinity,
                        child: AppPillButton(
                          label: 'DELETE ACCOUNT',
                          fill: AppPalette.danger,
                          onPressed: onDelete,
                          icon: Icons.delete_forever,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumLogoutCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PremiumLogoutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppPalette.panelSoft.withValues(alpha: 0.98),
                AppPalette.panelDeep.withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(
              color: AppPalette.gold.withValues(alpha: 0.34),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppPalette.gold.withValues(alpha: 0.10),
                blurRadius: 20,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.gold.withValues(alpha: 0.12),
                  border: Border.all(
                      color: AppPalette.gold.withValues(alpha: 0.32)),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppPalette.goldHighlight,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SIGN OUT',
                    style: safeOrbitron(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: Colors.white),
                  ),
                  Text(
                    'You will need to sign in again',
                    style: safeInter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppPalette.textSubtle),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppPalette.primary,
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _TinyBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: safeOrbitron(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: color),
      ),
    );
  }
}

class _ModeHeroCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> chips;
  final Color accent;
  final Widget? trailing;

  const _ModeHeroCard({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.chips = const [],
    this.accent = AppPalette.primary,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      padding: const EdgeInsets.all(18),
      borderColor: accent.withValues(alpha: 0.34),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppPalette.panelElevated.withValues(alpha: 0.98),
          AppPalette.panelDeep.withValues(alpha: 0.98),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.30),
          blurRadius: 28,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: accent.withValues(alpha: 0.12),
          blurRadius: 24,
          spreadRadius: -8,
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = trailing != null && constraints.maxWidth < 430;
          final compact = constraints.maxWidth < 360;
          final textColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: safeOrbitron(
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: compact ? 2.0 : 2.4,
                  color: AppPalette.goldHighlight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: safeOrbitron(
                  fontSize: compact ? 20 : 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: bodyFont(context).copyWith(
                  color: AppPalette.textMuted,
                  height: 1.35,
                  fontSize: compact ? 12 : 13,
                ),
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips,
                ),
              ],
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                textColumn,
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: trailing,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: textColumn),
              if (trailing != null) ...[
                const SizedBox(width: 16),
                trailing!,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ModeInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ModeInfoChip({
    required this.icon,
    required this.label,
    this.color = AppPalette.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: safeOrbitron(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _SummaryMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppPalette.panelSoft.withValues(alpha: 0.95),
            AppPalette.panelDeep.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: safeOrbitron(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: AppPalette.textSubtle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: safeOrbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

///   GAME ENUMS
/// ==========================
enum PlayerSymbol { x, o }

enum GameMode { ai, friend, coinMatch, levelGame }

enum AIDifficulty { easy, medium, hard }

const List<int> kStandardBoardSizes = [3, 4, 5];

class MatchBoardConfig {
  final int boardSize;
  final int winLength;

  const MatchBoardConfig({
    required this.boardSize,
    required this.winLength,
  });

  int get cellCount => boardSize * boardSize;
  String get label => '$boardSize×$boardSize';
}

MatchBoardConfig standardBoardConfig(int boardSize) {
  switch (boardSize) {
    case 4:
      return const MatchBoardConfig(boardSize: 4, winLength: 4);
    case 5:
      return const MatchBoardConfig(boardSize: 5, winLength: 5);
    case 3:
    default:
      return const MatchBoardConfig(boardSize: 3, winLength: 3);
  }
}

List<List<int>> generateWinningLines({
  required int boardSize,
  required int winLength,
}) {
  final lines = <List<int>>[];
  for (int row = 0; row < boardSize; row++) {
    for (int col = 0; col <= boardSize - winLength; col++) {
      lines.add(List.generate(winLength, (i) => row * boardSize + col + i));
    }
  }
  for (int col = 0; col < boardSize; col++) {
    for (int row = 0; row <= boardSize - winLength; row++) {
      lines.add(
        List.generate(winLength, (i) => (row + i) * boardSize + col),
      );
    }
  }
  for (int row = 0; row <= boardSize - winLength; row++) {
    for (int col = 0; col <= boardSize - winLength; col++) {
      lines.add(
        List.generate(winLength, (i) => (row + i) * boardSize + col + i),
      );
      lines.add(
        List.generate(
          winLength,
          (i) => (row + i) * boardSize + col + winLength - 1 - i,
        ),
      );
    }
  }
  return lines;
}

List<int> preferredCenterIndices(int boardSize) {
  final midpoint = boardSize ~/ 2;
  if (boardSize.isOdd) {
    return [midpoint * boardSize + midpoint];
  }

  return [
    (midpoint - 1) * boardSize + (midpoint - 1),
    (midpoint - 1) * boardSize + midpoint,
    midpoint * boardSize + (midpoint - 1),
    midpoint * boardSize + midpoint,
  ];
}

List<int> cornerIndices(int boardSize) {
  final last = boardSize - 1;
  return [0, last, last * boardSize, last * boardSize + last];
}

List<int> perimeterEdgeIndices(int boardSize) {
  final last = boardSize - 1;
  final indices = <int>[];
  for (int col = 1; col < last; col++) {
    indices.add(col);
    indices.add(last * boardSize + col);
  }
  for (int row = 1; row < last; row++) {
    indices.add(row * boardSize);
    indices.add(row * boardSize + last);
  }
  return indices;
}

double matchBoardMaxExtent(int boardSize) {
  return boardSize >= 5
      ? 480.0
      : boardSize == 4
          ? 520.0
          : 560.0;
}

double matchBoardViewportSize(
  BuildContext context,
  int boardSize, {
  double? availableWidth,
  double? availableHeight,
}) {
  final screenWidth = availableWidth ?? MediaQuery.sizeOf(context).width;
  final widthFactor = boardSize >= 5
      ? 0.92
      : boardSize == 4
          ? 0.88
          : 0.82;
  var viewport = min(screenWidth * widthFactor, matchBoardMaxExtent(boardSize));
  if (availableHeight != null) {
    viewport = min(viewport, availableHeight);
  }
  return max(0.0, viewport);
}

double matchBoardViewportSizeForBounds({
  required int boardSize,
  required double maxWidth,
  required double maxHeight,
}) {
  return min(
    min(max(0.0, maxWidth), max(0.0, maxHeight)),
    matchBoardMaxExtent(boardSize),
  );
}

double matchBoardSpacing(int boardSize) {
  if (boardSize >= 5) return 6;
  if (boardSize == 4) return 8;
  return 10;
}

double matchBoardPadding(int boardSize) {
  if (boardSize >= 5) return 10;
  if (boardSize == 4) return 12;
  return 14;
}

double matchBoardCellRadius(int boardSize) {
  if (boardSize >= 5) return 14;
  if (boardSize == 4) return 16;
  return 18;
}

int aiThinkingDelayForDifficulty(
  AIDifficulty difficulty, {
  required int boardSize,
}) {
  final boardDelay = boardSize >= 5
      ? 24
      : boardSize == 4
          ? 12
          : 0;
  switch (difficulty) {
    case AIDifficulty.easy:
      return 95 + boardDelay;
    case AIDifficulty.medium:
      return 140 + boardDelay;
    case AIDifficulty.hard:
      return 175 + boardDelay;
  }
}

int countOpenThreatsForPlayer({
  required List<String> board,
  required List<List<int>> winningLines,
  required String player,
  required int winLength,
}) {
  var total = 0;
  for (final line in winningLines) {
    var playerCount = 0;
    var opponentCount = 0;
    var emptyCount = 0;
    for (final index in line) {
      final value = board[index];
      if (value == player) {
        playerCount++;
      } else if (value.isEmpty) {
        emptyCount++;
      } else {
        opponentCount++;
      }
    }

    if (opponentCount == 0 && playerCount == winLength - 1 && emptyCount == 1) {
      total++;
    }
  }
  return total;
}

int adjacentSupportCount({
  required List<String> board,
  required int moveIndex,
  required String player,
  required int boardSize,
}) {
  final row = moveIndex ~/ boardSize;
  final col = moveIndex % boardSize;
  var total = 0;

  for (int rowOffset = -1; rowOffset <= 1; rowOffset++) {
    for (int colOffset = -1; colOffset <= 1; colOffset++) {
      if (rowOffset == 0 && colOffset == 0) continue;
      final nextRow = row + rowOffset;
      final nextCol = col + colOffset;
      if (nextRow < 0 ||
          nextRow >= boardSize ||
          nextCol < 0 ||
          nextCol >= boardSize) {
        continue;
      }

      final nextIndex = nextRow * boardSize + nextCol;
      if (board[nextIndex] == player) {
        total++;
      }
    }
  }

  return total;
}

int adjacentOccupiedCount({
  required List<String> board,
  required int moveIndex,
  required int boardSize,
}) {
  final row = moveIndex ~/ boardSize;
  final col = moveIndex % boardSize;
  var total = 0;

  for (int rowOffset = -1; rowOffset <= 1; rowOffset++) {
    for (int colOffset = -1; colOffset <= 1; colOffset++) {
      if (rowOffset == 0 && colOffset == 0) continue;
      final nextRow = row + rowOffset;
      final nextCol = col + colOffset;
      if (nextRow < 0 ||
          nextRow >= boardSize ||
          nextCol < 0 ||
          nextCol >= boardSize) {
        continue;
      }

      final nextIndex = nextRow * boardSize + nextCol;
      if (board[nextIndex].isNotEmpty) {
        total++;
      }
    }
  }

  return total;
}

double boardControlScore({
  required int moveIndex,
  required int boardSize,
}) {
  final row = moveIndex ~/ boardSize;
  final col = moveIndex % boardSize;
  final midpoint = (boardSize - 1) / 2;
  final distance = (row - midpoint).abs() + (col - midpoint).abs();
  final maxDistance = midpoint * 2;
  final normalized = max(0.0, maxDistance - distance);
  return normalized * (boardSize >= 4 ? 5.0 : 4.0);
}

double candidateHeatForMove({
  required List<String> board,
  required List<List<int>> winningLines,
  required int moveIndex,
  required String aiPlayer,
  required String humanPlayer,
  required int boardSize,
}) {
  var heat = boardControlScore(moveIndex: moveIndex, boardSize: boardSize);
  heat += adjacentOccupiedCount(
        board: board,
        moveIndex: moveIndex,
        boardSize: boardSize,
      ) *
      10;

  for (final line in winningLines) {
    if (!line.contains(moveIndex)) {
      continue;
    }

    var aiCount = 0;
    var humanCount = 0;
    for (final index in line) {
      if (board[index] == aiPlayer) {
        aiCount++;
      } else if (board[index] == humanPlayer) {
        humanCount++;
      }
    }

    if (aiCount == 0 || humanCount == 0) {
      heat += 8;
    }
    if (aiCount > 0 && humanCount == 0) {
      heat += aiCount * 7;
    }
    if (humanCount > 0 && aiCount == 0) {
      heat += humanCount * 6;
    }
  }

  return heat;
}

List<int> rankedCandidateMoves({
  required List<String> board,
  required List<List<int>> winningLines,
  required String aiPlayer,
  required String humanPlayer,
  required int boardSize,
  required AIDifficulty difficulty,
}) {
  final empties = List.generate(board.length, (i) => i)
      .where((i) => board[i].isEmpty)
      .toList();
  final filledCount = board.length - empties.length;

  if (empties.length <= 7 || filledCount <= 1) {
    return empties;
  }

  final candidateLimit = switch (difficulty) {
    AIDifficulty.easy => boardSize >= 5
        ? 16
        : boardSize == 4
            ? 14
            : empties.length,
    AIDifficulty.medium => boardSize >= 5
        ? 14
        : boardSize == 4
            ? 12
            : empties.length,
    AIDifficulty.hard => boardSize >= 5
        ? 12
        : boardSize == 4
            ? 10
            : empties.length,
  };

  final heatedMoves = empties
      .map(
        (index) => MapEntry(
          index,
          candidateHeatForMove(
            board: board,
            winningLines: winningLines,
            moveIndex: index,
            aiPlayer: aiPlayer,
            humanPlayer: humanPlayer,
            boardSize: boardSize,
          ),
        ),
      )
      .toList()
    ..sort((left, right) => right.value.compareTo(left.value));

  return heatedMoves
      .take(min(candidateLimit, heatedMoves.length))
      .map((entry) => entry.key)
      .toList();
}

double evaluateHardLookahead({
  required List<String> board,
  required List<List<int>> winningLines,
  required int moveIndex,
  required String aiPlayer,
  required String humanPlayer,
  required int boardSize,
  required int winLength,
}) {
  board[moveIndex] = aiPlayer;

  final immediateHumanWin = findWinningMoveForBoard(
    board: board,
    winningLines: winningLines,
    player: humanPlayer,
    winLength: winLength,
  );
  if (immediateHumanWin != -1) {
    board[moveIndex] = '';
    return -260;
  }

  var adjustment = countOpenThreatsForPlayer(
        board: board,
        winningLines: winningLines,
        player: aiPlayer,
        winLength: winLength,
      ) *
      14.0;

  final replies = rankedCandidateMoves(
    board: board,
    winningLines: winningLines,
    aiPlayer: humanPlayer,
    humanPlayer: aiPlayer,
    boardSize: boardSize,
    difficulty: AIDifficulty.medium,
  );

  var worstReplyPressure = 0.0;
  final replyLimit = boardSize >= 5 ? 4 : 5;
  for (final reply in replies.take(replyLimit)) {
    board[reply] = humanPlayer;

    final humanThreats = countOpenThreatsForPlayer(
      board: board,
      winningLines: winningLines,
      player: humanPlayer,
      winLength: winLength,
    );
    final humanWinningReply = findWinningMoveForBoard(
      board: board,
      winningLines: winningLines,
      player: humanPlayer,
      winLength: winLength,
    );
    final aiCounterWin = findWinningMoveForBoard(
      board: board,
      winningLines: winningLines,
      player: aiPlayer,
      winLength: winLength,
    );

    var replyPressure = humanThreats * 52.0;
    if (humanWinningReply != -1) {
      replyPressure += 120.0;
    }
    if (aiCounterWin == -1 && humanThreats > 1) {
      replyPressure += 44.0;
    }

    worstReplyPressure = max(worstReplyPressure, replyPressure);
    board[reply] = '';
  }

  board[moveIndex] = '';
  adjustment -= worstReplyPressure;
  return adjustment;
}

double scoreStrategicMove({
  required List<String> board,
  required List<List<int>> winningLines,
  required int moveIndex,
  required String aiPlayer,
  required String humanPlayer,
  required int boardSize,
  required int winLength,
  required AIDifficulty difficulty,
}) {
  var score = 0.0;
  var openLineTouches = 0;
  final attackWeight = switch (difficulty) {
    AIDifficulty.easy => 5.5,
    AIDifficulty.medium => 7.0,
    AIDifficulty.hard => 8.5,
  };
  final defendWeight = switch (difficulty) {
    AIDifficulty.easy => 14.0,
    AIDifficulty.medium => 24.0,
    AIDifficulty.hard => 34.0,
  };

  for (final line in winningLines) {
    if (!line.contains(moveIndex)) {
      continue;
    }

    openLineTouches++;

    var projectedAiCount = 0;
    var projectedHumanCount = 0;
    var projectedEmptyCount = 0;
    var currentAiCount = 0;
    var currentHumanCount = 0;

    for (final index in line) {
      final projectedValue = index == moveIndex ? aiPlayer : board[index];
      if (projectedValue == aiPlayer) {
        projectedAiCount++;
      } else if (projectedValue == humanPlayer) {
        projectedHumanCount++;
      } else {
        projectedEmptyCount++;
      }

      final currentValue = board[index];
      if (currentValue == aiPlayer) {
        currentAiCount++;
      } else if (currentValue == humanPlayer) {
        currentHumanCount++;
      }
    }

    if (projectedHumanCount == 0) {
      score += projectedAiCount * projectedAiCount * attackWeight;
      if (currentAiCount > 0) {
        score += (currentAiCount + 1) * attackWeight;
      }
      if (projectedAiCount == winLength - 1 && projectedEmptyCount == 1) {
        score += switch (difficulty) {
          AIDifficulty.easy => 150,
          AIDifficulty.medium => 200,
          AIDifficulty.hard => 240,
        };
      } else if (projectedAiCount == winLength - 2 &&
          projectedEmptyCount == 2) {
        score += switch (difficulty) {
          AIDifficulty.easy => 34,
          AIDifficulty.medium => 60,
          AIDifficulty.hard => 84,
        };
      } else if (projectedAiCount == 1) {
        score += difficulty == AIDifficulty.easy ? 4 : 6;
      }
    }

    if (currentAiCount == 0 && currentHumanCount > 0) {
      score += currentHumanCount * defendWeight;
      if (currentHumanCount == winLength - 1) {
        score += switch (difficulty) {
          AIDifficulty.easy => 150,
          AIDifficulty.medium => 260,
          AIDifficulty.hard => 320,
        };
      } else if (currentHumanCount == winLength - 2) {
        score += switch (difficulty) {
          AIDifficulty.easy => 42,
          AIDifficulty.medium => 88,
          AIDifficulty.hard => 132,
        };
      }
    }
  }

  score += openLineTouches *
      switch (difficulty) {
        AIDifficulty.easy => 1.5,
        AIDifficulty.medium => 3.0,
        AIDifficulty.hard => 4.5,
      };

  if (preferredCenterIndices(boardSize).contains(moveIndex)) {
    score += boardSize.isOdd ? 22 : 18;
  }
  if (cornerIndices(boardSize).contains(moveIndex)) {
    score += difficulty == AIDifficulty.easy ? 8 : 10;
  }
  if (perimeterEdgeIndices(boardSize).contains(moveIndex)) {
    score += boardSize >= 4 ? 4 : 5;
  }

  score += boardControlScore(moveIndex: moveIndex, boardSize: boardSize);

  score += adjacentSupportCount(
        board: board,
        moveIndex: moveIndex,
        player: aiPlayer,
        boardSize: boardSize,
      ) *
      switch (difficulty) {
        AIDifficulty.easy => 3,
        AIDifficulty.medium => 5,
        AIDifficulty.hard => 7,
      };

  score += adjacentOccupiedCount(
        board: board,
        moveIndex: moveIndex,
        boardSize: boardSize,
      ) *
      switch (difficulty) {
        AIDifficulty.easy => 1.5,
        AIDifficulty.medium => 2.5,
        AIDifficulty.hard => 4.0,
      };

  board[moveIndex] = aiPlayer;
  final aiThreats = countOpenThreatsForPlayer(
    board: board,
    winningLines: winningLines,
    player: aiPlayer,
    winLength: winLength,
  );
  final humanThreats = countOpenThreatsForPlayer(
    board: board,
    winningLines: winningLines,
    player: humanPlayer,
    winLength: winLength,
  );

  score += aiThreats *
      switch (difficulty) {
        AIDifficulty.easy => 16,
        AIDifficulty.medium => 26,
        AIDifficulty.hard => 38,
      };
  score -= humanThreats *
      switch (difficulty) {
        AIDifficulty.easy => 10,
        AIDifficulty.medium => 26,
        AIDifficulty.hard => 40,
      };

  final opponentReply = findWinningMoveForBoard(
    board: board,
    winningLines: winningLines,
    player: humanPlayer,
    winLength: winLength,
  );
  board[moveIndex] = "";

  if (opponentReply != -1) {
    if (difficulty == AIDifficulty.hard) {
      score -= 210;
    } else if (difficulty == AIDifficulty.medium) {
      score -= 120;
    } else {
      score -= 50;
    }
  }

  return score;
}

int findWinningMoveForBoard({
  required List<String> board,
  required List<List<int>> winningLines,
  required String player,
  required int winLength,
}) {
  for (final line in winningLines) {
    var playerCount = 0;
    var emptyIndex = -1;
    var blocked = false;

    for (final index in line) {
      final value = board[index];
      if (value == player) {
        playerCount++;
      } else if (value.isEmpty) {
        emptyIndex = index;
      } else {
        blocked = true;
        break;
      }
    }

    if (!blocked && playerCount == winLength - 1 && emptyIndex != -1) {
      return emptyIndex;
    }
  }
  return -1;
}

int pickStrategicMove({
  required List<String> board,
  required List<List<int>> winningLines,
  required String aiPlayer,
  required String humanPlayer,
  required int boardSize,
  required int winLength,
  required AIDifficulty difficulty,
}) {
  final empties = List.generate(board.length, (i) => i)
      .where((i) => board[i].isEmpty)
      .toList();
  if (empties.isEmpty) return -1;

  final candidateMoves = rankedCandidateMoves(
    board: board,
    winningLines: winningLines,
    aiPlayer: aiPlayer,
    humanPlayer: humanPlayer,
    boardSize: boardSize,
    difficulty: difficulty,
  );

  final win = findWinningMoveForBoard(
    board: board,
    winningLines: winningLines,
    player: aiPlayer,
    winLength: winLength,
  );
  if (win != -1) return win;

  final block = findWinningMoveForBoard(
    board: board,
    winningLines: winningLines,
    player: humanPlayer,
    winLength: winLength,
  );

  switch (difficulty) {
    case AIDifficulty.easy:
      if (block != -1 && _rng.nextDouble() < 0.28) {
        return block;
      }
      if (_rng.nextDouble() < (boardSize >= 4 ? 0.62 : 0.52)) {
        return empties[_rng.nextInt(empties.length)];
      }
      break;
    case AIDifficulty.medium:
      if (block != -1) {
        return block;
      }
      break;
    case AIDifficulty.hard:
      if (block != -1) {
        return block;
      }
      break;
  }

  final scoredMoves = candidateMoves
      .map(
        (index) => MapEntry(
          index,
          scoreStrategicMove(
            board: board,
            winningLines: winningLines,
            moveIndex: index,
            aiPlayer: aiPlayer,
            humanPlayer: humanPlayer,
            boardSize: boardSize,
            winLength: winLength,
            difficulty: difficulty,
          ),
        ),
      )
      .toList()
    ..sort((left, right) => right.value.compareTo(left.value));

  if (scoredMoves.isEmpty) {
    return empties[_rng.nextInt(empties.length)];
  }

  switch (difficulty) {
    case AIDifficulty.easy:
      final choices = scoredMoves.take(min(5, scoredMoves.length)).toList();
      return choices[_rng.nextInt(choices.length)].key;
    case AIDifficulty.medium:
      final choices = scoredMoves.take(min(4, scoredMoves.length)).toList();
      if (_rng.nextDouble() < 0.22) {
        return choices[_rng.nextInt(choices.length)].key;
      }
      return choices.first.key;
    case AIDifficulty.hard:
      final finalists = scoredMoves.take(min(4, scoredMoves.length)).map((entry) {
        final lookaheadScore = evaluateHardLookahead(
          board: board,
          winningLines: winningLines,
          moveIndex: entry.key,
          aiPlayer: aiPlayer,
          humanPlayer: humanPlayer,
          boardSize: boardSize,
          winLength: winLength,
        );
        return MapEntry(entry.key, entry.value + lookaheadScore);
      }).toList()
        ..sort((left, right) => right.value.compareTo(left.value));

      final bestScore = finalists.first.value;
      final stableChoices = finalists
          .where((entry) => entry.value >= bestScore - 3)
          .toList();
      return stableChoices.first.key;
  }
}

/// ==========================
///   NAVIGATION HELPER
/// ==========================
void navigateToHomeHub(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomeHub()),
    (route) => false,
  );
}

/// Show sign-in required dialog for guests trying to make purchases.
void showSignInRequiredDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: AppGlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: AppPalette.warning),
            const SizedBox(height: 16),
            Text(
              'Sign in required',
              style: titleFont(context).copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Sign in to earn coins and buy themes. You'll also get a 200 coins welcome gift.",
              style: bodyFont(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppPillButton(
                    label: 'Not now',
                    fill: Colors.white.withOpacity(0.08),
                    stroke: AppPalette.strokeStrong,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppPillButton(
                    label: 'Sign in',
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Route<void> _buildStartupPageRoute(String routeName) {
  Widget page;
  switch (routeName) {
    case '/home':
      page = const HomeHub();
      break;
    case '/login':
      page = const LoginScreen();
      break;
    default:
      if (kDebugMode) {
        debugPrint('[startup] Unknown route "$routeName", defaulting to /login');
      }
      routeName = '/login';
      page = const LoginScreen();
      break;
  }

  return PageRouteBuilder<void>(
    settings: RouteSettings(name: routeName),
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 260),
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
class NewYorkXOApp extends StatelessWidget {
  const NewYorkXOApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'XO Arena',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppPalette.homeBgBase,
        fontFamily: 'Rajdhani',
      ),
      routes: {
        '/home': (context) => const HomeHub(),
        '/login': (context) => const LoginScreen(),
      },
      home: const _AppEntry(),
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
    _startupRouteFuture = _getStartupRouteFuture();
  }

  @override
  Widget build(BuildContext context) {
    return IntroScreen(
      startupRouteFuture: _startupRouteFuture,
      startupRouteBuilder: _buildStartupPageRoute,
    );
  }
}

class HomeHub extends StatefulWidget {
  const HomeHub({super.key});

  @override
  State<HomeHub> createState() => _HomeHubState();
}

class _HomeHubState extends State<HomeHub>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _offline = false;
  bool _isForceLoggingOut = false;
  bool _isReconnecting = false;
  bool _isDisconnecting = false;
  int _currentTab = 0;
  StreamSubscription? _sessionSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _firestoreSub;

  // Staggered card entrance animation
  late final AnimationController _cardAnim;
  late final List<Animation<double>> _cardFades;
  late final List<Animation<Offset>> _cardSlides;

  bool get _isGuest => FirebaseAuth.instance.currentUser == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuditService.log('app_open');
    _refresh();
    _startFirestoreListener();
    _initIap();
    _startSessionListener();
    ConnectivityService().isOnline.addListener(_onConnectivityChanged);
    ConnectivityService().online.then((online) {
      if (mounted) setState(() => _offline = !online);
    });

    // Staggered entrance: smooth 600ms sequence
    const starts = <double>[0.0, 0.3];
    const ends = <double>[0.6, 1.0];
    _cardAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _cardFades = List.generate(2, (i) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _cardAnim,
            curve: Interval(starts[i], ends[i], curve: Curves.easeOutCubic)),
      );
    });
    _cardSlides = List.generate(2, (i) {
      return Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
          .animate(
        CurvedAnimation(
            parent: _cardAnim,
            curve: Interval(starts[i], ends[i], curve: Curves.easeOutCubic)),
      );
    });
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _cardAnim.forward();
    });
  }

  /// Initialize IAP service early to catch pending purchases from interrupted sessions.
  Future<void> _initIap() async {
    if (_isGuest) return; // Guests can't purchase
    try {
      await IapCoinsService().init();
      await IapCoinsService().clearExistingPurchases();
      if (mounted) {
        _refresh(); // Refresh coins if any pending purchases were granted
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HomeHub] IAP init error (non-fatal): $e');
      }
    }
  }

  void _onConnectivityChanged() {
    final wasOffline = _offline;
    final nowOnline = ConnectivityService().isOnline.value;
    if (mounted) setState(() => _offline = !nowOnline);
    if (wasOffline && nowOnline) {
      _handleReconnection();
    } else if (!wasOffline && !nowOnline) {
      _handleDisconnection();
    }
  }

  /// Handle internet loss — authenticated users keep real balance,
  /// only true guests (no Firebase account) get 999999 coins.
  Future<void> _handleDisconnection() async {
    if (_isDisconnecting) return;
    if (mounted) setState(() => _isDisconnecting = true);

    // Cancel online listeners
    _sessionSub?.cancel();
    _sessionSub = null;
    _firestoreSub?.cancel();
    _firestoreSub = null;

    final p = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // AUTHENTICATED: save current coins so we can compute offline delta later
      final currentCoins = p.getInt(Keys.coins) ?? 0;
      await p.setInt(Keys.preDisconnectCoins, currentCoins);
      // Keep real balance — Firestore persistence queues offline writes
    } else {
      // TRUE GUEST (no account): give unlimited coins
      await p.setBool(Keys.offlineGuest, true);
      await p.setInt(Keys.coins, 999999);
      LocalStore.coinsNotifier.value = 999999;
    }

    // Brief delay so overlay is visible
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        _isDisconnecting = false;
      });
    }
  }

  /// Smart reconnection: wait for Firestore to flush pending writes,
  /// then pull server data and apply any offline coin delta.
  Future<void> _handleReconnection() async {
    if (_isReconnecting) return;
    if (mounted) setState(() => _isReconnecting = true);

    final user = FirebaseAuth.instance.currentUser;
    final p = await SharedPreferences.getInstance();

    if (user != null) {
      // AUTHENTICATED: smart sync
      final localCoins = p.getInt(Keys.coins) ?? 0;
      final preDisconnect = p.getInt(Keys.preDisconnectCoins) ?? localCoins;
      final offlineDelta = localCoins - preDisconnect;

      // Wait 3 seconds for Firestore to flush queued offline writes
      await Future.delayed(const Duration(seconds: 3));

      // Pull authoritative server data
      try {
        await UserRepo().pullServerToLocal(user.uid);
      } catch (e) {
        if (kDebugMode) debugPrint('[RECONNECT] pullServerToLocal failed: $e');
      }

      // If user earned coins offline (real play, not 999999 guest),
      // apply the delta on top of the server state
      if (offlineDelta > 0) {
        if (kDebugMode) {
          debugPrint(
              '[RECONNECT] Applying offline delta: +$offlineDelta coins');
        }
        await LocalStore.updateCoins(offlineDelta);
      }

      // Clean up
      await p.remove(Keys.preDisconnectCoins);
      _startFirestoreListener();
      _startSessionListener();
      await p.setBool(Keys.offlineGuest, false);
    } else if (p.getBool(Keys.offlineGuest) == true) {
      // TRUE GUEST: just clear flag, don't merge 999999
      await p.setBool(Keys.offlineGuest, false);
    }

    if (mounted) {
      setState(() {
        _isReconnecting = false;
      });
      _refresh();
    }
  }

  /// Real-time Firestore listener — Single Source of Truth for user data.
  /// Keeps coins, username, and stats in sync across devices and after
  /// Cloud Function updates (verifyGooglePlayPurchase).
  void _startFirestoreListener() {
    if (_isGuest) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _firestoreSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
      (snap) async {
        if (!mounted) return;
        final data = snap.data();
        if (data == null) return;
        // Guard: if user signed out while snapshot was in flight
        if (FirebaseAuth.instance.currentUser == null) return;

        // Extract authoritative server data
        final wallet = data['Wallet'] as Map<String, dynamic>?;
        final profile = data['Profile'] as Map<String, dynamic>?;
        final stats = data['Stats'] as Map<String, dynamic>?;
        final cosmetics = data['Cosmetics'] as Map<String, dynamic>?;
        final progress = data['Progress'] as Map<String, dynamic>?;

        final serverCoins = (wallet?['coins'] as num?)?.toInt() ?? 0;
        final serverName = (profile?['name'] as String?) ?? 'PLAYER';

        // Update UI immediately + broadcast to other screens
        LocalStore.coinsNotifier.value = serverCoins;

        // Write-through to SharedPreferences cache (keeps other screens in sync)
        try {
          final p = await SharedPreferences.getInstance();
          await p.setInt(Keys.coins, serverCoins);
          await p.setString(Keys.username, serverName);

          // Sync stats
          if (stats != null) {
            await p.setInt(
                Keys.gamesPlayed,
                (stats['gamesPlayed'] as num?)?.toInt() ??
                    p.getInt(Keys.gamesPlayed) ??
                    0);
            await p.setInt(Keys.wins,
                (stats['wins'] as num?)?.toInt() ?? p.getInt(Keys.wins) ?? 0);
            await p.setInt(
                Keys.losses,
                (stats['losses'] as num?)?.toInt() ??
                    p.getInt(Keys.losses) ??
                    0);
            await p.setInt(Keys.draws,
                (stats['draws'] as num?)?.toInt() ?? p.getInt(Keys.draws) ?? 0);
          }

          // Sync cosmetics
          if (cosmetics != null) {
            final xColor = cosmetics['xColor'] as String?;
            final oColor = cosmetics['oColor'] as String?;
            final equippedAvatar =
                (cosmetics['equippedAvatar'] as num?)?.toInt();
            if (xColor != null) await p.setString(Keys.xColor, xColor);
            if (oColor != null) await p.setString(Keys.oColor, oColor);
            if (equippedAvatar != null) {
              await p.setInt(Keys.equippedAvatar, equippedAvatar);
              LocalStore.equippedAvatarNotifier.value = equippedAvatar;
            }

            final ownedX = cosmetics['ownedXColors'];
            final ownedO = cosmetics['ownedOColors'];
            final ownedAvatars = cosmetics['ownedAvatars'];
            final customXConf = cosmetics['customXConfigsV2'];
            final customOConf = cosmetics['customOConfigsV2'];

            if (ownedX is List) {
              await p.setString(
                  Keys.ownedXColors, ownedX.map((e) => e.toString()).join(','));
            }
            if (ownedO is List) {
              await p.setString(
                  Keys.ownedOColors, ownedO.map((e) => e.toString()).join(','));
            }
            if (ownedAvatars is List) {
              await p.setString(Keys.ownedAvatars,
                  ownedAvatars.map((e) => e.toString()).join(','));
            }
            if (customXConf is String) {
              await p.setString(Keys.customXConfigs, customXConf);
            }
            if (customOConf is String) {
              await p.setString(Keys.customOConfigs, customOConf);
            }
          }

          // Sync progress
          if (progress != null) {
            final level = (progress['levelGameCurrentLevel'] as num?)?.toInt();
            final completed = progress['levelGameCompleted'] as bool?;
            if (level != null)
              await p.setInt(Keys.levelGameCurrentLevel, level);
            if (completed != null)
              await p.setBool(Keys.levelGameCompleted, completed);
          }

          // Sync profile photo URL
          final profilePhotoUrl = (profile?['photoURL'] as String?) ??
              FirebaseAuth.instance.currentUser?.photoURL;
          if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
            await LocalStore.setProfilePhotoUrl(profilePhotoUrl);
          }
        } catch (e) {
          if (kDebugMode)
            debugPrint('[HomeHub] SharedPreferences write-through error: $e');
        }
      },
      onError: (e) {
        if (kDebugMode) debugPrint('[HomeHub] Firestore listener error: $e');
        // Fall back to local cache
        _refresh();
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionSub?.cancel();
    _firestoreSub?.cancel();
    ConnectivityService().isOnline.removeListener(_onConnectivityChanged);
    _cardAnim.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AuditService.log('app_resumed');
    } else if (state == AppLifecycleState.paused) {
      AuditService.log('app_paused');
    }
  }

  /// Start listening for session conflicts (single-device enforcement).
  Future<void> _startSessionListener() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Guest — no session to enforce

    final sessionId = await SessionService.getLocalSessionId();
    if (sessionId == null) return; // No session written yet

    _sessionSub = SessionService.listenForConflict(
      uid: user.uid,
      sessionId: sessionId,
      onConflict: (newDevice, loginTime) async {
        // Prevent stacked dialogs from rapid session changes
        if (_isForceLoggingOut) return;
        _isForceLoggingOut = true;

        // Stop all listeners immediately
        _sessionSub?.cancel();
        _sessionSub = null;
        _firestoreSub?.cancel();
        _firestoreSub = null;

        await SessionService.clearLocal();
        try {
          await AuthService().signOut();
        } catch (e) {
          if (kDebugMode)
            debugPrint('[SESSION] signOut during conflict failed: $e');
        }
        if (mounted) _showForceLogoutDialog(newDevice, loginTime);
      },
    );
  }

  /// Show a non-dismissible, glassmorphism force-logout dialog.
  void _showForceLogoutDialog(String device, DateTime time) {
    final formattedTime = DateFormat('hh:mm a').format(time);
    final formattedDate = DateFormat('MMMM d, yyyy').format(time);

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Force Logout',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, a1, a2, child) {
        return FadeTransition(
          opacity: a1,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: a1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, _, __) {
        return PopScope(
          canPop: false, // Block back button
          child: Center(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Material(
                    color: Colors.transparent,
                    child: AppGlassCard(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Glowing shield icon
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppPalette.danger.withOpacity(0.4),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.shield_outlined,
                              size: 52,
                              color: AppPalette.danger,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "SESSION TERMINATED",
                            textAlign: TextAlign.center,
                            style: safeOrbitron(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Your account was accessed from another device. To protect your data, you have been logged out.",
                            textAlign: TextAlign.center,
                            style: safeInter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppPalette.textMuted,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Device details card
                          AppGlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _sessionDetailRow(
                                  icon: Icons.phone_android,
                                  label: "Device",
                                  value: device,
                                ),
                                const SizedBox(height: 10),
                                _sessionDetailRow(
                                  icon: Icons.access_time,
                                  label: "Time",
                                  value: formattedTime,
                                ),
                                const SizedBox(height: 10),
                                _sessionDetailRow(
                                  icon: Icons.calendar_today,
                                  label: "Date",
                                  value: formattedDate,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          AppPillButton(
                            label: "BACK TO LOGIN",
                            icon: Icons.login,
                            fill: AppPalette.primary.withOpacity(0.9),
                            onPressed: () {
                              Navigator.of(ctx).pushNamedAndRemoveUntil(
                                '/login',
                                (_) => false,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sessionDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppPalette.primary),
        const SizedBox(width: 10),
        Text(
          "$label: ",
          style: safeInter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppPalette.textMuted,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: safeInter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _refresh() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {});
    // Keep profile photo URL notifier in sync after login/navigation.
    LocalStore.profilePhotoUrlNotifier.value =
        p.getString(Keys.profilePhotoUrl);
  }

  Future<void> _openHomeCoinsStore() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const StorePage(initialTab: 2),
      ),
    );
    await _refresh();
  }

  Future<void> _handleHomeProfileTap() async {
    if (_isGuest) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
      await _refresh();
      return;
    }

    if (_currentTab != 3) {
      setState(() => _currentTab = 3);
    }
  }

  Widget _buildHomeCoinButton({
    required bool compact,
    required bool landscape,
    required double iconSize,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _openHomeCoinsStore,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 6,
            vertical: landscape ? (compact ? 3 : 4) : (compact ? 4 : 6),
          ),
          child: ValueListenableBuilder<int>(
            valueListenable: LocalStore.coinsNotifier,
            builder: (_, coins, __) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/coin/COIN-SHOP.png',
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: compact ? 6 : 8),
                    Text(
                      NumberFormat.decimalPattern().format(coins),
                      style: homeOrbitron(
                        fontSize: landscape ? 18 : (compact ? 18 : 22),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: AppPalette.homeTitle,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHomeAvatarButton({
    required double size,
    required bool compact,
  }) {
    final framePadding = compact ? 2.0 : 4.0;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(size / 2 + framePadding),
      child: InkWell(
        borderRadius: BorderRadius.circular(size / 2 + framePadding),
        onTap: _handleHomeProfileTap,
        child: Padding(
          padding: EdgeInsets.all(framePadding),
          child: ValueListenableBuilder<int>(
            valueListenable: LocalStore.equippedAvatarNotifier,
            builder: (_, avatarId, ___) {
              final avatar = gameAvatarById(avatarId);
              return FullAvatarDisplay(
                size: size,
                avatar: avatar,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final landscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          final compact = width < 360;
          final minSideWidth = 86.0;
          final maxSideWidth = landscape ? 140.0 : 154.0;
          final desiredSideWidth = width * (landscape ? 0.22 : 0.24);
          final sideSlotWidth = min(
            max(minSideWidth, desiredSideWidth),
            min(maxSideWidth, max(minSideWidth, (width - 120.0) / 2)),
          );
          final centerWidth = max(120.0, width - sideSlotWidth * 2);
          final topBarHeight = landscape ? 68.0 : (compact ? 78.0 : 90.0);
          final avatarSize = landscape ? 48.0 : (compact ? 50.0 : 60.0);
          final coinIconSize = landscape ? 26.0 : (compact ? 28.0 : 34.0);

          return SizedBox(
            height: topBarHeight,
            child: Row(
              children: [
                SizedBox(
                  width: sideSlotWidth,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildHomeCoinButton(
                      compact: compact,
                      landscape: landscape,
                      iconSize: coinIconSize,
                    ),
                  ),
                ),
                SizedBox(
                  width: centerWidth,
                  child: Center(
                    child: IgnorePointer(
                      child: _buildHomeIdentityPanel(
                        compact: compact,
                        landscape: landscape,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: sideSlotWidth,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildHomeAvatarButton(
                      size: avatarSize,
                      compact: compact,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeIdentityPanel({
    bool compact = false,
    bool landscape = false,
  }) {
    final xoSize = landscape ? 28.0 : (compact ? 34.0 : 40.0);
    final arenaSize = landscape ? 14.0 : (compact ? 16.0 : 18.0);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'XO',
            textAlign: TextAlign.center,
            style: homeOrbitron(
              fontSize: xoSize,
              fontWeight: FontWeight.w900,
              letterSpacing: landscape ? 1.8 : 2.4,
              color: AppPalette.homeTitle,
            ),
          ),
          SizedBox(height: compact ? 1 : 3),
          Text(
            'ARENA',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: brandFont(
              context,
              fontSize: arenaSize,
            ).copyWith(
              letterSpacing: landscape ? 2.2 : 3.0,
              color: AppPalette.homeSky,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeSectionHeader() {
    final counterTile = AppGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: AppPalette.homePanel.withOpacity(0.86),
      borderColor: AppPalette.homeStroke.withOpacity(0.30),
      radius: 22,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.24),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '4',
            style: homeOrbitron(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: AppPalette.homeTitle,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'MODES',
            style: homeLabelFont(
              context,
              fontSize: 8,
              color: AppPalette.homeSky,
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 470;
        final compact = constraints.maxWidth < 360;
        final textColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SELECT MODE',
              style: homeLabelFont(
                context,
                color: AppPalette.homeCyan,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose your arena',
              style: homeTitleFont(
                context,
                fontSize: compact ? 22 : 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Four ways to play across solo, local, coin, and level runs.',
              style: homeBodyFont(
                context,
                fontSize: compact ? 11 : 12,
                color: AppPalette.homeMuted,
              ),
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    textColumn,
                    const SizedBox(height: 12),
                    counterTile,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: textColumn),
                    const SizedBox(width: 12),
                    counterTile,
                  ],
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.homeBgBase,
      body: Stack(
        children: [
          SafeArea(
            child: AppBackground(
              variant: AppBackgroundVariant.homeNeon,
              child: Column(
                children: [
                  if (_currentTab == 0) _buildHomeTopBar(),
                  Expanded(
                    child: IndexedStack(
                      index: _currentTab,
                      children: [
                        _buildHomeContent(),
                        const StorePage(embedded: true),
                        const VaultPage(embedded: true),
                        const SettingsPage(embedded: true),
                      ],
                    ),
                  ),
                  _buildBottomNav(),
                ],
              ),
            ),
          ),
          if (_isReconnecting || _isDisconnecting)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(0.45),
                  child: Center(
                    child: AppGlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      backgroundColor:
                          AppPalette.homePanelStrong.withOpacity(0.96),
                      borderColor: AppPalette.homeStroke.withOpacity(0.40),
                      radius: 22,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.30),
                          blurRadius: 22,
                          offset: const Offset(0, 14),
                        ),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isReconnecting
                                ? 'Reconnecting...'
                                : 'Switching to offline mode...',
                            style: homeBodyFont(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    final modes = <_HomeModeConfig>[
      _HomeModeConfig(
        title: 'VS AI',
        subtitle: 'Train, challenge, dominate',
        badge: 'AI',
        assetPath: 'assets/game/ai.gif',
        accent: AppPalette.homeCyan,
        accentSecondary: AppPalette.homeBlue,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SetupPage()),
          );
          _refresh();
        },
      ),
      _HomeModeConfig(
        title: 'VS FRIEND',
        subtitle: '1v1 on one device',
        badge: 'HOT',
        assetPath: 'assets/game/friend.gif',
        accent: AppPalette.homePurple,
        accentSecondary: AppPalette.homePink,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const FriendSetupPage(),
            ),
          );
          _refresh();
        },
      ),
      _HomeModeConfig(
        title: 'COIN BATTLE',
        subtitle: 'Risk coins, win bigger',
        badge: 'RISK',
        assetPath: 'assets/game/coin-ai.gif',
        accent: AppPalette.homeGold,
        accentSecondary: AppPalette.homePink,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CoinMatchSetupPage()),
          );
          _refresh();
        },
      ),
      _HomeModeConfig(
        title: 'LEVELS',
        subtitle: 'Beat stages, unlock rewards',
        badge: 'REWARD',
        assetPath: 'assets/game/levels.gif',
        accent: AppPalette.homeSky,
        accentSecondary: AppPalette.homeBlue,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LevelGameSetupPage()),
          );
          _refresh();
        },
      ),
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                MediaQuery.orientationOf(context) == Orientation.landscape
                    ? 880
                    : 720,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final columns = constraints.maxWidth >= 420 ? 2 : 1;
              final childAspectRatio = columns == 2
                  ? (constraints.maxWidth < 520 ? 0.98 : 0.92)
                  : (constraints.maxWidth > 460
                      ? 1.65
                      : (compact ? 1.12 : 1.26));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHomeSectionHeader(),
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.only(bottom: compact ? 4 : 8),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 18,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: modes.length,
                      itemBuilder: (context, index) {
                        final mode = modes[index];
                        final animationIndex = min(index ~/ 2, 1);
                        return RepaintBoundary(
                          child: FadeTransition(
                            opacity: _cardFades[animationIndex],
                            child: SlideTransition(
                              position: _cardSlides[animationIndex],
                              child: _BigModeCard(
                                title: mode.title,
                                subtitle: mode.subtitle,
                                badge: mode.badge,
                                assetPath: mode.assetPath,
                                accent: mode.accent,
                                accentSecondary: mode.accentSecondary,
                                onTap: mode.onTap,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    const tabs = <_NavTabData>[
      _NavTabData(
          icon: Icons.home_outlined, activeIcon: Icons.home, label: 'HOME'),
      _NavTabData(
          icon: Icons.storefront_outlined,
          activeIcon: Icons.storefront,
          label: 'STORE'),
      _NavTabData(
          icon: Icons.backpack_outlined,
          activeIcon: Icons.backpack,
          label: 'LOADOUT'),
      _NavTabData(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings,
          label: 'SETTINGS'),
    ];

    final screenWidth = MediaQuery.sizeOf(context).width;
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final compact = screenWidth < 360;
    final navHeight = landscape ? 66.0 : (compact ? 72.0 : 78.0);
    final outerPadding = EdgeInsets.fromLTRB(
      landscape ? 12 : 16,
      8,
      landscape ? 12 : 16,
      landscape ? 12 : 16,
    );
    final itemMargin = EdgeInsets.symmetric(horizontal: landscape ? 2 : 4);
    final itemRadius = landscape ? 18.0 : 20.0;
    final iconSize = landscape ? 20.0 : (compact ? 21.0 : 22.0);
    final labelSize = landscape ? 7.4 : (compact ? 7.8 : 8.5);

    return Padding(
      padding: outerPadding,
      child: Container(
        height: navHeight,
        padding: EdgeInsets.all(landscape ? 4 : (compact ? 5 : 6)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppPalette.homePanelStrong.withOpacity(0.98),
              AppPalette.homeBgSecondary.withOpacity(0.96),
            ],
          ),
          borderRadius: BorderRadius.circular(landscape ? 24 : 28),
          border: Border.all(
            color: AppPalette.homeStroke.withOpacity(0.28),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.34),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: AppPalette.homeCyan.withOpacity(0.06),
              blurRadius: 18,
              spreadRadius: -6,
            ),
          ],
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final tab = tabs[i];
            final isActive = _currentTab == i;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_currentTab != i) setState(() => _currentTab = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                    margin: itemMargin,
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppPalette.homeSky.withOpacity(0.96),
                              AppPalette.homeBlue.withOpacity(0.88),
                            ],
                          )
                        : null,
                    color: isActive ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(itemRadius),
                    border: Border.all(
                      color: isActive
                          ? AppPalette.homeStrokeStrong.withOpacity(0.70)
                          : Colors.transparent,
                      width: 1.1,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppPalette.homeSky.withOpacity(0.20),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: AppPalette.homePurple.withOpacity(0.08),
                              blurRadius: 14,
                              spreadRadius: -2,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? tab.activeIcon : tab.icon,
                        size: iconSize,
                        color: isActive
                            ? AppPalette.homeTitle
                            : AppPalette.homeMuted,
                      ),
                      SizedBox(height: landscape ? 2 : 4),
                      Text(
                        tab.label,
                        style: homeLabelFont(
                          context,
                          fontSize: labelSize,
                          color: isActive
                              ? AppPalette.homeTitle
                              : AppPalette.homeMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavTabData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavTabData(
      {required this.icon, required this.activeIcon, required this.label});
}

class _HomeModeConfig {
  final String title;
  final String subtitle;
  final String badge;
  final String assetPath;
  final Color accent;
  final Color accentSecondary;
  final VoidCallback onTap;

  const _HomeModeConfig({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.assetPath,
    required this.accent,
    required this.accentSecondary,
    required this.onTap,
  });
}

class _BigModeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String badge;
  final String assetPath;
  final Color accent;
  final Color accentSecondary;
  final VoidCallback onTap;

  const _BigModeCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.assetPath,
    required this.accent,
    required this.accentSecondary,
    required this.onTap,
  });

  @override
  State<_BigModeCard> createState() => _BigModeCardState();
}

class _BigModeCardState extends State<_BigModeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final glowColor = Color.lerp(widget.accent, widget.accentSecondary, 0.5)!;

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(AppPalette.homeSurface, widget.accent, 0.10)!,
              Color.lerp(
                  AppPalette.homeSurface2, widget.accentSecondary, 0.14)!,
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: widget.accent.withOpacity(_pressed ? 0.62 : 0.36),
            width: _pressed ? 1.4 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.34),
              blurRadius: 24,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: glowColor.withOpacity(_pressed ? 0.18 : 0.12),
              blurRadius: _pressed ? 28 : 22,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            splashColor: widget.accent.withOpacity(0.08),
            highlightColor: widget.accent.withOpacity(0.04),
            onHighlightChanged: (pressed) {
              if (_pressed != pressed) {
                setState(() => _pressed = pressed);
              }
            },
            onTap: widget.onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth < 220 || constraints.maxHeight < 250;

                  return Stack(
                    children: [
                      Positioned(
                        top: -36,
                        right: -18,
                        child: _CardAura(
                          color: widget.accent,
                          size: compact ? 116 : 140,
                        ),
                      ),
                      Positioned(
                        bottom: -52,
                        left: -28,
                        child: _CardAura(
                          color: widget.accentSecondary,
                          size: compact ? 126 : 150,
                          opacity: _pressed ? 0.18 : 0.12,
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(_pressed ? 0.07 : 0.04),
                                Colors.transparent,
                                Colors.black.withOpacity(0.10),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 14 : 16,
                          compact ? 14 : 16,
                          compact ? 14 : 16,
                          compact ? 16 : 18,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: compact ? 8 : 10,
                                    vertical: compact ? 5 : 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: widget.accent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: widget.accent.withOpacity(0.28),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: widget.accent,
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  widget.accent.withOpacity(0.45),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        widget.badge,
                                        style: homeLabelFont(
                                          context,
                                          fontSize: compact ? 8.0 : 8.5,
                                          color: widget.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.arrow_outward_rounded,
                                  size: compact ? 16 : 18,
                                  color: AppPalette.homeBody.withOpacity(0.72),
                                ),
                              ],
                            ),
                            SizedBox(height: compact ? 10 : 14),
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(compact ? 10 : 14),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(compact ? 18 : 22),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.05),
                                      Colors.white.withOpacity(0.02),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: widget.accent.withOpacity(0.14),
                                  ),
                                ),
                                child: Image.asset(
                                  widget.assetPath,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 10 : 14),
                            Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: homeOrbitron(
                                fontSize: compact ? 18 : 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                color: AppPalette.homeTitle,
                                height: 1.05,
                                shadows: [
                                  Shadow(
                                    color: widget.accent.withOpacity(0.18),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: compact ? 6 : 8),
                            Text(
                              widget.subtitle,
                              maxLines: compact ? 3 : 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: homeBodyFont(
                                context,
                                fontSize: compact ? 11 : 12,
                                color: AppPalette.homeBody,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardAura extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _CardAura({
    required this.color,
    required this.size,
    this.opacity = 0.16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(opacity * 0.35),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  PlayerSymbol _symbol = PlayerSymbol.x;
  AIDifficulty _difficulty = AIDifficulty.easy;
  int _boardSize = 3;
  bool _busy = false;

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);

    // tiny debounce so repeated taps never double-start
    await Future.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;

    final boardConfig = standardBoardConfig(_boardSize);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GamePage(
          mode: GameMode.ai,
          difficulty: _difficulty,
          playerSymbol: _symbol,
          boardSize: boardConfig.boardSize,
          winCondition: boardConfig.winLength,
        ),
      ),
    );

    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final boardConfig = standardBoardConfig(_boardSize);

    return Scaffold(
      body: SafeArea(
        child: AppBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  children: [
                    AppIconButton(
                        icon: Icons.arrow_back,
                        onTap: () => navigateToHomeHub(context)),
                    const SizedBox(width: 12),
                    Text("SETUP",
                        style: titleFont(context).copyWith(fontSize: 18)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        children: [
                          _ModeHeroCard(
                            eyebrow: 'SOLO TRAINING',
                            title: 'TACTICAL SETUP',
                            subtitle:
                                'Choose your mark, tune the AI pressure, pick the arena size, and launch a clean match without changing the existing game flow.',
                            chips: [
                              _ModeInfoChip(
                                icon: Icons.close_rounded,
                                label:
                                    'SYMBOL ${_symbol == PlayerSymbol.x ? 'X' : 'O'}',
                                color: AppPalette.goldHighlight,
                              ),
                              _ModeInfoChip(
                                icon: Icons.tune_rounded,
                                label: 'AI ${_difficulty.name.toUpperCase()}',
                                color: AppPalette.primary,
                              ),
                              _ModeInfoChip(
                                icon: Icons.grid_view_rounded,
                                label: 'BOARD ${boardConfig.label}',
                                color: AppPalette.homeSky,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AppGlassCard(
                            padding: const EdgeInsets.all(20),
                            borderColor:
                                AppPalette.strokeStrong.withValues(alpha: 0.60),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("CHOOSE YOUR SYMBOL",
                                    style: sectionFont(context)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _SymbolTile(
                                        label: "X",
                                        selected: _symbol == PlayerSymbol.x,
                                        dimmed: _symbol == PlayerSymbol.o,
                                        onTap: _busy
                                            ? null
                                            : () => setState(
                                                () => _symbol = PlayerSymbol.x),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _SymbolTile(
                                        label: "O",
                                        selected: _symbol == PlayerSymbol.o,
                                        dimmed: _symbol == PlayerSymbol.x,
                                        onTap: _busy
                                            ? null
                                            : () => setState(
                                                () => _symbol = PlayerSymbol.o),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "The opposite symbol is automatically dimmed once you lock in your side.",
                                  textAlign: TextAlign.center,
                                  style:
                                      bodyFont(context).copyWith(fontSize: 12),
                                ),
                                const SizedBox(height: 22),
                                Row(
                                  children: [
                                    Text("DIFFICULTY",
                                        style: sectionFont(context)),
                                    const Spacer(),
                                    _TinyBadge(
                                      text: _difficulty.name.toUpperCase(),
                                      color: AppPalette.primary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _DifficultySegment(
                                  value: _difficulty,
                                  onChanged: _busy
                                      ? null
                                      : (d) => setState(() => _difficulty = d),
                                ),
                                const SizedBox(height: 22),
                                Row(
                                  children: [
                                    Text("BOARD SIZE",
                                        style: sectionFont(context)),
                                    const Spacer(),
                                    _TinyBadge(
                                      text: boardConfig.label,
                                      color: AppPalette.homeSky,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _BoardSizeSegment(
                                  value: _boardSize,
                                  onChanged: _busy
                                      ? null
                                      : (size) =>
                                          setState(() => _boardSize = size),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Board size sets the win rule too: 3, 4, or 5 in a row.",
                                  textAlign: TextAlign.center,
                                  style:
                                      bodyFont(context).copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // NO empty gap: fixed bottom padding + safe area
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: AppPillButton(
                    label: "LAUNCH MATCH",
                    loading: _busy,
                    onPressed: _busy ? null : _start,
                    icon: Icons.play_arrow_rounded,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FriendSetupPage extends StatefulWidget {
  const FriendSetupPage({super.key});

  @override
  State<FriendSetupPage> createState() => _FriendSetupPageState();
}

class _FriendSetupPageState extends State<FriendSetupPage> {
  PlayerSymbol _symbol = PlayerSymbol.x;
  int _boardSize = 3;
  bool _busy = false;

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);

    await Future.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;

    final boardConfig = standardBoardConfig(_boardSize);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GamePage(
          mode: GameMode.friend,
          difficulty: AIDifficulty.easy,
          playerSymbol: _symbol,
          boardSize: boardConfig.boardSize,
          winCondition: boardConfig.winLength,
        ),
      ),
    );

    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final boardConfig = standardBoardConfig(_boardSize);

    return Scaffold(
      body: SafeArea(
        child: AppBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => navigateToHomeHub(context),
                    ),
                    const SizedBox(width: 12),
                    Text("LOCAL SETUP",
                        style: titleFont(context).copyWith(fontSize: 18)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        children: [
                          _ModeHeroCard(
                            eyebrow: 'LOCAL DUEL',
                            title: 'HEAD-TO-HEAD SETUP',
                            subtitle:
                                'Pick the opening symbol, scale the board, and launch a same-device match without changing the existing friend-mode rules.',
                            chips: [
                              _ModeInfoChip(
                                icon: Icons.close_rounded,
                                label:
                                    'START ${_symbol == PlayerSymbol.x ? 'X' : 'O'}',
                                color: AppPalette.goldHighlight,
                              ),
                              _ModeInfoChip(
                                icon: Icons.grid_view_rounded,
                                label: 'BOARD ${boardConfig.label}',
                                color: AppPalette.homeSky,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AppGlassCard(
                            padding: const EdgeInsets.all(20),
                            borderColor:
                                AppPalette.strokeStrong.withValues(alpha: 0.60),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("WHO STARTS?",
                                    style: sectionFont(context)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _SymbolTile(
                                        label: "X",
                                        selected: _symbol == PlayerSymbol.x,
                                        dimmed: _symbol == PlayerSymbol.o,
                                        onTap: _busy
                                            ? null
                                            : () => setState(
                                                  () =>
                                                      _symbol = PlayerSymbol.x,
                                                ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _SymbolTile(
                                        label: "O",
                                        selected: _symbol == PlayerSymbol.o,
                                        dimmed: _symbol == PlayerSymbol.x,
                                        onTap: _busy
                                            ? null
                                            : () => setState(
                                                  () =>
                                                      _symbol = PlayerSymbol.o,
                                                ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "The chosen symbol takes the opening move in local play.",
                                  textAlign: TextAlign.center,
                                  style:
                                      bodyFont(context).copyWith(fontSize: 12),
                                ),
                                const SizedBox(height: 22),
                                Row(
                                  children: [
                                    Text("BOARD SIZE",
                                        style: sectionFont(context)),
                                    const Spacer(),
                                    _TinyBadge(
                                      text: boardConfig.label,
                                      color: AppPalette.homeSky,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _BoardSizeSegment(
                                  value: _boardSize,
                                  onChanged: _busy
                                      ? null
                                      : (size) =>
                                          setState(() => _boardSize = size),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Local matches scale the win rule with the board: 3, 4, or 5 in a row.",
                                  textAlign: TextAlign.center,
                                  style:
                                      bodyFont(context).copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: AppPillButton(
                    label: "START LOCAL MATCH",
                    loading: _busy,
                    onPressed: _busy ? null : _start,
                    icon: Icons.play_arrow_rounded,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SymbolTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  const _SymbolTile({
    required this.label,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = selected && !dimmed;
    final glow = active
        ? AppPalette.primary.withValues(alpha: 0.30)
        : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppPalette.radiusSmall),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: dimmed ? 0.35 : 1.0,
        child: Container(
          height: 98,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppPalette.radiusSmall),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: active
                  ? [
                      AppPalette.primary.withValues(alpha: 0.18),
                      AppPalette.accentPurple.withValues(alpha: 0.16),
                    ]
                  : [
                      AppPalette.panelSoft.withValues(alpha: 0.94),
                      AppPalette.panelDeep.withValues(alpha: 0.98),
                    ],
            ),
            border: Border.all(
              color: active
                  ? AppPalette.gold.withValues(alpha: 0.48)
                  : AppPalette.strokeSoft,
              width: active ? 1.6 : 1.0,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: glow,
                        blurRadius: 18,
                        spreadRadius: 2,
                        offset: const Offset(0, 8)),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: safeOrbitron(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: active ? Colors.white : Colors.white70,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                active ? "LOCKED IN" : "TAP TO SELECT",
                style: safeOrbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                  color: active ? AppPalette.goldHighlight : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultySegment extends StatelessWidget {
  final AIDifficulty value;
  final ValueChanged<AIDifficulty>? onChanged;

  const _DifficultySegment({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, AIDifficulty v) {
      final selected = value == v;
      return InkWell(
        onTap: onChanged == null ? null : () => onChanged!(v),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [
                      AppPalette.primary.withValues(alpha: 0.28),
                      AppPalette.accentPurple.withValues(alpha: 0.18),
                    ]
                  : [
                      AppPalette.panelSoft.withValues(alpha: 0.94),
                      AppPalette.panelDeep.withValues(alpha: 0.98),
                    ],
            ),
            border: Border.all(
              color: selected
                  ? AppPalette.gold.withValues(alpha: 0.40)
                  : AppPalette.strokeSoft,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppPalette.primary.withValues(alpha: 0.16),
                      blurRadius: 16,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: safeOrbitron(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
              color: selected ? Colors.white : AppPalette.textMuted,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 420) {
          return Row(
            children: [
              Expanded(child: chip("EASY", AIDifficulty.easy)),
              const SizedBox(width: 10),
              Expanded(child: chip("MEDIUM", AIDifficulty.medium)),
              const SizedBox(width: 10),
              Expanded(child: chip("HARD", AIDifficulty.hard)),
            ],
          );
        }

        final chipWidth = constraints.maxWidth >= 320
            ? max(0.0, (constraints.maxWidth - 10) / 2)
            : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(width: chipWidth, child: chip("EASY", AIDifficulty.easy)),
            SizedBox(
              width: chipWidth,
              child: chip("MEDIUM", AIDifficulty.medium),
            ),
            SizedBox(width: chipWidth, child: chip("HARD", AIDifficulty.hard)),
          ],
        );
      },
    );
  }
}

class _BoardSizeSegment extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;

  const _BoardSizeSegment({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(int size) {
      final selected = value == size;
      final boardConfig = standardBoardConfig(size);
      return InkWell(
        onTap: onChanged == null ? null : () => onChanged!(size),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [
                      AppPalette.homeSky.withValues(alpha: 0.26),
                      AppPalette.homeBlue.withValues(alpha: 0.18),
                    ]
                  : [
                      AppPalette.panelSoft.withValues(alpha: 0.94),
                      AppPalette.panelDeep.withValues(alpha: 0.98),
                    ],
            ),
            border: Border.all(
              color: selected
                  ? AppPalette.homeSky.withValues(alpha: 0.62)
                  : AppPalette.strokeSoft,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppPalette.homeSky.withValues(alpha: 0.16),
                      blurRadius: 16,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                boardConfig.label,
                style: safeOrbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: selected ? Colors.white : AppPalette.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${boardConfig.winLength} IN ROW',
                style: safeOrbitron(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: selected
                      ? AppPalette.homeSky.withValues(alpha: 0.92)
                      : AppPalette.textSubtle,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 360) {
          return Row(
            children: [
              Expanded(child: chip(3)),
              const SizedBox(width: 10),
              Expanded(child: chip(4)),
              const SizedBox(width: 10),
              Expanded(child: chip(5)),
            ],
          );
        }

        final chipWidth = max(0.0, (constraints.maxWidth - 10) / 2);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(width: chipWidth, child: chip(3)),
            SizedBox(width: chipWidth, child: chip(4)),
            SizedBox(width: chipWidth, child: chip(5)),
          ],
        );
      },
    );
  }
}

/// ==========================
///   COIN MATCH SETUP PAGE
/// ==========================
class CoinMatchSetupPage extends StatefulWidget {
  const CoinMatchSetupPage({super.key});

  @override
  State<CoinMatchSetupPage> createState() => _CoinMatchSetupPageState();
}

class _CoinMatchSetupPageState extends State<CoinMatchSetupPage> {
  PlayerSymbol _symbol = PlayerSymbol.x;
  int _boardSize = 3;
  int _coins = 0;
  int? _selectedEntryFee;
  final TextEditingController _customEntryFeeController =
      TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadCoins();
  }

  @override
  void dispose() {
    _customEntryFeeController.dispose();
    super.dispose();
  }

  Future<void> _loadCoins() async {
    final coins = await LocalStore.coins();
    if (mounted) setState(() => _coins = coins);
  }

  int? get _entryFee {
    if (_selectedEntryFee != null) return _selectedEntryFee;
    if (_customEntryFeeController.text.isNotEmpty) {
      final amount = int.tryParse(_customEntryFeeController.text);
      if (amount != null && amount > 0) return amount;
    }
    return null;
  }

  Future<void> _start() async {
    if (_busy) return;
    final fee = _entryFee;
    if (fee == null || fee <= 0) {
      showTopNotification(context, "Please select or enter a coin amount!",
          color: AppPalette.danger);
      return;
    }
    if (fee > _coins) {
      showTopNotification(context, "Not enough coins!",
          color: AppPalette.danger);
      return;
    }

    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;

    final boardConfig = standardBoardConfig(_boardSize);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoinMatchGamePage(
          playerSymbol: _symbol,
          entryFee: fee,
          boardSize: boardConfig.boardSize,
          winCondition: boardConfig.winLength,
        ),
      ),
    );

    if (mounted) {
      await _loadCoins();
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final boardConfig = standardBoardConfig(_boardSize);

    return Scaffold(
      body: SafeArea(
        child: AppBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  children: [
                    AppIconButton(
                        icon: Icons.arrow_back,
                        onTap: () => navigateToHomeHub(context)),
                    const SizedBox(width: 12),
                    Text("PLAY COIN AI",
                        style: titleFont(context).copyWith(fontSize: 18)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        _ModeHeroCard(
                          eyebrow: 'COIN ARENA',
                          title: 'HIGH STAKES MATCH',
                          subtitle:
                              'Pick your side, lock an entry fee, and enter a premium AI match where the wallet updates instantly on result.',
                          chips: [
                            _ModeInfoChip(
                              icon: Icons.sports_esports_rounded,
                              label:
                                  'SYMBOL ${_symbol == PlayerSymbol.x ? 'X' : 'O'}',
                              color: AppPalette.primary,
                            ),
                            _ModeInfoChip(
                              icon: Icons.payments_outlined,
                              label: _entryFee == null
                                  ? 'SELECT ENTRY'
                                  : 'ENTRY ${_entryFee!} COINS',
                              color: AppPalette.goldHighlight,
                            ),
                            _ModeInfoChip(
                              icon: Icons.grid_view_rounded,
                              label: 'BOARD ${boardConfig.label}',
                              color: AppPalette.homeSky,
                            ),
                          ],
                          trailing: SizedBox(
                            width: 168,
                            child: PremiumBalanceBar(
                              coins: _coins,
                              compact: true,
                              label: 'AVAILABLE',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppGlassCard(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text("BOARD SIZE",
                                      style: sectionFont(context)),
                                  const Spacer(),
                                  _TinyBadge(
                                    text: boardConfig.label,
                                    color: AppPalette.homeSky,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Coin battles scale the arena without changing the stake rules.",
                                style: bodyFont(context).copyWith(
                                  color: AppPalette.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _BoardSizeSegment(
                                value: _boardSize,
                                onChanged: _busy
                                    ? null
                                    : (size) =>
                                        setState(() => _boardSize = size),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppGlassCard(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            children: [
                              Text("CHOOSE SYMBOL",
                                  style: sectionFont(context)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _SymbolOption(
                                      symbol: PlayerSymbol.x,
                                      selected: _symbol == PlayerSymbol.x,
                                      onTap: () => setState(
                                          () => _symbol = PlayerSymbol.x),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _SymbolOption(
                                      symbol: PlayerSymbol.o,
                                      selected: _symbol == PlayerSymbol.o,
                                      onTap: () => setState(
                                          () => _symbol = PlayerSymbol.o),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppGlassCard(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("COIN AMOUNT", style: sectionFont(context)),
                              const SizedBox(height: 8),
                              Text(
                                "Funds are deducted when the match begins and refunded automatically on draws.",
                                style: bodyFont(context).copyWith(
                                  color: AppPalette.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [50, 100, 200, 500].map((amount) {
                                  final selected = _selectedEntryFee == amount;
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedEntryFee = amount;
                                        _customEntryFeeController.clear();
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        color: selected
                                            ? AppPalette.primary
                                                .withOpacity(0.28)
                                            : Colors.white.withOpacity(0.06),
                                        border: Border.all(
                                          color: selected
                                              ? AppPalette.primary
                                                  .withOpacity(0.70)
                                              : AppPalette.stroke,
                                        ),
                                      ),
                                      child: Text(
                                        "$amount",
                                        style: safeOrbitron(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: selected
                                              ? Colors.white
                                              : Colors.white70,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Text(
                                    "OR CUSTOM AMOUNT",
                                    style: sectionFont(context)
                                        .copyWith(fontSize: 12),
                                  ),
                                  const Spacer(),
                                  if (_entryFee != null)
                                    _TinyBadge(
                                      text: '${_entryFee!} COINS',
                                      color: AppPalette.goldHighlight,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _customEntryFeeController,
                                keyboardType: TextInputType.number,
                                style: safeOrbitron(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Enter amount",
                                  hintStyle: bodyFont(context),
                                  filled: true,
                                  fillColor: AppPalette.panelDeep
                                      .withValues(alpha: 0.92),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                        color: AppPalette.strokeSoft),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                        color: AppPalette.strokeSoft),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                        color: AppPalette.goldHighlight,
                                        width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                ),
                                onChanged: (_) {
                                  setState(() {
                                    _selectedEntryFee = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        AppPillButton(
                          label: "ENTER MATCH",
                          onPressed:
                              _busy || _entryFee == null || _entryFee! > _coins
                                  ? null
                                  : _start,
                          icon: Icons.play_arrow,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SymbolOption extends StatelessWidget {
  final PlayerSymbol symbol;
  final bool selected;
  final VoidCallback onTap;

  const _SymbolOption(
      {required this.symbol, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [
                    AppPalette.primary.withValues(alpha: 0.22),
                    AppPalette.accentPurple.withValues(alpha: 0.16),
                  ]
                : [
                    AppPalette.panelSoft.withValues(alpha: 0.94),
                    AppPalette.panelDeep.withValues(alpha: 0.98),
                  ],
          ),
          border: Border.all(
            color: selected
                ? AppPalette.gold.withValues(alpha: 0.40)
                : AppPalette.strokeSoft,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppPalette.primary.withValues(alpha: 0.14),
                    blurRadius: 16,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: symbol == PlayerSymbol.x
                    ? BoxShape.rectangle
                    : BoxShape.circle,
                borderRadius:
                    symbol == PlayerSymbol.x ? BorderRadius.circular(8) : null,
              ),
              child: symbol == PlayerSymbol.x
                  ? CustomPaint(
                      size: const Size(60, 60),
                      painter: _XPainter(
                        color: selected
                            ? AppPalette.goldHighlight
                            : AppPalette.textMuted,
                        strokeWidth: 6,
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppPalette.goldHighlight
                              : AppPalette.textMuted,
                          width: 8,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              symbol == PlayerSymbol.x ? "X" : "O",
              style: safeOrbitron(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : AppPalette.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              selected ? 'READY' : 'TAP TO PICK',
              style: safeOrbitron(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color:
                    selected ? AppPalette.goldHighlight : AppPalette.textSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ==========================
///   GAME PAGE
///   - board centered
///   - coins at top right
///   - "NEXT" at top
///   - ignores taps while AI thinking/moving
/// ==========================
class GamePage extends StatefulWidget {
  final GameMode mode;
  final AIDifficulty difficulty;
  final PlayerSymbol playerSymbol;
  final int boardSize;
  final int winCondition;

  const GamePage({
    super.key,
    required this.mode,
    required this.difficulty,
    required this.playerSymbol,
    this.boardSize = 3,
    this.winCondition = 3,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final MatchBoardConfig _boardConfig;
  late final List<List<int>> _winningLines;
  late List<String> board;
  bool gameOver = false;

  // turns are always "X" or "O" on the board
  String currentTurn = "X";
  String winner = "";
  List<int> winningLine = [];

  bool isAIMoving = false;
  int aiThinkingTime = 200;

  // player identity for AI mode
  late final String playerChar; // "X" or "O"
  late final String aiChar; // opposite

  Color _xPiece = NeonColors.xColors[0];
  Color _oPiece = NeonColors.oColors[0];
  bool _musicDucked = false;

  @override
  void initState() {
    super.initState();

    _boardConfig = MatchBoardConfig(
      boardSize: widget.boardSize,
      winLength: widget.winCondition,
    );
    _winningLines = generateWinningLines(
      boardSize: _boardConfig.boardSize,
      winLength: _boardConfig.winLength,
    );
    board = List.filled(_boardConfig.cellCount, "");

    playerChar = widget.playerSymbol == PlayerSymbol.x ? "X" : "O";
    aiChar = playerChar == "X" ? "O" : "X";
    if (widget.mode == GameMode.friend) {
      currentTurn = playerChar;
    }

    if (widget.mode == GameMode.ai) {
      aiThinkingTime = aiThinkingDelayForDifficulty(
        widget.difficulty,
        boardSize: _boardConfig.boardSize,
      );
    }

    AuditService.log('match_started', {
      'matchType': widget.mode == GameMode.friend ? 'friend' : 'ai_free',
      'difficulty': widget.difficulty.name,
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeGame();
    });
  }

  Future<void> _initializeGame() async {
    await Future.wait<void>([
      _duckGameplayMusic(),
      _loadMeta(),
    ]);
    if (!mounted) return;

    // If player chose O, let the first frame paint before the AI opens.
    if (widget.mode == GameMode.ai && playerChar == "O") {
      _aiMove();
    }
  }

  Future<void> _duckGameplayMusic() async {
    if (_musicDucked) return;
    _musicDucked = true;
    await SoundService().duckMusic();
  }

  Future<void> _restoreGameplayMusic() async {
    if (!_musicDucked) return;
    _musicDucked = false;
    await SoundService().restoreMusic();
  }

  void _leaveMatch() {
    unawaited(_restoreGameplayMusic());
    navigateToHomeHub(context);
  }

  @override
  void dispose() {
    unawaited(_restoreGameplayMusic());
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final p = await SharedPreferences.getInstance();
    final xHex = p.getString(Keys.xColor) ??
        NeonColors.colorToString(NeonColors.xColors[0]);
    final oHex = p.getString(Keys.oColor) ??
        NeonColors.colorToString(NeonColors.oColors[0]);
    if (!mounted) return;
    setState(() {
      _xPiece = NeonColors.stringToColor(xHex);
      _oPiece = NeonColors.stringToColor(oHex);
    });
  }

  void _resetGame() {
    if (isAIMoving) return; // prevent reset while AI is moving (optional)
    setState(() {
      board = List.filled(_boardConfig.cellCount, "");
      gameOver = false;
      winner = "";
      winningLine = [];
      currentTurn = widget.mode == GameMode.friend ? playerChar : "X";
      isAIMoving = false;
    });

    if (widget.mode == GameMode.ai && playerChar == "O") {
      _aiMove();
    }
  }

  void _makeMove(int index) {
    // HARD RULE: ignore any taps while AI is moving/thinking
    if (gameOver || isAIMoving) return;
    if (board[index].isNotEmpty) return;

    // In AI mode: only allow player taps on their turn
    if (widget.mode == GameMode.ai && currentTurn != playerChar) return;

    setState(() => board[index] = currentTurn);
    _checkGameState();

    if (gameOver) return;

    // switch turn
    setState(() => currentTurn = currentTurn == "X" ? "O" : "X");

    // AI turn?
    if (widget.mode == GameMode.ai && currentTurn == aiChar) {
      if (_winningMoveFor(aiChar) != -1) {
        showTopNotification(
          context,
          "Block! AI can win next move.",
          color: AppPalette.danger,
        );
      }
      _aiMove();
    }
  }

  void _checkGameState() {
    for (final line in _winningLines) {
      final a = line[0];
      final first = board[a];
      if (first.isEmpty) {
        continue;
      }

      final allMatch = line.every((index) => board[index] == first);
      if (allMatch) {
        setState(() {
          gameOver = true;
          winner = first;
          winningLine = line;
        });
        _handleResult();
        return;
      }
    }

    if (!board.any((cell) => cell.isEmpty)) {
      setState(() => gameOver = true);
      _handleResult(draw: true);
      return;
    }
  }

  Future<void> _handleResult({bool draw = false}) async {
    await _restoreGameplayMusic();
    final isFriendMode = widget.mode == GameMode.friend;
    final resultStr = draw ? 'draw' : (winner == playerChar ? 'win' : 'loss');

    int coinsToAdd = 0;
    if (!isFriendMode && !draw && winner == playerChar) {
      if (widget.difficulty == AIDifficulty.medium)
        coinsToAdd = 10;
      else if (widget.difficulty == AIDifficulty.hard) coinsToAdd = 15;
    }

    int? balanceAfter;
    if (coinsToAdd > 0) {
      balanceAfter = await LocalStore.applyCoinDeltaLocally(coinsToAdd);
    }

    if (!mounted) return;
    if (draw) {
      _showEndDialog(
          title: "DRAW",
          subtitle: "Perfect match!\nNo one loses today.",
          icon: Icons.handshake,
          coinsAdded: 0);
    } else {
      final isWin = winner == playerChar;
      _showEndDialog(
        title: isFriendMode
            ? "${winner} WINS"
            : (isWin ? "YOU WIN" : "YOU LOST"),
        subtitle: isFriendMode
            ? "Round complete."
            : (isWin ? "Arena cleared." : "The AI took this round."),
        icon: isWin || isFriendMode
            ? Icons.emoji_events_outlined
            : Icons.sentiment_dissatisfied_outlined,
        coinsAdded: isWin ? coinsToAdd : 0,
        rewardText: isWin && coinsToAdd > 0
            ? 'Added +$coinsToAdd coins'
            : null,
      );
    }

    AuditService.log('match_ended', {
      'matchType': isFriendMode ? 'friend' : 'ai_free',
      'difficulty': widget.difficulty.name,
      'result': resultStr,
    });
    if (!isFriendMode) {
      _persistAIResult(resultStr, coinsToAdd, balanceAfter: balanceAfter);
    }

    if (FirebaseAuth.instance.currentUser == null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showGuestSignInPrompt();
      });
    }
  }

  /// Persist game stats and coin updates in background (after dialog is shown).
  Future<void> _persistAIResult(
    String resultStr,
    int coinsToAdd, {
    int? balanceAfter,
  }) async {
    await LocalStore.addResult(result: resultStr);
    if (coinsToAdd > 0) {
      final after = balanceAfter ?? await LocalStore.coins();
      final before = max(0, after - coinsToAdd);
      await LocalStore.syncCoinBalance();
      await LocalStore.addTopupHistory(
          usd: 0.0,
          coins: coinsToAdd,
          type: 'win',
          description: 'AI Match Win',
          balanceBefore: before,
          balanceAfter: after);
    }
  }

  void _showGuestSignInPrompt() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 56, color: AppPalette.primary),
                const SizedBox(height: 16),
                Text(
                  "Sign In for Coin Rewards! 🎁",
                  style: safeOrbitron(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Sign in to earn coins and track your progress!",
                  textAlign: TextAlign.center,
                  style: bodyFont(context)
                      .copyWith(height: 1.4, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        label: "LATER",
                        fill: Colors.white.withOpacity(0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.pop(context),
                        icon: Icons.close,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: "SIGN IN",
                        fill: AppPalette.primary.withOpacity(0.9),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamed('/login');
                        },
                        icon: Icons.login,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEndDialog(
      {required String title,
      required String subtitle,
      required IconData icon,
      int coinsAdded = 0,
      String? rewardText}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EndDialog(
        title: title,
        subtitle: subtitle,
        icon: icon,
        coinsAdded: coinsAdded,
        rewardText: rewardText,
        onRestart: () {
          Navigator.pop(context);
          unawaited(_duckGameplayMusic());
          _resetGame();
        },
        onHome: () {
          Navigator.pop(context);
          _leaveMatch();
        },
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 44, color: AppPalette.warning),
                const SizedBox(height: 10),
                Text(
                  "Exit Match?",
                  style: safeOrbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Leave now and this round will be abandoned. Your current board progress will be lost.",
                  textAlign: TextAlign.center,
                  style: bodyFont(context).copyWith(height: 1.3),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        label: "STAY",
                        fill: Colors.white.withOpacity(0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.pop(context),
                        icon: Icons.close,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: "LEAVE",
                        fill: AppPalette.danger.withOpacity(0.9),
                        onPressed: () {
                          Navigator.pop(context);
                          _leaveMatch();
                        },
                        icon: Icons.exit_to_app,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _aiMove() async {
    if (isAIMoving || gameOver || !mounted) return;
    setState(() => isAIMoving = true);

    await Future.delayed(Duration(milliseconds: aiThinkingTime));
    if (!mounted || gameOver) {
      if (mounted) setState(() => isAIMoving = false);
      return;
    }

    final best = _findBestMove(widget.difficulty, aiChar, playerChar);
    if (best != -1) {
      setState(() => board[best] = aiChar);
      _checkGameState();
      if (!gameOver) {
        setState(() => currentTurn = playerChar);
      }
    }

    if (mounted) setState(() => isAIMoving = false);
  }

  int _findBestMove(AIDifficulty difficulty, String ai, String human) {
    return pickStrategicMove(
      board: board,
      winningLines: _winningLines,
      aiPlayer: ai,
      humanPlayer: human,
      boardSize: _boardConfig.boardSize,
      winLength: _boardConfig.winLength,
      difficulty: difficulty,
    );
  }

  int _winningMoveFor(String who) {
    for (int i = 0; i < board.length; i++) {
      if (board[i].isEmpty) {
        board[i] = who;
        final ok = _isWinning(who);
        board[i] = "";
        if (ok) return i;
      }
    }
    return -1;
  }

  bool _isWinning(String player) {
    for (final line in _winningLines) {
      if (line.every((index) => board[index] == player)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final headerLabel = widget.mode == GameMode.ai
        ? "VS AI • ${widget.difficulty.name.toUpperCase()}"
        : "VS FRIEND";
    final boardSpacing = matchBoardSpacing(_boardConfig.boardSize);
    final boardPadding = matchBoardPadding(_boardConfig.boardSize);
    final cellRadius = matchBoardCellRadius(_boardConfig.boardSize);
    final statusColor = gameOver
        ? (winner.isEmpty
            ? AppPalette.goldHighlight
            : (winner == "X" ? _xPiece : _oPiece))
        : AppPalette.text;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showExitConfirmation();
        }
      },
      child: Scaffold(
        backgroundColor: AppPalette.bgDepth,
        body: SafeArea(
          child: AppBackground(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final landscape = constraints.maxWidth > constraints.maxHeight;
                final buttonHeight = landscape ? 48.0 : 52.0;

                Widget buildHeaderCard() {
                  return AppGlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: LayoutBuilder(
                      builder: (context, headerConstraints) {
                        final stackedHeader = headerConstraints.maxWidth < 360;
                        final coinWidth = clampDouble(
                          headerConstraints.maxWidth * (stackedHeader ? 0.48 : 0.30),
                          stackedHeader ? 118.0 : 132.0,
                          stackedHeader ? 156.0 : 176.0,
                        );
                        final titleWidth = max(
                          0.0,
                          headerConstraints.maxWidth - coinWidth - 66.0,
                        );
                        final titleBlock = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headerLabel,
                              style: sectionFont(context).copyWith(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_boardConfig.label} • ${_boardConfig.winLength} in a row',
                              style: bodyFont(context).copyWith(
                                fontSize: 12,
                                color: AppPalette.textMuted,
                              ),
                            ),
                          ],
                        );

                        final coinWidget = SizedBox(
                          width: coinWidth,
                          child: ValueListenableBuilder<int>(
                            valueListenable: LocalStore.coinsNotifier,
                            builder: (_, coins, __) => CoinPill(
                              coins: coins,
                              width: coinWidth,
                            ),
                          ),
                        );

                        if (stackedHeader) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  AppIconButton(
                                    icon: Icons.arrow_back,
                                    onTap: _showExitConfirmation,
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: max(0.0, headerConstraints.maxWidth - 56.0),
                                    child: Text(
                                      headerLabel,
                                      style: sectionFont(context)
                                          .copyWith(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              coinWidget,
                              const SizedBox(height: 10),
                              Text(
                                '${_boardConfig.label} • ${_boardConfig.winLength} in a row',
                                style: bodyFont(context).copyWith(
                                  fontSize: 12,
                                  color: AppPalette.textMuted,
                                ),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            AppIconButton(
                              icon: Icons.arrow_back,
                              onTap: _showExitConfirmation,
                            ),
                            const SizedBox(width: 12),
                            SizedBox(width: titleWidth, child: titleBlock),
                            const SizedBox(width: 10),
                            coinWidget,
                          ],
                        );
                      },
                    ),
                  );
                }

                Widget buildStatusCard() {
                  return AppGlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    borderColor: statusColor.withValues(alpha: 0.28),
                    child: Center(
                      child: gameOver
                          ? Text(
                              winner.isEmpty ? 'DRAW' : '$winner WINS',
                              style: safeOrbitron(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                color: statusColor,
                              ),
                            )
                          : Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                Text(
                                  'NEXT:',
                                  style: sectionFont(context)
                                      .copyWith(fontSize: 12),
                                ),
                                _TurnPill(
                                  text: currentTurn,
                                  color: currentTurn == 'X'
                                      ? _xPiece
                                      : _oPiece,
                                ),
                                if (isAIMoving) ...[
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  Text(
                                    'AI THINKING...',
                                    style: sectionFont(context)
                                        .copyWith(fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  );
                }

                Widget buildBoard(BoxConstraints boardConstraints) {
                  final boardViewport = matchBoardViewportSizeForBounds(
                    boardSize: _boardConfig.boardSize,
                    maxWidth: boardConstraints.maxWidth,
                    maxHeight: boardConstraints.maxHeight,
                  );
                  if (boardViewport <= 0) {
                    return const SizedBox.shrink();
                  }

                  return SizedBox(
                    width: boardViewport,
                    height: boardViewport,
                    child: AppGlassCard(
                      padding: EdgeInsets.all(boardPadding),
                      borderColor:
                          AppPalette.strokeStrong.withValues(alpha: 0.55),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppPalette.panelSoft.withValues(alpha: 0.98),
                          AppPalette.panelDeep.withValues(alpha: 0.99),
                        ],
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _boardConfig.boardSize,
                          crossAxisSpacing: boardSpacing,
                          mainAxisSpacing: boardSpacing,
                        ),
                        itemCount: _boardConfig.cellCount,
                        itemBuilder: (context, i) {
                          final isWinCell = winningLine.contains(i);
                          final cellAccent = board[i] == 'X' ? _xPiece : _oPiece;
                          return InkWell(
                            borderRadius: BorderRadius.circular(cellRadius),
                            onTap: () => _makeMove(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(cellRadius),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isWinCell
                                      ? [
                                          cellAccent.withValues(alpha: 0.18),
                                          AppPalette.panelElevated
                                              .withValues(alpha: 0.98),
                                        ]
                                      : [
                                          AppPalette.panelSoft
                                              .withValues(alpha: 0.94),
                                          AppPalette.panelDeep
                                              .withValues(alpha: 0.98),
                                        ],
                                ),
                                border: Border.all(
                                  color: isWinCell
                                      ? cellAccent.withValues(alpha: 0.85)
                                      : AppPalette.strokeSoft,
                                  width: isWinCell ? 2.2 : 1.0,
                                ),
                                boxShadow: isWinCell
                                    ? [
                                        BoxShadow(
                                          color: cellAccent.withValues(
                                            alpha: 0.20,
                                          ),
                                          blurRadius: 16,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 8),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.16,
                                          ),
                                          blurRadius: 12,
                                          spreadRadius: -5,
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: _CellContent(
                                  v: board[i],
                                  xColor: _xPiece,
                                  oColor: _oPiece,
                                  boardSize: _boardConfig.boardSize,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }

                Widget buildFooter() {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: landscape ? 340 : 560,
                    ),
                    child: LayoutBuilder(
                      builder: (context, footerConstraints) {
                        final stackButtons = footerConstraints.maxWidth < 360;
                        if (stackButtons) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppPillButton(
                                label: 'RESTART',
                                minHeight: buttonHeight,
                                fill: Colors.white.withOpacity(0.08),
                                stroke: AppPalette.strokeStrong,
                                onPressed: isAIMoving ? null : _resetGame,
                                icon: Icons.refresh,
                              ),
                              const SizedBox(height: 12),
                              AppPillButton(
                                label: 'HOME',
                                minHeight: buttonHeight,
                                fill:
                                    AppPalette.goldDeep.withValues(alpha: 0.95),
                                onPressed: _showExitConfirmation,
                                icon: Icons.home_outlined,
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: AppPillButton(
                                label: 'RESTART',
                                minHeight: buttonHeight,
                                fill: Colors.white.withOpacity(0.08),
                                stroke: AppPalette.strokeStrong,
                                onPressed: isAIMoving ? null : _resetGame,
                                icon: Icons.refresh,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppPillButton(
                                label: 'HOME',
                                minHeight: buttonHeight,
                                fill:
                                    AppPalette.goldDeep.withValues(alpha: 0.95),
                                onPressed: _showExitConfirmation,
                                icon: Icons.home_outlined,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                }

                if (landscape) {
                  return Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 10, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              buildHeaderCard(),
                              const SizedBox(height: 10),
                              buildStatusCard(),
                              const Spacer(),
                              buildFooter(),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 12, 14, 16),
                          child: LayoutBuilder(
                            builder: (context, boardConstraints) {
                              return Center(
                                child: buildBoard(boardConstraints),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                      child: buildHeaderCard(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: buildStatusCard(),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: LayoutBuilder(
                          builder: (context, boardConstraints) {
                            return Center(
                              child: buildBoard(boardConstraints),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: buildFooter(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TurnPill extends StatelessWidget {
  final String text;
  final Color color;
  const _TurnPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(0.14),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        text,
        style: safeOrbitron(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _CellContent extends StatelessWidget {
  final String v;
  final Color xColor;
  final Color oColor;
  final int boardSize;

  const _CellContent(
      {required this.v,
      required this.xColor,
      required this.oColor,
      this.boardSize = 3});

  double get _pieceExtent {
    if (boardSize >= 5) return 34;
    if (boardSize == 4) return 44;
    return 62;
  }

  double get _strokeWidth {
    if (boardSize >= 5) return 6;
    if (boardSize == 4) return 8;
    return 10;
  }

  @override
  Widget build(BuildContext context) {
    if (v == "X") {
      return CustomPaint(
        size: Size(_pieceExtent, _pieceExtent),
        painter: _XPainter(color: xColor, strokeWidth: _strokeWidth),
      );
    }
    if (v == "O") {
      return Container(
        width: _pieceExtent,
        height: _pieceExtent,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: oColor, width: _strokeWidth),
          boxShadow: [
            BoxShadow(
                color: oColor.withOpacity(0.22),
                blurRadius: boardSize >= 5 ? 10 : 16,
                spreadRadius: 1),
          ],
        ),
      );
    }
    return const SizedBox();
  }
}

/// Elegant X painter (kept correct)
class _XPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _XPainter({required this.color, this.strokeWidth = 8});

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0.35)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = strokeWidth + 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    final corePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.95),
          Color.lerp(color, Colors.white, 0.25)!,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final padding = size.width * 0.18;
    final startX = padding;
    final endX = size.width - padding;
    final startY = padding;
    final endY = size.height - padding;

    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), glowPaint);
    canvas.drawLine(Offset(endX, startY), Offset(startX, endY), glowPaint);
    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), corePaint);
    canvas.drawLine(Offset(endX, startY), Offset(startX, endY), corePaint);
  }

  @override
  bool shouldRepaint(covariant _XPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

/// End dialog (fixed layout / no broken buttons)
class _EndDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onRestart;
  final VoidCallback onHome;
  final String restartLabel;
  final IconData restartIcon;
  final int coinsAdded;
  final String? rewardText;

  const _EndDialog({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onRestart,
    required this.onHome,
    this.restartLabel = "REPLAY",
    this.restartIcon = Icons.refresh,
    this.coinsAdded = 0,
    this.rewardText,
  });

  @override
  Widget build(BuildContext context) {
    final isLoss = icon == Icons.sentiment_dissatisfied_outlined ||
        icon == Icons.sentiment_very_dissatisfied;
    final isDraw = icon == Icons.handshake;
    final accent = isLoss
        ? AppPalette.danger
        : isDraw
            ? AppPalette.primary
            : AppPalette.goldHighlight;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AppGlassCard(
          padding: const EdgeInsets.all(20),
          borderColor: accent.withValues(alpha: 0.34),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppPalette.panelElevated.withValues(alpha: 0.98),
              AppPalette.panelDeep.withValues(alpha: 0.98),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.22),
                      AppPalette.panelDeep.withValues(alpha: 0.98),
                    ],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.32)),
                ),
                child: Center(
                  child: isLoss
                      ? Image.asset('assets/game/skull.png',
                          width: 44, height: 44)
                      : Icon(
                          icon,
                          size: 40,
                          color: isDraw ? AppPalette.primary : accent,
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'MATCH RESOLVED',
                style: safeOrbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.3,
                  color: accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: safeOrbitron(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: bodyFont(context).copyWith(height: 1.3),
              ),
              if (coinsAdded > 0 && rewardText != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppPalette.gold.withValues(alpha: 0.16),
                        AppPalette.primary.withValues(alpha: 0.14),
                      ],
                    ),
                    border: Border.all(
                        color: AppPalette.gold.withValues(alpha: 0.38)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/coin/dollar .png',
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        rewardText!,
                        style: safeOrbitron(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppPalette.goldHighlight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppPillButton(
                      label: "HOME",
                      fill: Colors.white.withOpacity(0.08),
                      stroke: AppPalette.strokeStrong,
                      onPressed: onHome,
                      icon: Icons.home_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppPillButton(
                      label: restartLabel,
                      fill: isLoss ? AppPalette.danger : AppPalette.primary,
                      onPressed: onRestart,
                      icon: restartIcon,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ==========================
///   COIN MATCH GAME PAGE
/// ==========================
class CoinMatchGamePage extends StatefulWidget {
  final PlayerSymbol playerSymbol;
  final int entryFee;
  final int boardSize;
  final int winCondition;

  const CoinMatchGamePage({
    super.key,
    required this.playerSymbol,
    required this.entryFee,
    this.boardSize = 3,
    this.winCondition = 3,
  });

  @override
  State<CoinMatchGamePage> createState() => _CoinMatchGamePageState();
}

class _CoinMatchGamePageState extends State<CoinMatchGamePage> {
  late final MatchBoardConfig _boardConfig;
  late final List<List<int>> _winningLines;
  late List<String> board;
  bool gameOver = false;
  String currentTurn = "X";
  String winner = "";
  List<int> winningLine = [];
  bool isAIMoving = false;
  late final String playerChar;
  late final String aiChar;
  Color _xPiece = NeonColors.xColors[0];
  Color _oPiece = NeonColors.oColors[0];
  bool _musicDucked = false;

  @override
  void initState() {
    super.initState();
    _boardConfig = MatchBoardConfig(
      boardSize: widget.boardSize,
      winLength: widget.winCondition,
    );
    _winningLines = generateWinningLines(
      boardSize: _boardConfig.boardSize,
      winLength: _boardConfig.winLength,
    );
    board = List.filled(_boardConfig.cellCount, "");
    playerChar = widget.playerSymbol == PlayerSymbol.x ? "X" : "O";
    aiChar = playerChar == "X" ? "O" : "X";
    AuditService.log('match_started',
        {'matchType': 'coin_match', 'entryFee': widget.entryFee});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeMatch();
    });
  }

  Future<void> _initializeMatch() async {
    await Future.wait<void>([
      _duckGameplayMusic(),
      _deductEntryFee(),
      _loadMeta(),
    ]);
    if (!mounted) return;

    if (playerChar == "O") {
      _aiMove();
    }
  }

  Future<void> _duckGameplayMusic() async {
    if (_musicDucked) return;
    _musicDucked = true;
    await SoundService().duckMusic();
  }

  Future<void> _restoreGameplayMusic() async {
    if (!_musicDucked) return;
    _musicDucked = false;
    await SoundService().restoreMusic();
  }

  void _leaveMatch() {
    unawaited(_restoreGameplayMusic());
    navigateToHomeHub(context);
  }

  @override
  void dispose() {
    unawaited(_restoreGameplayMusic());
    super.dispose();
  }

  Future<void> _deductEntryFee() async {
    final before = LocalStore.coinsNotifier.value;
    await LocalStore.updateCoins(-widget.entryFee);
    await LocalStore.addTopupHistory(
        usd: 0.0,
        coins: widget.entryFee,
        type: 'loss',
        description: 'Game Entry',
        balanceBefore: before,
        balanceAfter: before - widget.entryFee);
  }

  Future<void> _loadMeta() async {
    final p = await SharedPreferences.getInstance();
    final xHex = p.getString(Keys.xColor) ??
        NeonColors.colorToString(NeonColors.xColors[0]);
    final oHex = p.getString(Keys.oColor) ??
        NeonColors.colorToString(NeonColors.oColors[0]);
    if (!mounted) return;
    setState(() {
      _xPiece = NeonColors.stringToColor(xHex);
      _oPiece = NeonColors.stringToColor(oHex);
    });
  }

  void _makeMove(int index) {
    if (gameOver || isAIMoving) return;
    if (board[index].isNotEmpty) return;
    if (currentTurn != playerChar) return;

    setState(() => board[index] = currentTurn);
    _checkGameState();
    if (gameOver) return;

    setState(() => currentTurn = currentTurn == "X" ? "O" : "X");
    if (currentTurn == aiChar) {
      if (_winningMoveFor(aiChar) != -1) {
        showTopNotification(
          context,
          "Block! AI can win next move.",
          color: AppPalette.danger,
        );
      }
      _aiMove();
    }
  }

  void _checkGameState() {
    for (final line in _winningLines) {
      final first = board[line[0]];
      if (first.isEmpty) {
        continue;
      }

      final allMatch = line.every((index) => board[index] == first);
      if (allMatch) {
        setState(() {
          gameOver = true;
          winner = first;
          winningLine = line;
        });
        _handleResult();
        return;
      }
    }

    if (!board.any((cell) => cell.isEmpty)) {
      setState(() => gameOver = true);
      _handleResult(draw: true);
    }
  }

  Future<void> _handleResult({bool draw = false}) async {
    await _restoreGameplayMusic();
    final resultStr = draw ? 'draw' : (winner == playerChar ? 'win' : 'loss');

    int coinsToAdd = 0;
    if (resultStr == 'win') {
      coinsToAdd = widget.entryFee * 2;
    } else if (resultStr == 'draw') {
      coinsToAdd = widget.entryFee;
    }

    int? balanceAfter;
    if (coinsToAdd > 0) {
      balanceAfter = await LocalStore.applyCoinDeltaLocally(coinsToAdd);
    }

    if (!mounted) return;
    if (draw) {
      _showEndDialog(
        title: "DRAW",
        subtitle: "Nobody drops this round.",
        icon: Icons.handshake,
        coinsAdded: coinsToAdd,
        rewardText: 'Returned +$coinsToAdd coins',
      );
    } else if (winner == playerChar) {
      _showEndDialog(
        title: "YOU WIN!",
        subtitle: "High-stakes arena cleared.",
        icon: Icons.emoji_events_outlined,
        coinsAdded: coinsToAdd,
        rewardText: 'Added +$coinsToAdd coins',
      );
    } else {
      _showEndDialog(
        title: "YOU LOST",
        subtitle: "The AI claimed this pot.",
        icon: Icons.sentiment_dissatisfied_outlined,
      );
    }

    AuditService.log('match_ended', {
      'matchType': 'coin_match',
      'entryFee': widget.entryFee,
      'result': resultStr
    });
    _persistCoinMatchResult(resultStr, coinsToAdd, balanceAfter: balanceAfter);
  }

  /// Persist coin match stats and rewards in background (after dialog is shown).
  Future<void> _persistCoinMatchResult(
    String resultStr,
    int coinsToAdd, {
    int? balanceAfter,
  }) async {
    try {
      await LocalStore.addResult(result: resultStr);
      if (coinsToAdd > 0) {
        final after = balanceAfter ?? await LocalStore.coins();
        final before = max(0, after - coinsToAdd);
        await LocalStore.syncCoinBalance();
        final desc = resultStr == 'draw' ? 'Game Draw Refund' : 'Game Win';
        await LocalStore.addTopupHistory(
            usd: 0.0,
            coins: coinsToAdd,
            type: 'win',
            description: desc,
            balanceBefore: before,
            balanceAfter: after);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CoinMatchGamePage] Background persist error: $e');
      }
    }
  }

  void _showEndDialog(
      {required String title,
      required String subtitle,
      required IconData icon,
      int coinsAdded = 0,
      String? rewardText}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EndDialog(
        title: title,
        subtitle: subtitle,
        icon: icon,
        coinsAdded: coinsAdded,
        rewardText: rewardText,
        onRestart: () {
          Navigator.pop(context);
          unawaited(_duckGameplayMusic());
          _resetGame();
        },
        onHome: () {
          Navigator.pop(context);
          _leaveMatch();
        },
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 44, color: AppPalette.warning),
                const SizedBox(height: 10),
                Text(
                  "Exit Coin Battle?",
                  style: safeOrbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Leaving now forfeits this run and the ${widget.entryFee} coin entry for this battle.",
                  textAlign: TextAlign.center,
                  style: bodyFont(context).copyWith(height: 1.3),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        label: "STAY",
                        fill: Colors.white.withOpacity(0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.pop(context),
                        icon: Icons.close,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: "LEAVE",
                        fill: AppPalette.danger.withOpacity(0.9),
                        onPressed: () {
                          Navigator.pop(context);
                          _leaveMatch();
                        },
                        icon: Icons.exit_to_app,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _resetGame() {
    if (isAIMoving) return;
    setState(() {
      board = List.filled(_boardConfig.cellCount, "");
      gameOver = false;
      winner = "";
      winningLine = [];
      currentTurn = "X";
      isAIMoving = false;
    });
    _deductEntryFee();
    if (playerChar == "O") {
      _aiMove();
    }
  }

  Future<void> _aiMove() async {
    if (isAIMoving || gameOver || !mounted) return;
    setState(() => isAIMoving = true);

    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted || gameOver) {
      if (mounted) setState(() => isAIMoving = false);
      return;
    }

    final best = _findAdaptiveMove();
    if (best != -1) {
      setState(() => board[best] = aiChar);
      _checkGameState();
      if (!gameOver) {
        setState(() => currentTurn = playerChar);
      }
    }

    if (mounted) setState(() => isAIMoving = false);
  }

  int _findAdaptiveMove() {
    return pickStrategicMove(
      board: board,
      winningLines: _winningLines,
      aiPlayer: aiChar,
      humanPlayer: playerChar,
      boardSize: _boardConfig.boardSize,
      winLength: _boardConfig.winLength,
      difficulty: AIDifficulty.hard,
    );
  }

  int _winningMoveFor(String who) {
    for (int i = 0; i < board.length; i++) {
      if (board[i].isEmpty) {
        board[i] = who;
        final ok = _isWinning(who);
        board[i] = "";
        if (ok) return i;
      }
    }
    return -1;
  }

  bool _isWinning(String player) {
    for (final line in _winningLines) {
      if (line.every((index) => board[index] == player)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final boardSpacing = matchBoardSpacing(_boardConfig.boardSize);
    final boardPadding = matchBoardPadding(_boardConfig.boardSize);
    final cellRadius = matchBoardCellRadius(_boardConfig.boardSize);
    final statusColor = gameOver
        ? (winner.isEmpty
            ? AppPalette.goldHighlight
            : (winner == "X" ? _xPiece : _oPiece))
        : AppPalette.text;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showExitConfirmation();
        }
      },
      child: Scaffold(
        backgroundColor: AppPalette.bgDepth,
        body: SafeArea(
          child: AppBackground(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final landscape = constraints.maxWidth > constraints.maxHeight;
                final buttonHeight = landscape ? 48.0 : 52.0;

                Widget buildHeaderCard() {
                  return AppGlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: LayoutBuilder(
                      builder: (context, headerConstraints) {
                        final stackedHeader = headerConstraints.maxWidth < 360;
                        final coinWidth = clampDouble(
                          headerConstraints.maxWidth * (stackedHeader ? 0.48 : 0.30),
                          stackedHeader ? 118.0 : 132.0,
                          stackedHeader ? 156.0 : 176.0,
                        );
                        final titleWidth = max(
                          0.0,
                          headerConstraints.maxWidth - coinWidth - 66.0,
                        );
                        final coinWidget = SizedBox(
                          width: coinWidth,
                          child: ValueListenableBuilder<int>(
                            valueListenable: LocalStore.coinsNotifier,
                            builder: (_, coins, __) => CoinPill(
                              coins: coins,
                              width: coinWidth,
                            ),
                          ),
                        );

                        final titleBlock = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VS AI • COIN PLAY',
                              style: sectionFont(context),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Entry: ${widget.entryFee} coins',
                              style: bodyFont(context)
                                  .copyWith(color: AppPalette.warning),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_boardConfig.label} • ${_boardConfig.winLength} in a row',
                              style: bodyFont(context).copyWith(
                                color: AppPalette.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );

                        if (stackedHeader) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  AppIconButton(
                                    icon: Icons.arrow_back,
                                    onTap: _showExitConfirmation,
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: max(0.0, headerConstraints.maxWidth - 56.0),
                                    child: Text(
                                      'VS AI • COIN PLAY',
                                      style: sectionFont(context),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              coinWidget,
                              const SizedBox(height: 10),
                              Text(
                                'Entry: ${widget.entryFee} coins',
                                style: bodyFont(context)
                                    .copyWith(color: AppPalette.warning),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_boardConfig.label} • ${_boardConfig.winLength} in a row',
                                style: bodyFont(context).copyWith(
                                  color: AppPalette.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            AppIconButton(
                              icon: Icons.arrow_back,
                              onTap: _showExitConfirmation,
                            ),
                            const SizedBox(width: 12),
                            SizedBox(width: titleWidth, child: titleBlock),
                            const SizedBox(width: 10),
                            coinWidget,
                          ],
                        );
                      },
                    ),
                  );
                }

                Widget buildStatusCard() {
                  return AppGlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    borderColor: statusColor.withValues(alpha: 0.28),
                    child: Center(
                      child: isAIMoving
                          ? Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                Text(
                                  'AI thinking...',
                                  style: bodyFont(context),
                                ),
                              ],
                            )
                          : Text(
                              gameOver
                                  ? (winner.isEmpty ? 'DRAW' : '$winner WINS')
                                  : 'NEXT: $currentTurn',
                              style: safeOrbitron(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: statusColor,
                              ),
                            ),
                    ),
                  );
                }

                Widget buildEntryFeeCard() {
                  return AppGlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    borderColor: AppPalette.gold.withValues(alpha: 0.34),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/coin/COIN.png',
                              width: 26,
                              height: 26,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${widget.entryFee} coins',
                              style: safeOrbitron(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFFFD700),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                Widget buildBoard(BoxConstraints boardConstraints) {
                  final boardViewport = matchBoardViewportSizeForBounds(
                    boardSize: _boardConfig.boardSize,
                    maxWidth: boardConstraints.maxWidth,
                    maxHeight: boardConstraints.maxHeight,
                  );
                  if (boardViewport <= 0) {
                    return const SizedBox.shrink();
                  }

                  return SizedBox(
                    width: boardViewport,
                    height: boardViewport,
                    child: AppGlassCard(
                      padding: EdgeInsets.all(boardPadding),
                      borderColor:
                          AppPalette.strokeStrong.withValues(alpha: 0.55),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppPalette.panelSoft.withValues(alpha: 0.98),
                          AppPalette.panelDeep.withValues(alpha: 0.99),
                        ],
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _boardConfig.boardSize,
                          mainAxisSpacing: boardSpacing,
                          crossAxisSpacing: boardSpacing,
                        ),
                        itemCount: _boardConfig.cellCount,
                        itemBuilder: (context, i) {
                          final isWinning = winningLine.contains(i);
                          final cellAccent = board[i] == 'X' ? _xPiece : _oPiece;
                          return InkWell(
                            onTap: () => _makeMove(i),
                            borderRadius: BorderRadius.circular(cellRadius),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(cellRadius),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isWinning
                                      ? [
                                          cellAccent.withValues(alpha: 0.18),
                                          AppPalette.panelElevated
                                              .withValues(alpha: 0.98),
                                        ]
                                      : [
                                          AppPalette.panelSoft
                                              .withValues(alpha: 0.94),
                                          AppPalette.panelDeep
                                              .withValues(alpha: 0.98),
                                        ],
                                ),
                                border: Border.all(
                                  color: isWinning
                                      ? cellAccent.withValues(alpha: 0.84)
                                      : AppPalette.strokeSoft,
                                  width: isWinning ? 2 : 1,
                                ),
                                boxShadow: isWinning
                                    ? [
                                        BoxShadow(
                                          color: cellAccent.withValues(
                                            alpha: 0.18,
                                          ),
                                          blurRadius: 16,
                                          spreadRadius: -2,
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.16,
                                          ),
                                          blurRadius: 12,
                                          spreadRadius: -5,
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: _CellContent(
                                  v: board[i],
                                  xColor: _xPiece,
                                  oColor: _oPiece,
                                  boardSize: _boardConfig.boardSize,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }

                Widget buildFooter() {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: landscape ? 340 : 560,
                    ),
                    child: LayoutBuilder(
                      builder: (context, footerConstraints) {
                        final stackButtons = footerConstraints.maxWidth < 360;
                        if (stackButtons) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppPillButton(
                                label: 'RESTART',
                                minHeight: buttonHeight,
                                fill: Colors.white.withOpacity(0.08),
                                stroke: AppPalette.strokeStrong,
                                onPressed: isAIMoving ? null : _resetGame,
                                icon: Icons.refresh,
                              ),
                              const SizedBox(height: 12),
                              AppPillButton(
                                label: 'HOME',
                                minHeight: buttonHeight,
                                fill:
                                    AppPalette.goldDeep.withValues(alpha: 0.95),
                                onPressed: _showExitConfirmation,
                                icon: Icons.home_outlined,
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: AppPillButton(
                                label: 'RESTART',
                                minHeight: buttonHeight,
                                fill: Colors.white.withOpacity(0.08),
                                stroke: AppPalette.strokeStrong,
                                onPressed: isAIMoving ? null : _resetGame,
                                icon: Icons.refresh,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppPillButton(
                                label: 'HOME',
                                minHeight: buttonHeight,
                                fill:
                                    AppPalette.goldDeep.withValues(alpha: 0.95),
                                onPressed: _showExitConfirmation,
                                icon: Icons.home_outlined,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                }

                if (landscape) {
                  return Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 10, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              buildHeaderCard(),
                              const SizedBox(height: 10),
                              buildStatusCard(),
                              const SizedBox(height: 10),
                              buildEntryFeeCard(),
                              const Spacer(),
                              buildFooter(),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 12, 14, 16),
                          child: LayoutBuilder(
                            builder: (context, boardConstraints) {
                              return Center(
                                child: buildBoard(boardConstraints),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                      child: buildHeaderCard(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: buildStatusCard(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      child: buildEntryFeeCard(),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: LayoutBuilder(
                          builder: (context, boardConstraints) {
                            return Center(
                              child: buildBoard(boardConstraints),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: buildFooter(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// ==========================
///   LEVEL GAME SETUP PAGE
/// ==========================
class LevelGameSetupPage extends StatefulWidget {
  const LevelGameSetupPage({super.key});

  @override
  State<LevelGameSetupPage> createState() => _LevelGameSetupPageState();
}

class _LevelGameSetupPageState extends State<LevelGameSetupPage> {
  int _currentLevel = 1;
  bool _loading = true;
  PlayerSymbol _symbol = PlayerSymbol.x;

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  Future<void> _loadLevel() async {
    try {
      final level = await LocalStore.getLevelGameCurrentLevel().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint(
                '[LevelGameSetupPage] _loadLevel timeout - using default level 1');
          }
          return 1; // Fallback to level 1 if timeout
        },
      );
      if (mounted) {
        setState(() {
          _currentLevel = level;
          _loading = false;
        });
      }
    } catch (e) {
      // If any error occurs, fallback to level 1 and hide loading
      if (kDebugMode) {
        debugPrint('[LevelGameSetupPage] _loadLevel error: $e');
      }
      if (mounted) {
        setState(() {
          _currentLevel = 1;
          _loading = false;
        });
      }
    }
  }

  Future<void> _start() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => LevelGamePage(
              initialLevel: _currentLevel, playerSymbol: _symbol)),
    );
    await _loadLevel();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: SafeArea(
          child: AppBackground(
            child: const Center(
              child: CircularProgressIndicator(color: AppPalette.primary),
            ),
          ),
        ),
      );
    }

    final progress = _currentLevel / 20;
    return Scaffold(
      body: SafeArea(
        child: AppBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  children: [
                    AppIconButton(
                        icon: Icons.arrow_back,
                        onTap: () => navigateToHomeHub(context)),
                    const SizedBox(width: 12),
                    Text("LEVEL GAME",
                        style: titleFont(context).copyWith(fontSize: 18)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        _ModeHeroCard(
                          eyebrow: 'CAMPAIGN MODE',
                          title: 'LEVEL RUN',
                          subtitle:
                              'Clear progressive arena boards, keep your streak alive, and collect milestone payouts without touching the level logic underneath.',
                          chips: [
                            _ModeInfoChip(
                              icon: Icons.flag_rounded,
                              label: 'LEVEL $_currentLevel / 20',
                              color: AppPalette.goldHighlight,
                            ),
                            _ModeInfoChip(
                              icon: Icons.grid_view_rounded,
                              label: _currentLevel <= 8
                                  ? '3x3 GRID'
                                  : _currentLevel <= 15
                                      ? '4x4 GRID'
                                      : '5x5 GRID',
                              color: AppPalette.primary,
                            ),
                          ],
                          trailing: SizedBox(
                            width: 148,
                            child: _SummaryMetricTile(
                              icon: Icons.auto_graph_rounded,
                              label: 'PROGRESS',
                              value: '${(progress * 100).toInt()}%',
                              accent: AppPalette.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppGlassCard(
                          padding: const EdgeInsets.all(22),
                          borderColor:
                              AppPalette.primary.withValues(alpha: 0.24),
                          child: Column(
                            children: [
                              Text("CURRENT LEVEL",
                                  style: sectionFont(context)),
                              const SizedBox(height: 16),
                              Text(
                                "$_currentLevel / 20",
                                style: safeOrbitron(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: AppPalette.goldHighlight,
                                ),
                              ),
                              const SizedBox(height: 16),
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: AppPalette.panelDeep
                                    .withValues(alpha: 0.90),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppPalette.primary),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "${(progress * 100).toInt()}% Complete",
                                style: bodyFont(context)
                                    .copyWith(color: AppPalette.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppGlassCard(
                          padding: const EdgeInsets.all(22),
                          borderColor: AppPalette.gold.withValues(alpha: 0.26),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("REWARDS", style: sectionFont(context)),
                              const SizedBox(height: 12),
                              _RewardInfo(level: 10, coins: 100),
                              const SizedBox(height: 8),
                              _RewardInfo(level: 20, coins: 500),
                              const SizedBox(height: 12),
                              Text(
                                "Each level: +10 coins",
                                style: bodyFont(context)
                                    .copyWith(color: AppPalette.goldHighlight),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppGlassCard(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            children: [
                              Text("CHOOSE SYMBOL",
                                  style: sectionFont(context)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _SymbolOption(
                                      symbol: PlayerSymbol.x,
                                      selected: _symbol == PlayerSymbol.x,
                                      onTap: () => setState(
                                          () => _symbol = PlayerSymbol.x),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _SymbolOption(
                                      symbol: PlayerSymbol.o,
                                      selected: _symbol == PlayerSymbol.o,
                                      onTap: () => setState(
                                          () => _symbol = PlayerSymbol.o),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        AppPillButton(
                          label: "ENTER LEVEL $_currentLevel",
                          onPressed: _start,
                          icon: Icons.play_arrow,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardInfo extends StatelessWidget {
  final int level;
  final int coins;

  const _RewardInfo({required this.level, required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppPalette.panelSoft.withValues(alpha: 0.96),
            AppPalette.panelDeep.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.gold.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppPalette.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppPalette.goldHighlight,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Level $level milestone",
              style: bodyFont(context),
            ),
          ),
          Image.asset(
            'assets/coin/COIN.png',
            width: 20,
            height: 20,
          ),
          const SizedBox(width: 8),
          Text(
            "+$coins",
            style: safeOrbitron(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppPalette.goldHighlight,
            ),
          ),
        ],
      ),
    );
  }
}

/// ==========================
///   LEVEL GAME PAGE
/// ==========================
class LevelGamePage extends StatefulWidget {
  final int initialLevel;
  final PlayerSymbol playerSymbol;

  const LevelGamePage(
      {super.key, required this.initialLevel, required this.playerSymbol});

  @override
  State<LevelGamePage> createState() => _LevelGamePageState();
}

class _LevelGamePageState extends State<LevelGamePage> {
  late int _currentLevel;
  late int _boardSize;
  late int _winCondition;
  late AIDifficulty _difficulty;
  late List<String> board;
  bool gameOver = false;
  late String currentTurn;
  late String playerChar;
  late String aiChar;
  String winner = "";
  List<int> winningLine = [];
  bool isAIMoving = false;
  Color _xPiece = NeonColors.xColors[0];
  Color _oPiece = NeonColors.oColors[0];
  bool _musicDucked = false;

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.initialLevel;
    playerChar = widget.playerSymbol == PlayerSymbol.x ? "X" : "O";
    aiChar = playerChar == "X" ? "O" : "X";
    currentTurn = playerChar; // Human plays first if X, AI plays first if O
    AuditService.log('match_started',
        {'matchType': 'level_campaign', 'level': widget.initialLevel});
    _updateLevelConfig();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeLevelMatch();
    });
  }

  Future<void> _initializeLevelMatch() async {
    await Future.wait<void>([
      _duckGameplayMusic(),
      _loadMeta(),
    ]);
    if (!mounted) return;
    if (playerChar == "O") {
      _aiMove();
    }
  }

  Future<void> _duckGameplayMusic() async {
    if (_musicDucked) return;
    _musicDucked = true;
    await SoundService().duckMusic();
  }

  Future<void> _restoreGameplayMusic() async {
    if (!_musicDucked) return;
    _musicDucked = false;
    await SoundService().restoreMusic();
  }

  void _leaveLevelGame() {
    unawaited(_restoreGameplayMusic());
    navigateToHomeHub(context);
  }

  @override
  void dispose() {
    unawaited(_restoreGameplayMusic());
    super.dispose();
  }

  void _updateLevelConfig() {
    if (_currentLevel <= 8) {
      _boardSize = 3;
      _winCondition = 3;
      final diffIndex = (_currentLevel - 1) % 3;
      _difficulty = [
        AIDifficulty.easy,
        AIDifficulty.medium,
        AIDifficulty.hard
      ][diffIndex];
    } else if (_currentLevel <= 15) {
      _boardSize = 4;
      _winCondition = 4;
      _difficulty = AIDifficulty.hard;
    } else {
      _boardSize = 5;
      _winCondition = 5;
      _difficulty = AIDifficulty.hard;
    }
    board = List.filled(_boardSize * _boardSize, "");
  }

  Future<void> _loadMeta() async {
    final p = await SharedPreferences.getInstance();
    final xHex = p.getString(Keys.xColor) ??
        NeonColors.colorToString(NeonColors.xColors[0]);
    final oHex = p.getString(Keys.oColor) ??
        NeonColors.colorToString(NeonColors.oColors[0]);
    if (!mounted) return;
    setState(() {
      _xPiece = NeonColors.stringToColor(xHex);
      _oPiece = NeonColors.stringToColor(oHex);
    });
  }

  void _makeMove(int index) {
    if (gameOver || isAIMoving) return;
    if (board[index].isNotEmpty) return;
    if (currentTurn != playerChar) return;

    setState(() => board[index] = currentTurn);
    _checkGameState();
    if (gameOver) return;

    setState(() => currentTurn = aiChar);
    if (_winningMoveFor(aiChar) != -1) {
      showTopNotification(
        context,
        "Block! AI can win next move.",
        color: AppPalette.danger,
      );
    }
    _aiMove();
  }

  void _checkGameState() {
    final lines = _generateWinLines();
    for (final line in lines) {
      if (line.length < _winCondition) continue;
      final first = board[line[0]];
      if (first.isEmpty) continue;
      bool allMatch = true;
      for (int i = 1; i < _winCondition; i++) {
        if (board[line[i]] != first) {
          allMatch = false;
          break;
        }
      }
      if (allMatch) {
        setState(() {
          gameOver = true;
          winner = first;
          winningLine = line.sublist(0, _winCondition);
        });
        _handleResult();
        return;
      }
    }

    if (!board.any((cell) => cell.isEmpty)) {
      setState(() => gameOver = true);
      _handleResult(draw: true);
    }
  }

  List<List<int>> _generateWinLines() {
    return generateWinningLines(
      boardSize: _boardSize,
      winLength: _winCondition,
    );
  }

  Future<void> _handleResult({bool draw = false}) async {
    await _restoreGameplayMusic();
    final resultStr = draw ? 'draw' : (winner == playerChar ? 'win' : 'loss');

    if (winner == aiChar) {
      if (!mounted) return;
      _showEndDialog(
        title: "YOU LOST",
        subtitle: "Level reset to 1\nStart from beginning!",
        icon: Icons.sentiment_dissatisfied_outlined,
        resetLevel: true,
        isDraw: false,
        isWin: false,
      );
      AuditService.log('match_ended', {
        'matchType': 'level_campaign',
        'level': _currentLevel,
        'result': resultStr
      });
      _persistLevelResult(resultStr, 0, isLoss: true);
    } else if (draw) {
      if (!mounted) return;
      _showEndDialog(
        title: "DRAW",
        subtitle: "Replay same level.",
        icon: Icons.handshake,
        resetLevel: false,
        isDraw: true,
        isWin: false,
      );
      AuditService.log('match_ended', {
        'matchType': 'level_campaign',
        'level': _currentLevel,
        'result': resultStr
      });
      _persistLevelResult(resultStr, 0);
    } else {
      int reward = 10;
      if (_currentLevel >= 11 && _currentLevel <= 19) {
        reward = 15;
      } else if (_currentLevel == 10) {
        reward = 100;
      } else if (_currentLevel == 20) {
        reward = 500;
      }
      final nextLevel = _currentLevel < 20 ? _currentLevel + 1 : _currentLevel;
      final balanceAfter = await LocalStore.applyCoinDeltaLocally(reward);

      if (!mounted) return;
      if (_currentLevel >= 20) {
        _showEndDialog(
          title: "CONGRATULATIONS!",
          subtitle: "You completed all 20 levels!",
          icon: Icons.emoji_events,
          resetLevel: false,
          isDraw: false,
          isWin: true,
          coinsAdded: reward,
          rewardText: 'Added +$reward coins',
        );
      } else {
        _showEndDialog(
          title: "LEVEL $_currentLevel COMPLETE!",
          subtitle: "Starting level $nextLevel...",
          icon: Icons.check_circle_outline,
          resetLevel: false,
          isDraw: false,
          isWin: true,
          coinsAdded: reward,
          rewardText: 'Added +$reward coins',
        );
      }

      AuditService.log('match_ended', {
        'matchType': 'level_campaign',
        'level': _currentLevel,
        'result': resultStr
      });
      _persistLevelResult(
        resultStr,
        reward,
        balanceAfter: balanceAfter,
        nextLevel: nextLevel,
      );
    }
  }

  /// Persist level game stats and rewards in background (after dialog is shown).
  Future<void> _persistLevelResult(String resultStr, int reward,
      {bool isLoss = false, int? nextLevel, int? balanceAfter}) async {
    try {
      if (isLoss) {
        await LocalStore.resetLevelGame();
      }
      await LocalStore.addResult(result: resultStr);
      if (reward > 0) {
        final after = balanceAfter ?? await LocalStore.coins();
        final before = max(0, after - reward);
        await LocalStore.syncCoinBalance();
        await LocalStore.addTopupHistory(
            usd: 0.0,
            coins: reward,
            type: 'win',
            description: 'Level Game Win',
            balanceBefore: before,
            balanceAfter: after);
      }
      if (nextLevel != null) {
        if (_currentLevel < 20) {
          await LocalStore.setLevelGameCurrentLevel(nextLevel);
        } else {
          await LocalStore.setLevelGameCompleted(true);
          await LocalStore.incrementLevelGameCompletions();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LevelGamePage] Background persist error: $e');
      }
    }
  }

  void _showEndDialog({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool resetLevel,
    required bool isDraw,
    required bool isWin,
    int coinsAdded = 0,
    String? rewardText,
  }) {
    final useNext = isWin;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EndDialog(
        title: title,
        subtitle: subtitle,
        icon: icon,
        coinsAdded: coinsAdded,
        rewardText: rewardText,
        restartLabel: useNext ? "NEXT" : "REPLAY",
        restartIcon: useNext ? Icons.arrow_forward : Icons.refresh,
        onRestart: () {
          Navigator.pop(context);
          unawaited(_duckGameplayMusic());
          if (resetLevel) {
            _currentLevel = 1;
            _updateLevelConfig();
            setState(() {
              board = List.filled(_boardSize * _boardSize, "");
              gameOver = false;
              winner = "";
              winningLine = [];
              currentTurn = playerChar;
              isAIMoving = false;
            });
            if (currentTurn == aiChar) _aiMove();
          } else if (isDraw) {
            setState(() {
              board = List.filled(_boardSize * _boardSize, "");
              gameOver = false;
              winner = "";
              winningLine = [];
              currentTurn = playerChar;
              isAIMoving = false;
            });
            if (currentTurn == aiChar) _aiMove();
          } else {
            final nextLevel =
                _currentLevel < 20 ? _currentLevel + 1 : _currentLevel;
            _currentLevel = nextLevel;
            _updateLevelConfig();
            setState(() {
              board = List.filled(_boardSize * _boardSize, "");
              gameOver = false;
              winner = "";
              winningLine = [];
              currentTurn = playerChar;
              isAIMoving = false;
            });
            if (currentTurn == aiChar) _aiMove();
          }
        },
        onHome: () {
          Navigator.pop(context);
          _leaveLevelGame();
        },
      ),
    );
  }

  Future<void> _aiMove() async {
    if (isAIMoving || gameOver || !mounted) return;
    setState(() => isAIMoving = true);

    final thinkingTime = aiThinkingDelayForDifficulty(
      _difficulty,
      boardSize: _boardSize,
    );

    await Future.delayed(Duration(milliseconds: thinkingTime));
    if (!mounted || gameOver) {
      if (mounted) setState(() => isAIMoving = false);
      return;
    }

    final best = _findBestMove();
    if (best != -1) {
      setState(() => board[best] = aiChar);
      _checkGameState();
      if (!gameOver) {
        setState(() => currentTurn = playerChar);
      }
    }

    if (mounted) setState(() => isAIMoving = false);
  }

  int _findBestMove() {
    return pickStrategicMove(
      board: board,
      winningLines: _generateWinLines(),
      aiPlayer: aiChar,
      humanPlayer: playerChar,
      boardSize: _boardSize,
      winLength: _winCondition,
      difficulty: _difficulty,
    );
  }

  int _winningMoveFor(String who) {
    final lines = _generateWinLines();
    for (final line in lines) {
      if (line.length < _winCondition) continue;
      int count = 0;
      int emptyIndex = -1;
      for (int i = 0; i < _winCondition; i++) {
        if (board[line[i]] == who) {
          count++;
        } else if (board[line[i]].isEmpty) {
          emptyIndex = line[i];
        } else {
          break;
        }
      }
      if (count == _winCondition - 1 && emptyIndex != -1) {
        return emptyIndex;
      }
    }
    return -1;
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 44, color: AppPalette.warning),
                const SizedBox(height: 10),
                Text(
                  "Exit Level Run?",
                  style: safeOrbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Leave now and your current campaign run resets back to the start.",
                  textAlign: TextAlign.center,
                  style: bodyFont(context).copyWith(height: 1.3),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        label: "STAY",
                        fill: Colors.white.withOpacity(0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.pop(context),
                        icon: Icons.close,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: "LEAVE",
                        fill: AppPalette.danger.withOpacity(0.9),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _restoreGameplayMusic();
                          await LocalStore.resetLevelGame();
                          if (!mounted) return;
                          _leaveLevelGame();
                        },
                        icon: Icons.exit_to_app,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boardSpacing = matchBoardSpacing(_boardSize);
    final boardPadding = matchBoardPadding(_boardSize);
    final cellRadius = matchBoardCellRadius(_boardSize);
    final statusColor = gameOver
        ? (winner.isEmpty
            ? AppPalette.goldHighlight
            : (winner == "X" ? _xPiece : _oPiece))
        : AppPalette.text;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showExitConfirmation();
      },
      child: Scaffold(
        body: SafeArea(
          child: AppBackground(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final landscape = constraints.maxWidth > constraints.maxHeight;

                Widget buildHeaderCard() {
                  return AppGlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: LayoutBuilder(
                      builder: (context, headerConstraints) {
                        final stackedHeader = headerConstraints.maxWidth < 360;
                        final coinWidth = clampDouble(
                          headerConstraints.maxWidth * (stackedHeader ? 0.48 : 0.30),
                          stackedHeader ? 118.0 : 132.0,
                          stackedHeader ? 156.0 : 176.0,
                        );
                        final titleWidth = max(
                          0.0,
                          headerConstraints.maxWidth - coinWidth - 66.0,
                        );
                        final coinWidget = SizedBox(
                          width: coinWidth,
                          child: ValueListenableBuilder<int>(
                            valueListenable: LocalStore.coinsNotifier,
                            builder: (_, coins, __) => CoinPill(
                              coins: coins,
                              width: coinWidth,
                            ),
                          ),
                        );

                        final titleBlock = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LEVEL $_currentLevel',
                              style: sectionFont(context),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_boardSize×$_boardSize • $_winCondition in a row',
                              style: bodyFont(context),
                            ),
                          ],
                        );

                        if (stackedHeader) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  AppIconButton(
                                    icon: Icons.arrow_back,
                                    onTap: _showExitConfirmation,
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: max(0.0, headerConstraints.maxWidth - 56.0),
                                    child: Text(
                                      'LEVEL $_currentLevel',
                                      style: sectionFont(context),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              coinWidget,
                              const SizedBox(height: 10),
                              Text(
                                '$_boardSize×$_boardSize • $_winCondition in a row',
                                style: bodyFont(context),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            AppIconButton(
                              icon: Icons.arrow_back,
                              onTap: _showExitConfirmation,
                            ),
                            const SizedBox(width: 12),
                            SizedBox(width: titleWidth, child: titleBlock),
                            const SizedBox(width: 10),
                            coinWidget,
                          ],
                        );
                      },
                    ),
                  );
                }

                Widget buildStatusCard() {
                  return AppGlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    borderColor: statusColor.withValues(alpha: 0.28),
                    child: Center(
                      child: isAIMoving
                          ? Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                Text(
                                  'AI thinking...',
                                  style: bodyFont(context),
                                ),
                              ],
                            )
                          : Text(
                              gameOver
                                  ? (winner.isEmpty ? 'DRAW' : '$winner WINS')
                                  : 'NEXT: $currentTurn',
                              style: safeOrbitron(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: statusColor,
                              ),
                            ),
                    ),
                  );
                }

                Widget buildBoard(BoxConstraints boardConstraints) {
                  final boardViewport = matchBoardViewportSizeForBounds(
                    boardSize: _boardSize,
                    maxWidth: boardConstraints.maxWidth,
                    maxHeight: boardConstraints.maxHeight,
                  );
                  if (boardViewport <= 0) {
                    return const SizedBox.shrink();
                  }

                  return SizedBox(
                    width: boardViewport,
                    height: boardViewport,
                    child: AppGlassCard(
                      padding: EdgeInsets.all(boardPadding),
                      borderColor:
                          AppPalette.strokeStrong.withValues(alpha: 0.55),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppPalette.panelSoft.withValues(alpha: 0.98),
                          AppPalette.panelDeep.withValues(alpha: 0.99),
                        ],
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _boardSize,
                          mainAxisSpacing: boardSpacing,
                          crossAxisSpacing: boardSpacing,
                        ),
                        itemCount: _boardSize * _boardSize,
                        itemBuilder: (context, i) {
                          final isWinning = winningLine.contains(i);
                          final cellAccent = board[i] == 'X' ? _xPiece : _oPiece;
                          return InkWell(
                            onTap: () => _makeMove(i),
                            borderRadius: BorderRadius.circular(cellRadius),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(cellRadius),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isWinning
                                      ? [
                                          cellAccent.withValues(alpha: 0.18),
                                          AppPalette.panelElevated
                                              .withValues(alpha: 0.98),
                                        ]
                                      : [
                                          AppPalette.panelSoft
                                              .withValues(alpha: 0.94),
                                          AppPalette.panelDeep
                                              .withValues(alpha: 0.98),
                                        ],
                                ),
                                border: Border.all(
                                  color: isWinning
                                      ? cellAccent.withValues(alpha: 0.85)
                                      : AppPalette.strokeSoft,
                                  width: isWinning ? 2 : 1,
                                ),
                                boxShadow: isWinning
                                    ? [
                                        BoxShadow(
                                          color: cellAccent.withValues(
                                            alpha: 0.20,
                                          ),
                                          blurRadius: 16,
                                          spreadRadius: -2,
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.16,
                                          ),
                                          blurRadius: 12,
                                          spreadRadius: -5,
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: _CellContent(
                                  v: board[i],
                                  xColor: _xPiece,
                                  oColor: _oPiece,
                                  boardSize: _boardSize,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }

                return Stack(
                  children: [
                    if (landscape)
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 8, 10, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  buildHeaderCard(),
                                  const SizedBox(height: 10),
                                  buildStatusCard(),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 6,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 12, 14, 16),
                              child: LayoutBuilder(
                                builder: (context, boardConstraints) {
                                  return Center(
                                    child: buildBoard(boardConstraints),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                            child: buildHeaderCard(),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: buildStatusCard(),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                              child: LayoutBuilder(
                                builder: (context, boardConstraints) {
                                  return Center(
                                    child: buildBoard(boardConstraints),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// ==========================
///   STORE (CONSISTENT UI)
/// ==========================
class StorePage extends StatefulWidget {
  final int initialTab;
  final bool embedded;
  const StorePage({super.key, this.initialTab = 0, this.embedded = false});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage>
    with SingleTickerProviderStateMixin {
  late int _selectedTab;
  int _coins = 0;
  List<int> _ownedX = [];
  List<int> _ownedO = [];
  List<int> _ownedAvatars = [1];
  int _equippedAvatar = 1;
  int _selectedXIndex = 0;
  int _selectedOIndex = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    LocalStore.coinsNotifier.addListener(_onCoinsChanged);
    _load();
  }

  @override
  void dispose() {
    LocalStore.coinsNotifier.removeListener(_onCoinsChanged);
    super.dispose();
  }

  void _onCoinsChanged() {
    if (mounted) setState(() => _coins = LocalStore.coinsNotifier.value);
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _ownedX = await LocalStore.ownedXColors();
    _ownedO = await LocalStore.ownedOColors();
    final currentX = await LocalStore.xPieceColor();
    final currentO = await LocalStore.oPieceColor();
    _selectedXIndex = max(
        0,
        NeonColors.xColors
            .indexWhere((c) => c.toARGB32() == currentX.toARGB32()));
    _selectedOIndex = max(
        0,
        NeonColors.oColors
            .indexWhere((c) => c.toARGB32() == currentO.toARGB32()));
    _ownedAvatars = await LocalStore.ownedAvatars();
    _equippedAvatar = await LocalStore.equippedAvatar();
    setState(() => _coins = p.getInt(Keys.coins) ?? 0);
  }

  String _storeHeaderTitle() {
    switch (_selectedTab) {
      case 1:
        return 'Avatar Gallery';
      case 2:
        return 'Buy Coins';
      case 0:
      default:
        return 'Store';
    }
  }

  String _storeHeaderSubtitle() {
    switch (_selectedTab) {
      case 1:
        return 'Equip premium avatars without crowding the gallery layout.';
      case 2:
        return 'Top up your arena wallet and get back into the match flow.';
      case 0:
      default:
        return 'Customize your arena loadout with cleaner, faster browsing.';
    }
  }

  /// Show dialog when user doesn't have enough coins
  void _showInsufficientCoinsDialog(
      BuildContext context, int required, int current) {
    final needed = required - current;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 56, color: AppPalette.warning),
                const SizedBox(height: 16),
                Text(
                  "Not Enough Coins",
                  style: safeOrbitron(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "You need $required coins to purchase this item.\nYou currently have $current coins.",
                  textAlign: TextAlign.center,
                  style: bodyFont(context)
                      .copyWith(height: 1.4, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppPalette.warning.withOpacity(0.15),
                    border:
                        Border.all(color: AppPalette.warning.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on_rounded,
                          color: Color(0xFFFFD700), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Need $needed more coins",
                        style: safeOrbitron(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFFD700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        label: "CANCEL",
                        fill: Colors.white.withOpacity(0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.pop(context),
                        icon: Icons.close,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: "BUY COINS",
                        fill: AppPalette.goldDeep,
                        stroke: AppPalette.goldHighlight.withOpacity(0.55),
                        onPressed: () {
                          Navigator.pop(context);
                          // Switch to coins tab
                          setState(() => _selectedTab = 2);
                        },
                        icon: Icons.monetization_on_rounded,
                        iconColor: const Color(0xFFFFD700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showPurchaseConfirmDialog({
    required BuildContext context,
    required bool isX,
    required Color color,
    required int price,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isX ? 'X' : 'O',
                  style: safeOrbitron(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    color: color,
                    shadows: [
                      Shadow(
                          color: color.withValues(alpha: 0.6), blurRadius: 20),
                      Shadow(
                          color: color.withValues(alpha: 0.3), blurRadius: 40),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Unlock ${isX ? "X" : "O"} Color?',
                  style: safeOrbitron(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/coin/COIN.png',
                      height: 18,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 6),
                    Text('$price',
                        style: safeOrbitron(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFFFD700))),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        label: 'CANCEL',
                        fill: Colors.white.withOpacity(0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.pop(context, false),
                        icon: Icons.close,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: 'CONFIRM',
                        fill: AppPalette.primary.withOpacity(0.9),
                        onPressed: () => Navigator.pop(context, true),
                        icon: Icons.check,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _buyXColor(int i) async {
    if (_busy) return;
    // Check if guest
    if (FirebaseAuth.instance.currentUser == null) {
      showSignInRequiredDialog(context);
      return;
    }
    if (_ownedX.contains(i)) {
      showTopNotification(context, "Already owned!", color: AppPalette.danger);
      return;
    }
    final price = priceForColorIndex(i);
    if (_coins < price) {
      _showInsufficientCoinsDialog(context, price, _coins);
      return;
    }
    // Show confirmation dialog
    final confirmed = await _showPurchaseConfirmDialog(
      context: context,
      isX: true,
      color: NeonColors.xColors[i],
      price: price,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final before = LocalStore.coinsNotifier.value;
    await LocalStore.updateCoins(-price);
    await LocalStore.addTopupHistory(
        usd: 0.0,
        coins: price,
        type: 'loss',
        description: 'Cosmetic Purchase',
        balanceBefore: before,
        balanceAfter: before - price);
    await LocalStore.addOwnedXColor(i);
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    showTopNotification(context, "Purchased X color!",
        color: AppPalette.success);
  }

  Future<void> _buyOColor(int i) async {
    if (_busy) return;
    // Check if guest
    if (FirebaseAuth.instance.currentUser == null) {
      showSignInRequiredDialog(context);
      return;
    }
    if (_ownedO.contains(i)) {
      showTopNotification(context, "Already owned!", color: AppPalette.danger);
      return;
    }
    final price = priceForColorIndex(i);
    if (_coins < price) {
      _showInsufficientCoinsDialog(context, price, _coins);
      return;
    }
    // Show confirmation dialog
    final confirmed = await _showPurchaseConfirmDialog(
      context: context,
      isX: false,
      color: NeonColors.oColors[i],
      price: price,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final before = LocalStore.coinsNotifier.value;
    await LocalStore.updateCoins(-price);
    await LocalStore.addTopupHistory(
        usd: 0.0,
        coins: price,
        type: 'loss',
        description: 'Cosmetic Purchase',
        balanceBefore: before,
        balanceAfter: before - price);
    await LocalStore.addOwnedOColor(i);
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    showTopNotification(context, "Purchased O color!",
        color: AppPalette.success);
  }

  Future<void> _buyAvatar(GameAvatar avatar) async {
    if (_busy) return;
    if (FirebaseAuth.instance.currentUser == null) {
      showSignInRequiredDialog(context);
      return;
    }
    if (_ownedAvatars.contains(avatar.id)) {
      await _equipAvatar(avatar.id);
      return;
    }
    if (avatar.price > 0 && _coins < avatar.price) {
      _showInsufficientCoinsDialog(context, avatar.price, _coins);
      return;
    }
    final confirmed = await showAvatarPurchaseDialog(context, avatar);
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    if (avatar.price > 0) {
      final before = LocalStore.coinsNotifier.value;
      await LocalStore.updateCoins(-avatar.price);
      await LocalStore.addTopupHistory(
        usd: 0.0,
        coins: avatar.price,
        type: 'loss',
        description: 'Avatar Purchase: ${avatar.name}',
        balanceBefore: before,
        balanceAfter: before - avatar.price,
      );
    }
    await LocalStore.addOwnedAvatar(avatar.id);
    await LocalStore.setEquippedAvatar(avatar.id);
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    showTopNotification(context, 'Purchased ${avatar.name}!',
        color: AppPalette.success);
  }

  Future<void> _equipAvatar(int id) async {
    if (_busy) return;
    await LocalStore.setEquippedAvatar(id);
    if (!mounted) return;
    setState(() => _equippedAvatar = id);
    showTopNotification(context, '${gameAvatarById(id).name} equipped!',
        color: AppPalette.success);
  }

  String _usernameOrFallback() {
    final current = FirebaseAuth.instance.currentUser;
    final raw = current?.displayName ?? current?.email ?? 'P';
    return raw.trim().isEmpty ? 'P' : raw.trim();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _StoreTabBar(
            selectedIndex: _selectedTab,
            onTabSelected: (i) => setState(() => _selectedTab = i),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: IndexedStack(
            index: _selectedTab,
            children: [
              _ColorsTab(
                ownedX: _ownedX,
                ownedO: _ownedO,
                selectedXIndex: _selectedXIndex,
                selectedOIndex: _selectedOIndex,
                onBuyX: _buyXColor,
                onBuyO: _buyOColor,
                busy: _busy,
              ),
              AvatarStoreTab(
                ownedAvatars: _ownedAvatars,
                equippedAvatar: _equippedAvatar,
                busy: _busy,
                onBuyAvatar: _buyAvatar,
                onEquipAvatar: _equipAvatar,
              ),
              const CoinsScreen(),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return content;

    return Scaffold(
      body: SafeArea(
        child: AppBackground(
          variant: AppBackgroundVariant.homeNeon,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  children: [
                    AppIconButton(
                        icon: Icons.arrow_back,
                        onTap: () => navigateToHomeHub(context)),
                    const Spacer(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _storeHeaderTitle(),
                      style: titleFont(context).copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _storeHeaderSubtitle(),
                      style: bodyFont(context).copyWith(
                        fontSize: 13,
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorsTab extends StatelessWidget {
  final List<int> ownedX;
  final List<int> ownedO;
  final int selectedXIndex;
  final int selectedOIndex;

  final Future<void> Function(int) onBuyX;
  final Future<void> Function(int) onBuyO;

  final bool busy;

  const _ColorsTab({
    required this.ownedX,
    required this.ownedO,
    required this.selectedXIndex,
    required this.selectedOIndex,
    required this.onBuyX,
    required this.onBuyO,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          _ColorSection(
            isX: true,
            title: 'X COLORS',
            ownedCount: ownedX.length,
            totalCount: NeonColors.xColors.length + 1,
            owned: ownedX.toSet(),
            selectedIndex: selectedXIndex,
            colors: NeonColors.xColors,
            onTap: (i) => busy ? null : () => onBuyX(i),
          ),
          const SizedBox(height: 20),
          _ColorSection(
            isX: false,
            title: 'O COLORS',
            ownedCount: ownedO.length,
            totalCount: NeonColors.oColors.length + 1,
            owned: ownedO.toSet(),
            selectedIndex: selectedOIndex,
            colors: NeonColors.oColors,
            onTap: (i) => busy ? null : () => onBuyO(i),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _ColorSection extends StatelessWidget {
  final String title;
  final int ownedCount;
  final int totalCount;
  final bool isX;
  final Set<int> owned;

  final int selectedIndex;
  final List<Color> colors;
  final VoidCallback? Function(int) onTap;

  const _ColorSection({
    required this.title,
    required this.ownedCount,
    required this.totalCount,
    required this.isX,
    required this.owned,
    required this.selectedIndex,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isX ? AppPalette.homeCyan : AppPalette.accentPurple;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.30),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(title,
                style: safeOrbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                    color: accent)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withOpacity(0.22)),
              ),
              child: Text(
                '$ownedCount/$totalCount',
                style: safeOrbitron(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent.withOpacity(0.32), Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: colors.length,
          itemBuilder: (context, i) {
            return _ColorTile(
              index: i,
              isX: isX,
              color: colors[i],
              isOwned: owned.contains(i),
              isSelected: i == selectedIndex,
              onTap: onTap(i),
            );
          },
        ),
      ],
    );
  }
}

class _ColorTile extends StatelessWidget {
  final int index;
  final bool isX;
  final Color color;
  final bool isOwned;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ColorTile({
    required this.index,
    required this.isX,
    required this.color,
    required this.isOwned,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(
                  AppPalette.panelElevated, color, isOwned ? 0.12 : 0.04)!,
              AppPalette.panelDeep,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? color.withOpacity(0.80)
                : (isOwned
                    ? color.withValues(alpha: 0.42)
                    : AppPalette.homeStroke.withOpacity(0.16)),
            width: isOwned || isSelected ? 1.5 : 1,
          ),
          boxShadow: isOwned || isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: isSelected ? 0.26 : 0.18),
                    blurRadius: 16,
                    spreadRadius: -2,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            SizedBox(
              width: 44,
              height: 44,
              child: isX
                  ? CustomPaint(painter: GlowXPainter(color: color))
                  : CustomPaint(painter: GlowOPainter(color: color)),
            ),
            const SizedBox(height: 8),
            if (isOwned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isSelected ? color : AppPalette.success)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: (isSelected ? color : AppPalette.success),
                      width: 0.5),
                ),
                child: Text(isSelected ? 'SELECTED' : 'OWNED',
                    style: safeOrbitron(
                        fontSize: 8,
                        color: isSelected ? color : AppPalette.success,
                        fontWeight: FontWeight.w700)),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/coin/COIN.png',
                    height: 14,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${priceForColorIndex(index)}',
                    style: safeOrbitron(
                        fontSize: 10,
                        color: const Color(0xFFFFD700),
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class GlowXPainter extends CustomPainter {
  final Color color;

  const GlowXPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final main = Paint()
      ..shader = LinearGradient(
              colors: [color, Color.lerp(color, Colors.white, 0.18)!])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final p = size.width * 0.18;
    canvas.drawLine(
        Offset(p, p), Offset(size.width - p, size.height - p), glow);
    canvas.drawLine(
        Offset(size.width - p, p), Offset(p, size.height - p), glow);
    canvas.drawLine(
        Offset(p, p), Offset(size.width - p, size.height - p), main);
    canvas.drawLine(
        Offset(size.width - p, p), Offset(p, size.height - p), main);
  }

  @override
  bool shouldRepaint(covariant GlowXPainter oldDelegate) =>
      oldDelegate.color != color;
}

class GlowOPainter extends CustomPainter {
  final Color color;

  const GlowOPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final main = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.33, glow);
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.33, main);
  }

  @override
  bool shouldRepaint(covariant GlowOPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _StoreTabBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabSelected;

  const _StoreTabBar(
      {required this.selectedIndex, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    Widget tab(int index, String label) {
      final selected = selectedIndex == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => onTabSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppPalette.homeSky, AppPalette.homeBlue],
                    )
                  : null,
              color: selected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppPalette.homeStrokeStrong.withOpacity(0.70)
                    : Colors.transparent,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppPalette.homeSky.withOpacity(0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: safeOrbitron(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppPalette.textSubtle,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppPalette.panelElevated.withOpacity(0.96),
            AppPalette.panelDeep.withOpacity(0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.homeStroke.withOpacity(0.26)),
      ),
      child: Row(
        children: [
          tab(0, 'X & O COLORS'),
          tab(1, 'AVATARS'),
          tab(2, 'BUY COINS'),
        ],
      ),
    );
  }
}

/// ==========================
///   COINS HISTORY PAGE
/// ==========================
class CoinsHistoryPage extends StatefulWidget {
  const CoinsHistoryPage({super.key});

  @override
  State<CoinsHistoryPage> createState() => _CoinsHistoryPageState();
}

class _CoinsHistoryPageState extends State<CoinsHistoryPage> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final history = await LocalStore.getTopupHistory();
      if (mounted) {
        setState(() {
          _history = history;
          _loading = false;
        });
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CoinsHistoryPage] _loadHistory error: $e');
        debugPrint('[CoinsHistoryPage] $st');
      }
      if (mounted) {
        setState(() {
          _loadError = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
    final timeFormat = DateFormat('HH:mm:ss', 'pt_BR');
    return '${dateFormat.format(dt)} ${timeFormat.format(dt)}';
  }

  String _defaultDescription(String type) {
    switch (type) {
      case 'win':
        return 'Game Win';
      case 'recharge':
        return 'Coin Purchase';
      case 'loss':
        return 'Game Entry';
      default:
        return 'Transaction';
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCredits = _history
        .where((entry) =>
            (entry['type'] as String? ?? 'loss') == 'win' ||
            (entry['type'] as String? ?? 'loss') == 'recharge')
        .fold<int>(0, (sum, entry) => sum + (entry['coins'] as int).abs());
    final totalDebits = _history.where((entry) {
      final type = entry['type'] as String? ?? 'loss';
      return type != 'win' && type != 'recharge';
    }).fold<int>(0, (sum, entry) => sum + (entry['coins'] as int).abs());

    return Scaffold(
      body: SafeArea(
        child: AppBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => navigateToHomeHub(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "COIN HISTORY",
                        style: titleFont(context).copyWith(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: _ModeHeroCard(
                  eyebrow: 'ARENA LEDGER',
                  title: 'TRANSACTION FLOW',
                  subtitle:
                      'Review purchases, entry fees, and reward payouts with live balance transitions.',
                  chips: [
                    _ModeInfoChip(
                      icon: Icons.receipt_long_rounded,
                      label: '${_history.length} ENTRIES',
                      color: AppPalette.primary,
                    ),
                  ],
                  trailing: SizedBox(
                    width: 176,
                    child: Column(
                      children: [
                        _SummaryMetricTile(
                          icon: Icons.arrow_upward_rounded,
                          label: 'CREDITS',
                          value: '+$totalCredits',
                          accent: AppPalette.success,
                        ),
                        const SizedBox(height: 10),
                        _SummaryMetricTile(
                          icon: Icons.arrow_downward_rounded,
                          label: 'DEBITS',
                          value: '-$totalDebits',
                          accent: AppPalette.danger,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? Center(
                        child: AppGlassCard(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                  color: AppPalette.primary),
                              const SizedBox(height: 16),
                              Text(
                                'Loading history feed...',
                                style: bodyFont(context),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _loadError != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: AppGlassCard(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.cloud_off_rounded,
                                      size: 36,
                                      color: AppPalette.danger,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "Could not load transaction history.",
                                      style: bodyFont(context),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _loadError!,
                                      style: bodyFont(context).copyWith(
                                          color: AppPalette.textMuted),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    AppPillButton(
                                      label: 'Retry',
                                      onPressed: _loadHistory,
                                      icon: Icons.refresh,
                                      fill: AppPalette.primary
                                          .withValues(alpha: 0.7),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : _history.isEmpty
                            ? Center(
                                child: AppGlassCard(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.payments_outlined,
                                        size: 34,
                                        color: AppPalette.goldHighlight,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        "No transactions yet",
                                        style: titleFont(context)
                                            .copyWith(fontSize: 18),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Coin purchases, match fees, and rewards will appear here once activity starts.",
                                        textAlign: TextAlign.center,
                                        style: bodyFont(context),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 0, 14, 16),
                                child: Column(
                                  children: _history.map((entry) {
                                    final type =
                                        entry['type'] as String? ?? 'loss';
                                    final coins = (entry['coins'] as int).abs();
                                    final dateTime =
                                        entry['dateTime'] as DateTime;
                                    final balanceBefore =
                                        entry['balanceBefore'] as int?;
                                    final balanceAfter =
                                        entry['balanceAfter'] as int?;
                                    final description =
                                        entry['description'] as String?;

                                    final isPositive =
                                        type == 'win' || type == 'recharge';
                                    const greenColor = Color(0xFF4ADE80);
                                    const redColor = Color(0xFFF87171);
                                    final accentColor =
                                        isPositive ? greenColor : redColor;

                                    // Derive description label from type if not provided
                                    final label = description ??
                                        _defaultDescription(type);

                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: AppGlassCard(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        borderColor:
                                            accentColor.withValues(alpha: 0.26),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    accentColor.withValues(
                                                        alpha: 0.18),
                                                    AppPalette.panelDeep
                                                        .withValues(
                                                            alpha: 0.98),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: accentColor.withValues(
                                                      alpha: 0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Image.asset(
                                                    'assets/coin/COIN.png',
                                                    width: 26,
                                                    height: 26,
                                                  ),
                                                  Positioned(
                                                    right: 5,
                                                    bottom: 5,
                                                    child: Icon(
                                                      isPositive
                                                          ? Icons.arrow_upward
                                                          : Icons
                                                              .arrow_downward,
                                                      color: accentColor,
                                                      size: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          label,
                                                          style: safeOrbitron(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Colors.white,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      _TinyBadge(
                                                        text: isPositive
                                                            ? 'CREDIT'
                                                            : 'DEBIT',
                                                        color: accentColor,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Text(
                                                        '${isPositive ? '+' : '-'}$coins',
                                                        style: safeOrbitron(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: accentColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    _formatDateTime(dateTime),
                                                    style: bodyFont(context)
                                                        .copyWith(
                                                      fontSize: 12,
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                  if (balanceBefore != null &&
                                                      balanceAfter != null) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Balance: $balanceBefore \u2192 $balanceAfter',
                                                      style: safeInter(
                                                        fontSize: 11,
                                                        color: AppPalette
                                                            .textSubtle,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ==========================
///   VAULT (APPLY PIECE COLORS ONLY)
/// ==========================
class VaultPage extends StatefulWidget {
  final bool embedded;
  const VaultPage({super.key, this.embedded = false});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  List<int> _ownedX = [];
  List<int> _ownedO = [];
  bool _busy = false;
  int? _selectedXIndex;
  int? _selectedOIndex;
  @override
  void initState() {
    super.initState();
    _load();
    LocalStore.cosmeticsVersion.addListener(_onCosmeticsChanged);
  }

  @override
  void dispose() {
    LocalStore.cosmeticsVersion.removeListener(_onCosmeticsChanged);
    super.dispose();
  }

  void _onCosmeticsChanged() {
    _load();
  }

  Future<void> _load() async {
    _ownedX = await LocalStore.ownedXColors();
    _ownedO = await LocalStore.ownedOColors();
    // Load current selected colors and find their indices
    final currentXColor = await LocalStore.xPieceColor();
    final currentOColor = await LocalStore.oPieceColor();

    _selectedXIndex =
        NeonColors.xColors.indexWhere((c) => c.value == currentXColor.value);
    if (_selectedXIndex == -1) _selectedXIndex = null;

    _selectedOIndex =
        NeonColors.oColors.indexWhere((c) => c.value == currentOColor.value);
    if (_selectedOIndex == -1) _selectedOIndex = null;

    if (mounted) setState(() {});
  }

  Future<void> _applyX(int i) async {
    if (_busy) return;
    setState(() => _busy = true);
    await LocalStore.setXPieceColor(NeonColors.xColors[i]);
    setState(() {
      _selectedXIndex = i;
      _busy = false;
    });
    if (!mounted) return;
    showTopNotification(context, "X color applied!", color: AppPalette.success);
  }

  Future<void> _applyO(int i) async {
    if (_busy) return;
    setState(() => _busy = true);
    await LocalStore.setOPieceColor(NeonColors.oColors[i]);
    setState(() {
      _selectedOIndex = i;
      _busy = false;
    });
    if (!mounted) return;
    showTopNotification(context, "O color applied!", color: AppPalette.success);
  }

  @override
  Widget build(BuildContext context) {
    final scrollContent = Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.embedded) ...[
              _ModeHeroCard(
                eyebrow: 'LOADOUT',
                title: 'ARENA INVENTORY',
                subtitle:
                    'Apply any owned neon symbol skin instantly while keeping your selected cosmetics wired to the existing store state.',
                chips: [
                  _ModeInfoChip(
                    icon: Icons.close_rounded,
                    label: '${_ownedX.length} X COLORS',
                    color: AppPalette.primary,
                  ),
                  _ModeInfoChip(
                    icon: Icons.radio_button_unchecked_rounded,
                    label: '${_ownedO.length} O COLORS',
                    color: AppPalette.goldHighlight,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            AppGlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: AppPalette.strokeSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                          "X COLORS (${_ownedX.length}/${NeonColors.xColors.length})",
                          style: sectionFont(context)),
                      const Spacer(),
                      _TinyBadge(
                        text: _selectedXIndex == null ? 'NONE' : 'EQUIPPED',
                        color: AppPalette.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          ((MediaQuery.of(context).size.width - 28) / 84)
                              .floor()
                              .clamp(3, 5),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _ownedX.length,
                    itemBuilder: (context, index) {
                      if (index < _ownedX.length) {
                        final i = _ownedX[index];
                        final c = NeonColors.xColors[i];
                        return _VaultTile(
                          color: c,
                          isX: true,
                          isSelected: _selectedXIndex == i,
                          onTap: _busy ? null : () => _applyX(i),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppGlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: AppPalette.strokeSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text("O COLORS (${_ownedO.length})",
                          style: sectionFont(context)),
                      const Spacer(),
                      _TinyBadge(
                        text: _selectedOIndex == null ? 'NONE' : 'EQUIPPED',
                        color: AppPalette.goldHighlight,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          ((MediaQuery.of(context).size.width - 28) / 84)
                              .floor()
                              .clamp(3, 5),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _ownedO.length,
                    itemBuilder: (context, index) {
                      if (index < _ownedO.length) {
                        final i = _ownedO[index];
                        final c = NeonColors.oColors[i];
                        return _VaultTile(
                          color: c,
                          isX: false,
                          isSelected: _selectedOIndex == i,
                          onTap: _busy ? null : () => _applyO(i),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return Column(children: [scrollContent]);
    }

    return Scaffold(
      body: SafeArea(
        child: AppBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  children: [
                    AppIconButton(
                        icon: Icons.arrow_back,
                        onTap: () => navigateToHomeHub(context)),
                    const SizedBox(width: 12),
                    Text("INVENTORY",
                        style: titleFont(context).copyWith(fontSize: 18)),
                  ],
                ),
              ),
              scrollContent,
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultTile extends StatelessWidget {
  final Color color;
  final bool isX;
  final bool isSelected;
  final VoidCallback? onTap;

  const _VaultTile({
    required this.color,
    required this.isX,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderOpacity = isSelected ? 1.0 : 0.4;
    final borderWidth = isSelected ? 2.5 : 1.2;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppPalette.panelSoft.withValues(alpha: 0.95),
              AppPalette.panelDeep.withValues(alpha: 0.98),
            ],
          ),
          border: Border.all(
            color: color.withValues(alpha: borderOpacity),
            width: borderWidth,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 12,
                    spreadRadius: -4,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 10,
                    spreadRadius: -6,
                  ),
                ],
        ),
        child: Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: isX
                ? CustomPaint(painter: GlowXPainter(color: color))
                : CustomPaint(painter: GlowOPainter(color: color)),
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final bool embedded;
  const SettingsPage({super.key, this.embedded = false});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  String _username = "PLAYER";
  String _email = "";
  String _provider = "email"; // "email" or "google"
  int _games = 0, _wins = 0, _losses = 0, _draws = 0;
  int _coins = 0;
  int _lastLevel = 1;
  int _completions = 0;
  int _equippedAvatar = 1;
  bool _editingName = false;
  bool _dangerExpanded = false;
  bool _isMusicEnabled = true;
  double _musicVolume = 0.7;

  // Username editing
  final TextEditingController _usernameController = TextEditingController();
  late final AnimationController _headerFadeController;
  late final Animation<double> _headerFade;

  // Delete account reason state
  String? _deleteReason;
  String _otherReasonText = "";
  bool _showOtherTextField = false;

  @override
  void initState() {
    super.initState();
    _headerFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _headerFade =
        CurvedAnimation(parent: _headerFadeController, curve: Curves.easeOut);
    _load();
    _headerFadeController.forward();
  }

  @override
  void dispose() {
    _headerFadeController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = AuthService().currentUser?.uid;
    if (uid != null) {
      try {
        await UserRepo().pullServerToLocal(uid);
        // Load provider from Firestore
        final firestore = FirebaseFirestore.instance;
        final userDoc = await firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null) {
            final profile = data['Profile'] as Map<String, dynamic>?;
            if (profile != null) {
              _provider = profile['provider'] as String? ?? 'email';
            }
          }
        }
      } catch (_) {}
    }
    final p = await SharedPreferences.getInstance();
    setState(() {
      _username = (p.getString(Keys.username) ?? "PLAYER").toUpperCase();
      _email = p.getString(Keys.email) ?? "";
      _games = p.getInt(Keys.gamesPlayed) ?? 0;
      _wins = p.getInt(Keys.wins) ?? 0;
      _losses = p.getInt(Keys.losses) ?? 0;
      _draws = p.getInt(Keys.draws) ?? 0;
      _coins = p.getInt(Keys.coins) ?? 0;
      _lastLevel = p.getInt(Keys.levelGameCurrentLevel) ?? 1;
      // If level is 0, show 1 (start level)
      if (_lastLevel == 0) _lastLevel = 1;
      _completions = p.getInt(Keys.levelGameCompletions) ?? 0;
      _equippedAvatar = LocalStore.equippedAvatarNotifier.value;
      _isMusicEnabled = SoundService().isMusicEnabled;
      _musicVolume = SoundService().musicVolume;
    });
    _usernameController.text = _username;
  }

  Future<void> _saveName() async {
    final newName = _usernameController.text.trim();
    if (newName.isEmpty) {
      showTopNotification(context, "Name cannot be empty.",
          color: AppPalette.danger);
      return;
    }
    if (newName.length > 20) {
      showTopNotification(context, "Name is too long (max 20 characters).",
          color: AppPalette.danger);
      return;
    }

    final upperName = newName.toUpperCase();
    final p = await SharedPreferences.getInstance();
    await p.setString(Keys.username, upperName);

    final user = AuthService().currentUser;
    if (user != null) {
      try {
        await user.updateDisplayName(upperName);
        await UserRepo().syncToFirestore(user.uid, {
          'Profile': {
            'name': upperName,
          },
        });
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SETTINGS] Failed to update Firebase name: $e');
        }
        // Non-fatal: local name is saved, continue
      }
    }

    setState(() {
      _username = upperName;
      _editingName = false;
    });
    showTopNotification(context, "Name updated!", color: AppPalette.success);
  }

  Future<void> _showAvatarOptions() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    await LocalStore.setProfilePhotoPath(file.path);

    // Upload to Firebase Storage if user is signed in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_photos')
            .child('${user.uid}.jpg');
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        await LocalStore.setProfilePhotoUrl(url);
        await user.updatePhotoURL(url);
      } catch (e) {
        if (kDebugMode) debugPrint('[PHOTO] Upload failed: $e');
      }
    }

    if (mounted)
      setState(() => _equippedAvatar = LocalStore.equippedAvatarNotifier.value);
  }

  void _showChangePasswordDialog() {
    if (_provider == 'google') {
      showTopNotification(
          context, 'Google accounts manage passwords through Google.',
          color: AppPalette.warning);
      return;
    }

    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AppGlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CHANGE PASSWORD',
                      style: safeOrbitron(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.primary,
                          letterSpacing: 2),
                    ),
                    const SizedBox(height: 20),
                    ArenaField(
                      controller: currentPassController,
                      hint: 'CURRENT PASSWORD',
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    const SizedBox(height: 12),
                    ArenaField(
                      controller: newPassController,
                      hint: 'NEW PASSWORD (MIN 6 CHARS)',
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    const SizedBox(height: 12),
                    ArenaField(
                      controller: confirmPassController,
                      hint: 'CONFIRM NEW PASSWORD',
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    const SizedBox(height: 8),
                    if (errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0x20FF3B30),
                          border: Border.all(color: const Color(0x50FF3B30)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFFF3B30), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: safeInter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFFF6B6B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppPillButton(
                            label: 'CANCEL',
                            fill: const Color(0xFF1A1A1A),
                            onPressed: isLoading
                                ? null
                                : () {
                                    currentPassController.dispose();
                                    newPassController.dispose();
                                    confirmPassController.dispose();
                                    Navigator.pop(ctx);
                                  },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppPillButton(
                            label: 'SAVE',
                            loading: isLoading,
                            onPressed: () async {
                              final current = currentPassController.text;
                              final newPass = newPassController.text;
                              final confirm = confirmPassController.text;

                              if (current.isEmpty ||
                                  newPass.isEmpty ||
                                  confirm.isEmpty) {
                                setDialogState(() =>
                                    errorMessage = 'Please fill all fields.');
                                return;
                              }
                              if (newPass.length < 6) {
                                setDialogState(() => errorMessage =
                                    'New password must be at least 6 characters.');
                                return;
                              }
                              if (newPass != confirm) {
                                setDialogState(() =>
                                    errorMessage = 'Passwords do not match.');
                                return;
                              }
                              if (current == newPass) {
                                setDialogState(() => errorMessage =
                                    'New password must be different.');
                                return;
                              }

                              setDialogState(() {
                                isLoading = true;
                                errorMessage = null;
                              });

                              try {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null || user.email == null) {
                                  throw Exception('No user found.');
                                }

                                final credential = EmailAuthProvider.credential(
                                  email: user.email!,
                                  password: current,
                                );

                                await user
                                    .reauthenticateWithCredential(credential);
                                await user.updatePassword(newPass);

                                if (!ctx.mounted) return;
                                currentPassController.dispose();
                                newPassController.dispose();
                                confirmPassController.dispose();
                                Navigator.pop(ctx);
                                showTopNotification(
                                    context, 'Password changed successfully!',
                                    color: AppPalette.success);
                              } on FirebaseAuthException catch (e) {
                                String msg;
                                switch (e.code) {
                                  case 'wrong-password':
                                  case 'invalid-credential':
                                    msg = 'Current password is incorrect.';
                                    break;
                                  case 'weak-password':
                                    msg = 'New password is too weak.';
                                    break;
                                  case 'requires-recent-login':
                                    msg =
                                        'Session expired. Please log out and log in again.';
                                    break;
                                  case 'network-request-failed':
                                    msg = 'No internet connection.';
                                    break;
                                  default:
                                    msg = 'Failed: ${e.message ?? e.code}';
                                }
                                setDialogState(() {
                                  isLoading = false;
                                  errorMessage = msg;
                                });
                              } catch (_) {
                                setDialogState(() {
                                  isLoading = false;
                                  errorMessage =
                                      'An error occurred. Please try again.';
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout, size: 48, color: AppPalette.warning),
                const SizedBox(height: 16),
                Text(
                  "Sign Out",
                  style: titleFont(ctx).copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "End this arena session on this device? Your synced progress will stay on your account.",
                  style: bodyFont(ctx),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        label: "STAY",
                        fill: Colors.white.withOpacity(0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: "SIGN OUT",
                        fill: AppPalette.danger,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _logout();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    // Check online status before logging out
    final isOnline = await ConnectivityService().online;
    if (!isOnline) {
      if (!mounted) return;
      showTopNotification(
        context,
        "You're offline. Please connect to the internet to log out.",
        color: AppPalette.danger,
      );
      return;
    }

    await UserRepo().clearLocalCache();
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        if (kDebugMode) {
          debugPrint('[URL] Failed to open $url');
        }
        if (!mounted) return;
        showTopNotification(context, "Could not open link.",
            color: AppPalette.danger);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[URL] launch exception: $e');
      }
      if (!mounted) return;
      showTopNotification(context, "Could not open link.",
          color: AppPalette.danger);
    }
  }

  Future<void> _contactSupport() async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Contact Support / Refunds",
                    style: titleFont(ctx).copyWith(fontSize: 18)),
                const SizedBox(height: 10),
                Text(
                  AppConfig.refundRulesText,
                  style: bodyFont(ctx),
                ),
                const SizedBox(height: 8),
                Text(
                  "Contact: ${AppConfig.refundEmail}",
                  style: bodyFont(ctx).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                AppPillButton(
                  label: "Send email",
                  fill: Colors.white.withOpacity(0.08),
                  stroke: AppPalette.strokeStrong,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final uri = Uri(
                      scheme: "mailto",
                      path: AppConfig.refundEmail,
                      queryParameters: {
                        "subject": "XO Arena Support / Refund",
                        "body":
                            "Describe your issue here.\n\nAccount email: $_email\nDevice: Android\n",
                      },
                    );
                    if (!await launchUrl(uri,
                        mode: LaunchMode.externalApplication)) {
                      if (!mounted) return;
                      showTopNotification(context, "Mail app not available.",
                          color: AppPalette.danger);
                    }
                  },
                ),
                const SizedBox(height: 8),
                AppPillButton(
                  label: "OK",
                  fill: Colors.white.withOpacity(0.06),
                  stroke: AppPalette.strokeStrong,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountConfirmation() {
    if (!mounted) return;

    // Reset state
    _deleteReason = null;
    _otherReasonText = "";
    _showOtherTextField = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AppGlassCard(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Delete Account",
                        style: titleFont(ctx).copyWith(fontSize: 18)),
                    const SizedBox(height: 10),
                    Text(
                      "This will permanently delete your account and associated data. This action cannot be undone.",
                      style: bodyFont(ctx),
                    ),
                    const SizedBox(height: 16),
                    // Reason selection
                    Text("Please select a reason:", style: sectionFont(ctx)),
                    const SizedBox(height: 8),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: Text("I don't use the app anymore",
                          style: bodyFont(ctx)),
                      value: "I don't use the app anymore",
                      groupValue: _deleteReason,
                      onChanged: (value) {
                        setDialogState(() {
                          _deleteReason = value;
                          _showOtherTextField = false;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: Text("I found a better alternative",
                          style: bodyFont(ctx)),
                      value: "I found a better alternative",
                      groupValue: _deleteReason,
                      onChanged: (value) {
                        setDialogState(() {
                          _deleteReason = value;
                          _showOtherTextField = false;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Too many bugs or crashes",
                          style: bodyFont(ctx)),
                      value: "Too many bugs or crashes",
                      groupValue: _deleteReason,
                      onChanged: (value) {
                        setDialogState(() {
                          _deleteReason = value;
                          _showOtherTextField = false;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Privacy concerns", style: bodyFont(ctx)),
                      value: "Privacy concerns",
                      groupValue: _deleteReason,
                      onChanged: (value) {
                        setDialogState(() {
                          _deleteReason = value;
                          _showOtherTextField = false;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title:
                          Text("I want to start fresh", style: bodyFont(ctx)),
                      value: "I want to start fresh",
                      groupValue: _deleteReason,
                      onChanged: (value) {
                        setDialogState(() {
                          _deleteReason = value;
                          _showOtherTextField = false;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Other (write your reason)",
                          style: bodyFont(ctx)),
                      value: "Other",
                      groupValue: _deleteReason,
                      onChanged: (value) {
                        setDialogState(() {
                          _deleteReason = value;
                          _showOtherTextField = true;
                        });
                      },
                    ),
                    // Other reason text field
                    if (_showOtherTextField) ...[
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: "Please describe your reason...",
                          hintStyle: bodyFont(ctx)
                              .copyWith(color: AppPalette.textMuted),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppPalette.radiusSmall),
                            borderSide: BorderSide(color: AppPalette.stroke),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppPalette.radiusSmall),
                            borderSide: BorderSide(color: AppPalette.stroke),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppPalette.radiusSmall),
                            borderSide: BorderSide(color: AppPalette.primary),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                        ),
                        style: bodyFont(ctx),
                        maxLines: 3,
                        onChanged: (value) {
                          _otherReasonText = value;
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppPillButton(
                      label: "Confirm Delete",
                      fill: AppPalette.danger.withOpacity(0.90),
                      onPressed: () {
                        // Validation
                        if (_deleteReason == null) {
                          showTopNotification(ctx, "Please select a reason.",
                              color: AppPalette.danger);
                          return;
                        }
                        if (_deleteReason == "Other" &&
                            _otherReasonText.trim().isEmpty) {
                          showTopNotification(
                              ctx, "Please describe your reason.",
                              color: AppPalette.danger);
                          return;
                        }

                        Navigator.pop(ctx);
                        final details = _deleteReason == "Other"
                            ? _otherReasonText.trim()
                            : null;
                        _deleteAccount(
                            reason: _deleteReason!, details: details);
                      },
                      icon: Icons.delete_forever,
                    ),
                    const SizedBox(height: 8),
                    AppPillButton(
                      label: "CANCEL",
                      fill: Colors.white.withOpacity(0.08),
                      stroke: AppPalette.strokeStrong,
                      onPressed: () => Navigator.pop(ctx),
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

  // Check if deletion is locked
  Future<bool> _isDeletionLocked() async {
    final p = await SharedPreferences.getInstance();
    final lockedUntil = p.getInt(Keys.deleteLockedUntil);
    if (lockedUntil == null) return false;

    final lockedUntilDate = DateTime.fromMillisecondsSinceEpoch(lockedUntil);
    if (DateTime.now().isBefore(lockedUntilDate)) {
      return true; // Still locked
    } else {
      // Lock expired - reset
      await p.remove(Keys.deleteLockedUntil);
      await p.setInt(Keys.deleteAttempts, 0);
      await p.remove(Keys.deleteLastAttempt);
      return false;
    }
  }

  // Get lock message
  Future<String?> _getLockMessage() async {
    final p = await SharedPreferences.getInstance();
    final lockedUntil = p.getInt(Keys.deleteLockedUntil);
    if (lockedUntil == null) return null;

    final lockedUntilDate = DateTime.fromMillisecondsSinceEpoch(lockedUntil);
    if (DateTime.now().isBefore(lockedUntilDate)) {
      final remaining = lockedUntilDate.difference(DateTime.now());
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes % 60;
      return "Account deletion is locked. Please try again after ${hours}h ${minutes}m";
    }
    return null;
  }

  // Increment failed attempts
  Future<void> _incrementDeleteAttempts() async {
    final p = await SharedPreferences.getInstance();
    final attempts = (p.getInt(Keys.deleteAttempts) ?? 0) + 1;
    await p.setInt(Keys.deleteAttempts, attempts);
    await p.setInt(
        Keys.deleteLastAttempt, DateTime.now().millisecondsSinceEpoch);

    if (attempts >= 3) {
      // Lock for 24 hours
      final lockedUntil = DateTime.now().add(const Duration(hours: 24));
      await p.setInt(
          Keys.deleteLockedUntil, lockedUntil.millisecondsSinceEpoch);
    }
  }

  // Reset delete attempts (on success)
  Future<void> _resetDeleteAttempts() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(Keys.deleteAttempts, 0);
    await p.remove(Keys.deleteLastAttempt);
    await p.remove(Keys.deleteLockedUntil);
  }

  Future<void> _deleteAccount({required String reason, String? details}) async {
    if (!mounted) return;

    // Check if deletion is locked
    if (await _isDeletionLocked()) {
      final lockMessage = await _getLockMessage();
      if (lockMessage != null) {
        showTopNotification(context, lockMessage, color: AppPalette.danger);
      }
      return;
    }

    // Request password FIRST (before any deletion)
    final password = await _showPasswordDialog();
    if (password == null || password.isEmpty) {
      return; // User cancelled
    }

    // Now proceed with deletion using password
    await _deleteAccountWithPassword(
        reason: reason, details: details, password: password);
  }

  Future<String?> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AppGlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 48, color: AppPalette.warning),
                  const SizedBox(height: 16),
                  Text(
                    "Confirm Password",
                    style: safeOrbitron(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "For security, please enter your password to confirm account deletion.",
                    textAlign: TextAlign.center,
                    style: bodyFont(ctx).copyWith(height: 1.3),
                  ),
                  const SizedBox(height: 20),
                  ArenaField(
                    controller: passwordController,
                    hint: 'PASSWORD',
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: AppPillButton(
                          label: "CANCEL",
                          fill: Colors.white.withOpacity(0.08),
                          stroke: AppPalette.strokeStrong,
                          onPressed: () => Navigator.pop(ctx, null),
                          icon: Icons.close,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppPillButton(
                          label: "CONFIRM",
                          fill: AppPalette.danger.withOpacity(0.9),
                          onPressed: () {
                            Navigator.pop(ctx, passwordController.text);
                          },
                          icon: Icons.check,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccountWithPassword({
    required String reason,
    String? details,
    required String password,
  }) async {
    if (!mounted) return;

    if (kDebugMode) {
      debugPrint(
          '[DELETE] reason=$reason${details != null ? ", details=$details" : ""}');
    }

    final isOnline = await ConnectivityService().online;
    if (!isOnline) {
      showTopNotification(
          context, "Please connect to the internet to delete your account.",
          color: AppPalette.danger);
      return;
    }

    // Save deletion reason feedback (NON-FATAL, merged into ghost record by AuthService)
    final uid = AuthService().currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('deletion_feedback')
            .doc(uid)
            .set({
          'reason': reason,
          if (details != null) 'details': details,
        }, SetOptions(merge: true));
        if (kDebugMode) {
          debugPrint('[DELETE] Feedback saved to Firestore');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[DELETE] Failed to save feedback (non-fatal): $e');
        }
      }
    }

    // Show loading dialog with purge message
    _showDeletionLoadingDialog();

    try {
      await AuthService().deleteAccountAndData(password: password);

      await _resetDeleteAttempts();

      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      showTopNotification(context, "Account deleted successfully.",
          color: AppPalette.success);

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } on RequiresReauthException {
      // Firestore data already wiped — need re-auth to delete Auth account
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      await _handleReauthForDeletion();
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      String errorMessage;
      if (e is Exception) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      } else {
        errorMessage = e.toString();
      }

      if (errorMessage.contains('Incorrect password') ||
          errorMessage.contains('wrong-password') ||
          errorMessage.contains('invalid-credential')) {
        await _incrementDeleteAttempts();

        if (await _isDeletionLocked()) {
          final lockMessage = await _getLockMessage();
          errorMessage = lockMessage ??
              "Too many failed attempts. Account deletion is locked for 24 hours.";
        } else {
          final p = await SharedPreferences.getInstance();
          final attempts = p.getInt(Keys.deleteAttempts) ?? 0;
          final remaining = 3 - attempts;
          errorMessage = "Incorrect password. $remaining attempts remaining.";
        }
      } else if (errorMessage.contains('internet') ||
          errorMessage.contains('network') ||
          errorMessage.contains('connect to the internet')) {
        errorMessage = "Please check your internet connection and try again.";
      } else if (errorMessage.contains('Firestore') ||
          errorMessage.contains('Permission denied') ||
          errorMessage.contains('deletion failed')) {
        errorMessage =
            "Could not delete account data. Please contact support if this persists.";
      } else {
        errorMessage = "Could not delete account. Please try again.";
      }

      showTopNotification(context, errorMessage, color: AppPalette.danger);
    }
  }

  void _showDeletionLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  "Wiping all your data from our servers...",
                  textAlign: TextAlign.center,
                  style: bodyFont(ctx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Handle re-authentication when Firebase Auth requires recent login.
  Future<void> _handleReauthForDeletion() async {
    if (!mounted) return;

    final user = AuthService().currentUser;
    if (user == null) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }

    final isGoogle = user.providerData.any((p) => p.providerId == 'google.com');

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.security, size: 48, color: AppPalette.warning),
                const SizedBox(height: 16),
                Text(
                  "Security Check",
                  style: safeOrbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please log in one last time to confirm account deletion.",
                  textAlign: TextAlign.center,
                  style: bodyFont(ctx).copyWith(height: 1.3),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        label: "CANCEL",
                        fill: Colors.white.withOpacity(0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.pop(ctx, false),
                        icon: Icons.close,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: isGoogle ? "SIGN IN" : "CONFIRM",
                        fill: AppPalette.danger.withOpacity(0.9),
                        onPressed: () => Navigator.pop(ctx, true),
                        icon: isGoogle ? Icons.account_circle : Icons.check,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      if (isGoogle) {
        await AuthService().reauthenticateWithGoogle();
      } else {
        final password = await _showPasswordDialog();
        if (password == null || password.isEmpty) return;
        await AuthService().reauthenticateWithPassword(password);
      }

      _showDeletionLoadingDialog();
      await AuthService().deleteAuthOnly();
      await _resetDeleteAttempts();

      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      showTopNotification(context, "Account deleted successfully.",
          color: AppPalette.success);
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      showTopNotification(
          context, "Re-authentication failed. Please try again.",
          color: AppPalette.danger);
    }
  }

  void _showPolicies() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("PRIVACY & TERMS",
                    style: titleFont(ctx).copyWith(fontSize: 18)),
                const SizedBox(height: 10),
                Text(
                  "We store: name + email + (age optional) + stats + coins + transactions\n\n"
                  "No cash-out, no real rewards, and no money transfers\n\n"
                  "Coins are for in-game use only\n\n"
                  "Any purchases, if offered, are processed through the platform's official billing system.\n\n"
                  "There is a Delete Account option in Settings, which permanently deletes the data\n\n"
                  "Contact: ${AppConfig.supportEmail}",
                  style: bodyFont(ctx),
                ),
                const SizedBox(height: 16),
                // Privacy Policy link
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  leading: const Icon(Icons.privacy_tip_outlined,
                      color: AppPalette.primary),
                  title: Text("Privacy Policy",
                      style:
                          bodyFont(ctx).copyWith(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.open_in_new,
                      size: 18, color: AppPalette.textMuted),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openUrl(AppConfig.privacyPolicyUrl);
                  },
                ),
                // Terms link
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  leading: const Icon(Icons.description_outlined,
                      color: AppPalette.primary),
                  title: Text("Terms",
                      style:
                          bodyFont(ctx).copyWith(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.open_in_new,
                      size: 18, color: AppPalette.textMuted),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openUrl(AppConfig.termsUrl);
                  },
                ),
                // Delete Account Info link
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  leading: const Icon(Icons.delete_forever_outlined,
                      color: AppPalette.danger),
                  title: Text("Delete Account Info",
                      style:
                          bodyFont(ctx).copyWith(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.open_in_new,
                      size: 18, color: AppPalette.textMuted),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openUrl(AppConfig.accountDeletionUrl);
                  },
                ),
                const SizedBox(height: 14),
                AppPillButton(
                  label: "OK",
                  fill: Colors.white.withOpacity(0.08),
                  stroke: AppPalette.strokeStrong,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Row(
      children: [
        Text(
          text,
          style: safeOrbitron(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppPalette.goldHighlight,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: AppPalette.strokeSoft)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollContent = Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        child: Column(
          children: [
            FadeTransition(
              opacity: _headerFade,
              child: ValueListenableBuilder<int>(
                valueListenable: LocalStore.equippedAvatarNotifier,
                builder: (_, avatarId, __) {
                  final avatar = gameAvatarById(avatarId);
                  return _ProfileHeader(
                    username: _username,
                    email: _email,
                    provider: _provider,
                    games: _games,
                    wins: _wins,
                    losses: _losses,
                    draws: _draws,
                    topLevel: _lastLevel,
                    avatar: avatar,
                    editingName: _editingName,
                    usernameController: _usernameController,
                    onCameraTap: _showAvatarOptions,
                    onEditName: () => setState(() => _editingName = true),
                    onCancelEdit: () {
                      _usernameController.text = _username;
                      setState(() => _editingName = false);
                    },
                    onSaveName: _saveName,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            AppGlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: AppPalette.strokeSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.music_note_rounded,
                          color: AppPalette.primary, size: 16),
                      const SizedBox(width: 8),
                      Text('MUSIC',
                          style: safeOrbitron(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.goldHighlight,
                              letterSpacing: 2)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.music_note_outlined,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('MUSIC',
                                    style: safeOrbitron(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                                const Spacer(),
                                Switch(
                                  value: _isMusicEnabled,
                                  activeColor: AppPalette.primary,
                                  onChanged: (val) async {
                                    setState(() => _isMusicEnabled = val);
                                    await SoundService().setMusicEnabled(val);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_isMusicEnabled) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.volume_down,
                            color: Color(0xFF888888), size: 14),
                        Expanded(
                          child: SliderTheme(
                            data: const SliderThemeData(
                              activeTrackColor: AppPalette.primary,
                              inactiveTrackColor: AppPalette.strokeSoft,
                              thumbColor: AppPalette.goldHighlight,
                              overlayColor: Color(0x2058D8FF),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _musicVolume,
                              min: 0.0,
                              max: 1.0,
                              onChanged: (val) async {
                                setState(() => _musicVolume = val);
                                await SoundService().setMusicVolume(val);
                              },
                            ),
                          ),
                        ),
                        const Icon(Icons.volume_up,
                            color: Color(0xFF888888), size: 14),
                        const SizedBox(width: 4),
                        Text('${(_musicVolume * 100).toInt()}%',
                            style: safeOrbitron(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppPalette.goldHighlight)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppGlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: AppPalette.strokeSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('ACCOUNT'),
                  const SizedBox(height: 10),
                  _SettingTile(
                    icon: Icons.lock_outline,
                    label: 'Change Password',
                    subtitle: 'Update your login password',
                    onTap: _showChangePasswordDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppGlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: AppPalette.strokeSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('SUPPORT & LEGAL'),
                  const SizedBox(height: 10),
                  _SettingTile(
                    icon: Icons.support_agent_outlined,
                    label: 'Contact Support',
                    subtitle: 'Reach the XO ARENA support team',
                    onTap: _contactSupport,
                  ),
                  const SizedBox(height: 8),
                  _SettingTile(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    subtitle: 'Read how your data is handled',
                    onTap: () => _openUrl(AppConfig.privacyPolicyUrl),
                  ),
                  const SizedBox(height: 8),
                  _SettingTile(
                    icon: Icons.description_outlined,
                    label: 'Terms of Service',
                    subtitle: 'Game rules and legal terms',
                    onTap: () => _openUrl(AppConfig.termsUrl),
                  ),
                  const SizedBox(height: 8),
                  _SettingTile(
                    icon: Icons.delete_forever_outlined,
                    label: 'Account Deletion Info',
                    subtitle: 'Learn what gets removed permanently',
                    onTap: () => _openUrl(AppConfig.accountDeletionUrl),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _DangerZoneCard(
              expanded: _dangerExpanded,
              onToggle: () =>
                  setState(() => _dangerExpanded = !_dangerExpanded),
              onDelete: _showDeleteAccountConfirmation,
            ),
            const SizedBox(height: 24),
            _PremiumLogoutCard(onTap: _showLogoutConfirmDialog),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return Column(children: [scrollContent]);
    }

    return Scaffold(
      body: SafeArea(
        child: AppBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final coinWidth = clampDouble(
                      constraints.maxWidth * 0.34,
                      128.0,
                      156.0,
                    );
                    final titleWidth = max(
                      0.0,
                      constraints.maxWidth - coinWidth - 66.0,
                    );
                    final coinWidget = GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StorePage(initialTab: 2),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: coinWidth,
                        child: ValueListenableBuilder<int>(
                          valueListenable: LocalStore.coinsNotifier,
                          builder: (_, coins, __) => CoinPill(
                            coins: coins,
                            width: coinWidth,
                          ),
                        ),
                      ),
                    );

                    if (constraints.maxWidth < 360) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AppIconButton(
                                icon: Icons.arrow_back,
                                onTap: () => navigateToHomeHub(context),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: max(0.0, constraints.maxWidth - 56.0),
                                child: Text(
                                  "SETTINGS",
                                  style: titleFont(context).copyWith(fontSize: 18),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          coinWidget,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        AppIconButton(
                          icon: Icons.arrow_back,
                          onTap: () => navigateToHomeHub(context),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: titleWidth,
                          child: Text(
                            "SETTINGS",
                            style: titleFont(context).copyWith(fontSize: 18),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        coinWidget,
                      ],
                    );
                  },
                ),
              ),
              scrollContent,
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Text(
            value.toString(),
            style: safeOrbitron(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: safeOrbitron(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingTile(
      {required this.icon,
      required this.label,
      this.subtitle,
      this.trailing,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppPalette.panelSoft.withValues(alpha: 0.95),
                AppPalette.panelDeep.withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(color: AppPalette.strokeSoft),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppPalette.primary.withValues(alpha: 0.18),
                      AppPalette.accentPurple.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppPalette.strokeStrong, width: 0.7),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: safeOrbitron(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: safeInter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppPalette.textSubtle),
                      ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: AppPalette.primary),
            ],
          ),
        ),
      ),
    );
  }
}
