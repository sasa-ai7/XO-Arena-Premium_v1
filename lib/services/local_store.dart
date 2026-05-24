import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';
import '../core/keys.dart';
import '../core/neon_colors.dart';
import '../models/game_avatar.dart';
import '../models/offline_profile.dart';
import '../models/user_data.dart';
import '../services/app_mode_service.dart';
import '../services/arena/arena_cosmetics_loader.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/user_repo.dart';

class LocalStore {
  static Future<SharedPreferences> _p() => SharedPreferences.getInstance();
  static String? get _uid => AuthService().currentUser?.uid;

  /// Public accessor for the current user's UID (null if not signed in).
  static String? get uid => _uid;

  /// Reactive coin balance — screens listen to this for real-time updates.
  static final ValueNotifier<int> coinsNotifier = ValueNotifier<int>(0);

  /// Bumped whenever owned cosmetics change (purchase or equip).
  /// StorePage listens to this so it reloads updated ownership on tab return.
  static final ValueNotifier<int> cosmeticsVersion = ValueNotifier<int>(0);

  /// Reactive equipped avatar id - Top Bar and Profile listen to this.
  /// 0 = no avatar equipped (uses Google photo / character portrait fallback).
  static final ValueNotifier<int> equippedAvatarNotifier =
      ValueNotifier<int>(0);

  /// True while the user is inside a match that reads/writes Firestore wallet or stats.
  /// HomeHub checks this before switching to offline mode on disconnection.
  static final ValueNotifier<bool> isInOnlineMatch = ValueNotifier<bool>(false);

  /// Registered by HomeHub so that [restartIntoOfflineMode] can cancel
  /// Firestore/session listeners without a direct reference to HomeHub.
  static VoidCallback? _cancelListenersCallback;

  /// HomeHub calls this in initState / dispose to wire up the cancel hook.
  static void registerCancelListenersCallback(VoidCallback? callback) {
    _cancelListenersCallback = callback;
  }

  /// Reactive local profile image path.
  static final ValueNotifier<String?> profileImagePathNotifier =
      ValueNotifier<String?>(null);

  /// Reactive Google/Firebase profile photo URL - all avatar composites listen.
  static final ValueNotifier<String?> profilePhotoUrlNotifier =
      ValueNotifier<String?>(null);

  /// Asset path for the offline character portrait (e.g., assets/account/man.png).
  /// Non-null while in offline mode; null when online.
  /// [FullAvatarDisplay] shows this as the profile image when non-null.
  static final ValueNotifier<String?> offlineAvatarAssetNotifier =
      ValueNotifier<String?>(null);

  /// Reactive app locale — drives MaterialApp.locale for instant language switching.
  static final ValueNotifier<Locale> localeNotifier =
      ValueNotifier<Locale>(const Locale('en'));

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

  static List<String> _parseSkinList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Build the Cosmetics map from current SharedPreferences, with optional overrides.
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
      'equippedAvatar': equippedAvatar ?? p.getInt(Keys.equippedAvatar) ?? 0,
      'ownedAvatars': ownedAvatars ?? (() {
        final s = p.getString(Keys.ownedAvatars) ?? '';
        if (s.isEmpty) return <int>[];
        return s.split(',').map(int.tryParse).whereType<int>().toSet().toList()..sort();
      })(),
      'selectedXSkin': p.getString(Keys.selectedXSkin) ?? 'default',
      'selectedOSkin': p.getString(Keys.selectedOSkin) ?? 'default',
      'ownedXSkins': _parseSkinList(p.getString(Keys.ownedXSkins)),
      'ownedOSkins': _parseSkinList(p.getString(Keys.ownedOSkins)),
      if (customXConfigs != null && customXConfigs.isNotEmpty)
        'customXConfigsV2': customXConfigs,
      if (customOConfigs != null && customOConfigs.isNotEmpty)
        'customOConfigsV2': customOConfigs,
    };
  }

  /// Sync a partial map to Firestore for the current user. Skip if offline or not signed in.
  static Future<void> _syncToFirestore(Map<String, dynamic> updates) async {
    final uid = _uid;
    if (uid == null || updates.isEmpty) return;

    // Guard: only write to Firestore when strictly online (AppMode.online).
    // This prevents writes during switchingToOnline / connectionProblem /
    // connectionLostDuringOnlineMatch / restartingToOffline.
    if (!AppModeService.canUseOnlineServices) {
      if (kDebugMode) {
        debugPrint('[GUARD] _syncToFirestore blocked mode=${AppModeService.current}');
      }
      return;
    }

    final isOnline = await ConnectivityService().online;
    if (!isOnline) return;

    try {
      await UserRepo().syncToFirestore(uid, updates);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[LocalStore] Firestore sync error: $error');
      }
    }
  }

  /// Returns the correct profile [ImageProvider] for the current app mode.
  ///
  /// Online: equipped avatar → Google photoURL → character portrait.
  /// Offline: character portrait only — NEVER uses Google photo.
  static ImageProvider getCurrentProfileImageProvider({
    String? characterType,
    String? photoUrl,
    int equippedAvatarId = 0,
  }) {
    final charAsset = (characterType == 'female')
        ? 'assets/account/feminine.png'
        : 'assets/account/man.png';

    if (AppModeService.isOfflineLike) {
      // Offline: always local character portrait — never Google photo.
      return AssetImage(charAsset);
    }

    // Online: equipped avatar → Google photoURL → character portrait.
    // Use the nullable resolver so an unequipped / unknown id falls
    // through cleanly instead of resolving to Avatar__1 (a paid item).
    final equipped = gameAvatarByIdOrNull(equippedAvatarId);
    if (equipped != null) {
      return AssetImage(equipped.assetPath);
    }
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    }
    return AssetImage(charAsset);
  }

  /// Call once at app startup to seed notifiers from SharedPreferences.
  static Future<void> initCoinsNotifier() async {
    final p = await _p();
    coinsNotifier.value = p.getInt(Keys.coins) ?? 200;
    // Sanitize legacy local cosmetics: if equippedAvatar > 0 but is not in
    // ownedAvatars, reset to 0. Avatar 1 was previously auto-granted by
    // older clients — this prevents the paid-only frame from appearing
    // for users who never bought it.
    final ownedRaw = p.getString(Keys.ownedAvatars) ?? '';
    final ownedIds = ownedRaw.isEmpty
        ? <int>{}
        : ownedRaw.split(',').map(int.tryParse).whereType<int>().toSet();
    final equipped = p.getInt(Keys.equippedAvatar) ?? 0;
    if (equipped > 0 && !ownedIds.contains(equipped)) {
      if (kDebugMode) {
        debugPrint('[AVATAR_MIGRATION] equippedAvatar reset to 0 because not owned (was $equipped)');
      }
      await p.setInt(Keys.equippedAvatar, 0);
      equippedAvatarNotifier.value = 0;
    } else {
      equippedAvatarNotifier.value = equipped;
    }
  }

  /// Call once at app startup to seed the profile image/photo notifiers.
  static Future<void> initProfileNotifier() async {
    final p = await _p();
    profileImagePathNotifier.value = p.getString(Keys.profilePhotoPath);
    profilePhotoUrlNotifier.value = p.getString(Keys.profilePhotoUrl);
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
    await p.setInt(Keys.equippedAvatar, p.getInt(Keys.equippedAvatar) ?? 0);
    await p.setString(Keys.ownedAvatars, p.getString(Keys.ownedAvatars) ?? '');
    await p.setString(Keys.ownedXSkins, p.getString(Keys.ownedXSkins) ?? 'default');
    await p.setString(Keys.ownedOSkins, p.getString(Keys.ownedOSkins) ?? 'default');
    await p.setString(Keys.selectedXSkin, p.getString(Keys.selectedXSkin) ?? 'default');
    await p.setString(Keys.selectedOSkin, p.getString(Keys.selectedOSkin) ?? 'default');

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
    equippedAvatarNotifier.value = p.getInt(Keys.equippedAvatar) ?? 0;
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
    if (AppConfig.kEnableFirestoreWalletSync) {
      await _syncToFirestore({'Wallet': {'coins': safeAmount}});
    }
  }

  static Future<void> updateCoins(int delta) async {
    // ── Route to correct wallet based on current AppMode ─────────────────────
    if (AppModeService.current == AppMode.offline) {
      // Offline mode: write ONLY to the offline wallet key. Never Firestore.
      final p = await _p();
      final current = p.getInt(Keys.offlineCoinsV2) ?? 200;
      final next = max(0, current + delta);
      await p.setInt(Keys.offlineCoinsV2, next);
      coinsNotifier.value = next;
      if (kDebugMode) debugPrint('[OFFLINE] updateCoins (offline) delta=$delta → $next');
      return;
    }

    // Guard: block all wallet changes unless strictly online.
    if (!AppModeService.canUseOnlineServices) {
      if (kDebugMode) {
        debugPrint('[GUARD] updateCoins blocked mode=${AppModeService.current}');
      }
      return;
    }

    // Online mode: write to online cache + sync to Firestore.
    final p = await _p();
    final current = p.getInt(Keys.coins) ?? 200;
    final next = max(0, current + delta);
    await p.setInt(Keys.coins, next);
    coinsNotifier.value = next;
    if (AppConfig.kEnableFirestoreWalletSync) {
      await _syncToFirestore({'Wallet': {'coins': next}});
    }
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
    if (!AppConfig.kEnableFirestoreWalletSync) return;
    if (!AppModeService.canUseOnlineServices) {
      if (kDebugMode) {
        debugPrint('[GUARD] syncCoinBalance blocked mode=${AppModeService.current}');
      }
      return;
    }
    final uid = _uid;
    if (uid == null) return;
    final coins = await LocalStore.coins();
    await UserRepo().syncToFirestore(uid, {'Wallet': {'coins': coins}});
  }

  static Future<void> addCoins(int amount) async {
    await updateCoins(amount);
  }

  /// Call the [grantMatchReward] Cloud Function to grant coins for a match result.
  ///
  /// This is the SECURE path for all match coin rewards.
  /// The server decides the reward amount — the client never sends a coin value.
  /// The local coin balance is updated from the server response.
  ///
  /// Usage (call this AFTER [addResult]):
  /// ```dart
  /// await LocalStore.addResult(result: 'win');
  /// await LocalStore.grantMatchRewardCF(matchId: uniqueMatchId, result: 'win');
  /// ```
  ///
  /// [matchId] must be unique per match. If the same matchId is submitted twice,
  /// the Cloud Function returns the already-processed response (idempotent).
  static Future<({int coinsAdded, int newBalance})> grantMatchRewardCF({
    required String matchId,
    required String result,
  }) async {
    // Guard: never process ONLINE match rewards while offline.
    //
    // This is the online (Cloud Function) reward path. Offline match
    // rewards run through [addResult] + the offline wallet and are
    // already persisted locally — they are NOT skipped. The previous
    // log message was misleading because it ran right after a
    // successful offline addResult and looked contradictory.
    if (AppModeService.isOfflineLike) {
      if (kDebugMode) {
        debugPrint('[MATCH] online reward grant skipped — app is not safely online');
      }
      return (coinsAdded: 0, newBalance: coinsNotifier.value);
    }

    // Coin rewards are NEVER server-authoritative anymore — the client
    // wallet is the source of truth. If the stats-only Cloud Function is
    // also disabled, there is nothing to do.
    if (!AppConfig.kEnableMatchStatsCloudFunction) {
      if (kDebugMode) {
        debugPrint('[MATCH] stats-only CF skipped because disabled — matchId=$matchId');
      }
      return (coinsAdded: 0, newBalance: coinsNotifier.value);
    }

    final uid = _uid;
    if (uid == null) {
      if (kDebugMode) debugPrint('[LocalStore] grantMatchRewardCF: no user signed in, skipping.');
      return (coinsAdded: 0, newBalance: coinsNotifier.value);
    }

    if (kDebugMode) {
      debugPrint('[MATCH] stats-only CF called matchId=$matchId result=$result');
    }
    try {
      final fn = FirebaseFunctions.instance.httpsCallable('grantMatchReward');
      final res = await fn.call(<String, dynamic>{
        'matchId': matchId,
        'result': result,
      }).timeout(const Duration(seconds: 15));

      final data = (res.data as Map<dynamic, dynamic>).cast<String, dynamic>();
      final coinsAdded = (data['coinsAdded'] as num?)?.toInt() ?? 0;
      final newBalance = (data['newBalance'] as num?)?.toInt();

      // STATS-ONLY: the CF no longer mutates Wallet.coins (it returns the
      // current server balance for visibility only). The client is
      // authoritative for coins — overwriting the local cache from the CF
      // response would clobber the credit/deduction this match's page
      // already applied via [updateCoins] and would re-introduce the
      // historic "ghost reward then revert" behaviour. We log for the
      // audit trail but do not touch local state.
      if (kDebugMode) {
        debugPrint(
          '[MATCH] cloud coin grant skipped to avoid double reward — stats only '
          '(server coinsAdded=$coinsAdded, server newBalance=$newBalance, '
          'localCoins=${coinsNotifier.value})',
        );
      }
      return (coinsAdded: 0, newBalance: coinsNotifier.value);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') {
        // Do not retry — log once and continue
        if (kDebugMode) debugPrint('[LocalStore] grantMatchRewardCF: permission-denied, not retrying.');
      } else {
        if (kDebugMode) debugPrint('[LocalStore] grantMatchRewardCF error: ${e.code} — ${e.message}');
      }
      return (coinsAdded: 0, newBalance: coinsNotifier.value);
    } catch (e) {
      if (kDebugMode) debugPrint('[LocalStore] grantMatchRewardCF unexpected error: $e');
      return (coinsAdded: 0, newBalance: coinsNotifier.value);
    }
  }

  static Future<void> addResult({required String result}) async {
    final p = await _p();
    final normalized = result.toLowerCase();

    // ── Route to offline stats if in offline mode ─────────────────────────────
    if (AppModeService.current == AppMode.offline) {
      // Write to offline-only stat keys. NEVER sync to Firestore.
      final gp = (p.getInt(Keys.offlineGamesPlayed) ?? 0) + 1;
      await p.setInt(Keys.offlineGamesPlayed, gp);
      if (normalized == 'win') {
        await p.setInt(Keys.offlineWins, (p.getInt(Keys.offlineWins) ?? 0) + 1);
      } else if (normalized == 'loss') {
        await p.setInt(
            Keys.offlineLosses, (p.getInt(Keys.offlineLosses) ?? 0) + 1);
      } else {
        await p.setInt(
            Keys.offlineDraws, (p.getInt(Keys.offlineDraws) ?? 0) + 1);
      }
      if (kDebugMode) {
        debugPrint('[OFFLINE] addResult (offline) result=$normalized, gamesPlayed=$gp');
      }
      return; // ZERO Firestore writes
    }

    // Guard: block stat writes unless strictly online.
    if (!AppModeService.canUseOnlineServices) {
      if (kDebugMode) {
        debugPrint('[GUARD] addResult blocked mode=${AppModeService.current}');
      }
      return;
    }

    // ── Online path: write to online stat keys + sync to Firestore ────────────
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

    if (AppConfig.kEnableFirestoreStatsSync) {
      await _syncToFirestore({
        'Stats': {
          'gamesPlayed': gp,
          'wins': w,
          'losses': l,
          'draws': d,
        }
      });
    }
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
    if (AppConfig.kEnableFirestoreInventorySync) {
      await _syncToFirestore({'Cosmetics': _cosmeticsPayload(p, xColor: hex)});
    }
  }

  static Future<void> setOPieceColor(Color c) async {
    final p = await _p();
    final hex = NeonColors.colorToString(c);
    await p.setString(Keys.oColor, hex);
    cosmeticsVersion.value++;
    if (AppConfig.kEnableFirestoreInventorySync) {
      await _syncToFirestore({'Cosmetics': _cosmeticsPayload(p, oColor: hex)});
    }
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
    if (AppConfig.kEnableFirestoreInventorySync) {
      await _syncToFirestore({'Cosmetics': _cosmeticsPayload(p, ownedX: list)});
    }
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
    if (AppConfig.kEnableFirestoreInventorySync) {
      await _syncToFirestore({'Cosmetics': _cosmeticsPayload(p, ownedO: list)});
    }
  }

  static Future<List<int>> ownedAvatars() async {
    final p = await _p();
    final s = p.getString(Keys.ownedAvatars) ?? '';
    if (s.isEmpty) return [];
    return s.split(',').map(int.tryParse).whereType<int>().toSet().toList()
      ..sort();
  }

  static Future<int> equippedAvatar() async {
    final p = await _p();
    return p.getInt(Keys.equippedAvatar) ?? 0;
  }

  static Future<void> addOwnedAvatar(int id) async {
    final p = await _p();
    final s = p.getString(Keys.ownedAvatars) ?? '';
    final set = (s.isEmpty ? <String>[] : s.split(','))
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    set.add(id);
    final list = set.toList()..sort();
    await p.setString(Keys.ownedAvatars, list.join(','));
    cosmeticsVersion.value++;
    if (AppConfig.kEnableFirestoreInventorySync) {
      await _syncToFirestore(
          {'Cosmetics': _cosmeticsPayload(p, ownedAvatars: list)});
      if (kDebugMode) debugPrint('[INVENTORY_SYNC] addOwnedAvatar → $id');
    }
  }

  static Future<void> setEquippedAvatar(int id) async {
    final p = await _p();
    // id == 0 means "unequip" — always allowed and falls back to the
    // Google photo / character portrait.
    if (id != 0) {
      final ownedRaw = p.getString(Keys.ownedAvatars) ?? '';
      final owned = (ownedRaw.isEmpty ? <String>[] : ownedRaw.split(','))
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
      if (!owned.contains(id)) {
        if (kDebugMode) {
          debugPrint('[STORE] blocked avatar equip because not owned: id=$id');
        }
        return;
      }
    }
    await p.setInt(Keys.equippedAvatar, id);
    equippedAvatarNotifier.value = id;
    cosmeticsVersion.value++;
    if (kDebugMode) {
      debugPrint(id == 0
          ? '[STORE] avatar unequipped'
          : '[STORE] avatar equipped: id=$id');
    }
    if (AppConfig.kEnableFirestoreInventorySync) {
      await _syncToFirestore(
          {'Cosmetics': _cosmeticsPayload(p, equippedAvatar: id)});
      if (kDebugMode) debugPrint('[INVENTORY_SYNC] setEquippedAvatar → $id');
    }
    syncCurrentCosmeticsToActiveArenaRoom();
  }

  // ── XO Image Skin methods ─────────────────────────────────────────────────

  static Future<String> selectedXSkin() async {
    final p = await _p();
    return p.getString(Keys.selectedXSkin) ?? 'default';
  }

  static Future<String> selectedOSkin() async {
    final p = await _p();
    return p.getString(Keys.selectedOSkin) ?? 'default';
  }

  static Future<void> setSelectedXSkin(String id) async {
    final p = await _p();
    await p.setString(Keys.selectedXSkin, id);
    cosmeticsVersion.value++;
    if (AppConfig.kEnableFirestoreInventorySync) {
      await _syncToFirestore({'Cosmetics': _cosmeticsPayload(p)});
      if (kDebugMode) {
        debugPrint('[INVENTORY_SYNC] ownedXSkins=${_parseSkinList(p.getString(Keys.ownedXSkins)).join(',')}');
        debugPrint('[INVENTORY_SYNC] ownedOSkins=${_parseSkinList(p.getString(Keys.ownedOSkins)).join(',')}');
        debugPrint('[INVENTORY_SYNC] selectedXSkin=${p.getString(Keys.selectedXSkin)}');
        debugPrint('[INVENTORY_SYNC] selectedOSkin=${p.getString(Keys.selectedOSkin)}');
        debugPrint('[INVENTORY_SYNC] Firestore Cosmetics synced');
      }
    }
    syncCurrentCosmeticsToActiveArenaRoom();
  }

  static Future<void> setSelectedOSkin(String id) async {
    final p = await _p();
    await p.setString(Keys.selectedOSkin, id);
    cosmeticsVersion.value++;
    if (AppConfig.kEnableFirestoreInventorySync) {
      await _syncToFirestore({'Cosmetics': _cosmeticsPayload(p)});
      if (kDebugMode) {
        debugPrint('[INVENTORY_SYNC] ownedXSkins=${_parseSkinList(p.getString(Keys.ownedXSkins)).join(',')}');
        debugPrint('[INVENTORY_SYNC] ownedOSkins=${_parseSkinList(p.getString(Keys.ownedOSkins)).join(',')}');
        debugPrint('[INVENTORY_SYNC] selectedXSkin=${p.getString(Keys.selectedXSkin)}');
        debugPrint('[INVENTORY_SYNC] selectedOSkin=${p.getString(Keys.selectedOSkin)}');
        debugPrint('[INVENTORY_SYNC] Firestore Cosmetics synced');
      }
    }
    syncCurrentCosmeticsToActiveArenaRoom();
  }

  static Future<List<String>> ownedXSkins() async {
    final p = await _p();
    final s = p.getString(Keys.ownedXSkins) ?? 'default';
    final ids = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (!ids.contains('default')) ids.add('default');
    return ids.toList();
  }

  static Future<List<String>> ownedOSkins() async {
    final p = await _p();
    final s = p.getString(Keys.ownedOSkins) ?? 'default';
    final ids = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (!ids.contains('default')) ids.add('default');
    return ids.toList();
  }

  static Future<void> addOwnedXSkin(String id) async {
    final p = await _p();
    final set = (p.getString(Keys.ownedXSkins) ?? 'default')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    set.add('default');
    set.add(id);
    await p.setString(Keys.ownedXSkins, set.join(','));
    cosmeticsVersion.value++;
    if (AppConfig.kEnableFirestoreInventorySync) {
      await _syncToFirestore({'Cosmetics': _cosmeticsPayload(p)});
      if (kDebugMode) {
        debugPrint('[INVENTORY_SYNC] ownedXSkins=${_parseSkinList(p.getString(Keys.ownedXSkins)).join(',')}');
        debugPrint('[INVENTORY_SYNC] ownedOSkins=${_parseSkinList(p.getString(Keys.ownedOSkins)).join(',')}');
        debugPrint('[INVENTORY_SYNC] selectedXSkin=${p.getString(Keys.selectedXSkin)}');
        debugPrint('[INVENTORY_SYNC] selectedOSkin=${p.getString(Keys.selectedOSkin)}');
        debugPrint('[INVENTORY_SYNC] Firestore Cosmetics synced');
      }
    }
  }

  static Future<void> addOwnedOSkin(String id) async {
    final p = await _p();
    final set = (p.getString(Keys.ownedOSkins) ?? 'default')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    set.add('default');
    set.add(id);
    await p.setString(Keys.ownedOSkins, set.join(','));
    cosmeticsVersion.value++;
    if (AppConfig.kEnableFirestoreInventorySync) {
      await _syncToFirestore({'Cosmetics': _cosmeticsPayload(p)});
      if (kDebugMode) {
        debugPrint('[INVENTORY_SYNC] ownedXSkins=${_parseSkinList(p.getString(Keys.ownedXSkins)).join(',')}');
        debugPrint('[INVENTORY_SYNC] ownedOSkins=${_parseSkinList(p.getString(Keys.ownedOSkins)).join(',')}');
        debugPrint('[INVENTORY_SYNC] selectedXSkin=${p.getString(Keys.selectedXSkin)}');
        debugPrint('[INVENTORY_SYNC] selectedOSkin=${p.getString(Keys.selectedOSkin)}');
        debugPrint('[INVENTORY_SYNC] Firestore Cosmetics synced');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

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
    final currentUrl = p.getString(Keys.profilePhotoUrl);
    final normalized = (url == null || url.isEmpty) ? null : url;
    if (currentUrl == normalized && profilePhotoUrlNotifier.value == normalized) {
      return;
    }
    if (normalized == null) {
      await p.remove(Keys.profilePhotoUrl);
      profilePhotoUrlNotifier.value = null;
      return;
    }
    await p.setString(Keys.profilePhotoUrl, normalized);
    profilePhotoUrlNotifier.value = normalized;
  }

  static Future<void> addTopupHistory({
    required double usd,
    required int coins,
    required String type,
    String? description,
    String? transactionId,
    int? balanceBefore,
    int? balanceAfter,
    String? source,
  }) async {
    final isCredit = type == 'win' || type == 'recharge';
    final delta = isCredit ? coins.abs() : -coins.abs();

    if (kDebugMode) {
      debugPrint('[WALLET] applying delta source=${source ?? type} delta=$delta '
          'before=${balanceBefore ?? '?'} after=${balanceAfter ?? '?'}');
    }

    final p = await _p();
    if (transactionId != null && transactionId.isNotEmpty) {
      final logged = p.getString(Keys.loggedTransactionIds) ?? '';
      final loggedSet = logged.split(',').where((s) => s.isNotEmpty).toSet();
      if (loggedSet.contains(transactionId)) {
        if (kDebugMode) {
          debugPrint('[WALLET_LEDGER] duplicate transaction blocked id=$transactionId');
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

    final isOnline = AppModeService.canUseOnlineServices;
    final uid = _uid;

    if (kDebugMode) {
      debugPrint('[WALLET_LEDGER] created transactionId=${transactionId ?? 'none'} '
          'type=${isCredit ? 'credit' : 'debit'} source=${source ?? type} delta=$delta');
    }

    if (isOnline && uid != null && transactionId != null && transactionId.isNotEmpty) {
      try {
        final ledgerEntry = <String, dynamic>{
          'uid': uid,
          'mode': 'online',
          'type': isCredit ? 'credit' : 'debit',
          if (source != null) 'source': source,
          'title': description ?? type,
          'delta': delta,
          if (balanceBefore != null) 'balanceBefore': balanceBefore,
          if (balanceAfter != null) 'balanceAfter': balanceAfter,
          'createdAt': FieldValue.serverTimestamp(),
          'transactionId': transactionId,
        };
        await UserRepo().writeWalletLedger(uid, transactionId, ledgerEntry);
        if (kDebugMode) debugPrint('[WALLET_LEDGER] Firestore ledger write success');
      } catch (e) {
        if (kDebugMode) debugPrint('[WALLET_LEDGER] failed error=$e');
      }
    } else {
      if (kDebugMode) debugPrint('[WALLET_LEDGER] local offline ledger write success');
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

  // ── Adaptive-easing fail streak per level ────────────────────────────────
  //
  // Persisted, per-level loss counter used by LevelGamePage to silently ease
  // the AI after repeated failures. Local-only — never synced to Firestore;
  // this is a UX nudge, not progress state. (2026-05-24 — level rebalance.)
  static String _levelFailStreakKey(int level) => 'levelFailStreak_$level';

  static Future<int> getLevelFailStreak(int level) async {
    final p = await _p();
    return p.getInt(_levelFailStreakKey(level)) ?? 0;
  }

  static Future<int> incrementLevelFailStreak(int level) async {
    final p = await _p();
    final next = (p.getInt(_levelFailStreakKey(level)) ?? 0) + 1;
    await p.setInt(_levelFailStreakKey(level), next);
    return next;
  }

  static Future<void> clearLevelFailStreak(int level) async {
    final p = await _p();
    await p.remove(_levelFailStreakKey(level));
  }

  // ── Online character type cache ──────────────────────────────────────────

  /// Cache the online profile's characterType locally (written by Firestore listener).
  static Future<void> setOnlineCharacterType(String? type) async {
    if (type == null || type.isEmpty) return;
    final p = await _p();
    await p.setString(Keys.characterType, type);
  }

  // ── Offline profile ──────────────────────────────────────────────────────

  /// Read the offline player profile from SharedPreferences, or null if not yet created.
  static Future<OfflinePlayerProfile?> getOfflineProfile() async {
    final p = await _p();
    if (!(p.getBool(Keys.offlineProfileExists) ?? false)) return null;

    // Parse owned avatars (comma-separated ints).
    final ownedAvatarsRaw = p.getString(Keys.offlineOwnedAvatars) ?? '';
    final ownedAvatarsList = ownedAvatarsRaw.isEmpty
        ? <int>[]
        : ownedAvatarsRaw.split(',').map(int.tryParse).whereType<int>().toList();

    // Parse owned skins (comma-separated strings).
    final ownedXSkinsRaw = p.getString(Keys.offlineOwnedXSkins) ?? '';
    final ownedXSkinsList = ownedXSkinsRaw.isEmpty
        ? <String>[]
        : ownedXSkinsRaw.split(',').where((s) => s.isNotEmpty).toList();

    final ownedOSkinsRaw = p.getString(Keys.offlineOwnedOSkins) ?? '';
    final ownedOSkinsList = ownedOSkinsRaw.isEmpty
        ? <String>[]
        : ownedOSkinsRaw.split(',').where((s) => s.isNotEmpty).toList();

    final selectedAvatarRaw = p.getInt(Keys.offlineSelectedAvatar);

    return OfflinePlayerProfile(
      offlineId: p.getString(Keys.offlinePlayerId) ?? '',
      name: p.getString(Keys.offlinePlayerName) ?? 'PLAYER',
      characterType: p.getString(Keys.offlineCharacterType) ?? 'male',
      coins: p.getInt(Keys.offlineCoinsV2) ?? 200,
      gamesPlayed: p.getInt(Keys.offlineGamesPlayed) ?? 0,
      wins: p.getInt(Keys.offlineWins) ?? 0,
      losses: p.getInt(Keys.offlineLosses) ?? 0,
      draws: p.getInt(Keys.offlineDraws) ?? 0,
      isOfflineProfile: true,
      ownedAvatars: ownedAvatarsList,
      selectedAvatar: selectedAvatarRaw,
      ownedXSkins: ownedXSkinsList,
      selectedXSkin: p.getString(Keys.offlineSelectedXSkin),
      ownedOSkins: ownedOSkinsList,
      selectedOSkin: p.getString(Keys.offlineSelectedOSkin),
    );
  }

  /// Create (or recreate) the offline profile. Falls back to cached online data for name and characterType.
  ///
  /// SAFETY: If an offline profile already exists, refuse to overwrite it
  /// and return the existing one. This is the last line of defence against
  /// the "offline coins reset to 200 after Online→Offline" bug — even if a
  /// future code path calls this method without first checking
  /// [getOfflineProfile], the existing 250-coin profile is preserved.
  static Future<OfflinePlayerProfile> createOfflineProfile({
    String? name,
    String? characterType,
  }) async {
    final p = await _p();
    if (p.getBool(Keys.offlineProfileExists) == true) {
      final existing = await getOfflineProfile();
      if (existing != null) {
        if (kDebugMode) {
          debugPrint('[OFFLINE_PROFILE] preserve existing — refusing to recreate, coins=${existing.coins}');
        }
        return existing;
      }
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final resolvedName = (name?.trim().isNotEmpty == true)
        ? name!
        : (p.getString(Keys.username) ??
            p.getString(Keys.guestName) ??
            'PLAYER');
    final resolvedType = (characterType?.isNotEmpty == true)
        ? characterType!
        : (p.getString(Keys.characterType) ??
            p.getString(Keys.offlineCharacterType) ??
            'male');

    await p.setBool(Keys.offlineProfileExists, true);
    await p.setString(Keys.offlinePlayerId, id);
    await p.setString(Keys.offlinePlayerName, resolvedName);
    await p.setString(Keys.offlineCharacterType, resolvedType);
    await p.setInt(Keys.offlineCoinsV2, 200);
    await p.setInt(Keys.offlineGamesPlayed, 0);
    await p.setInt(Keys.offlineWins, 0);
    await p.setInt(Keys.offlineLosses, 0);
    await p.setInt(Keys.offlineDraws, 0);
    // Cosmetics: start empty — no avatars, no skins.
    await p.setString(Keys.offlineOwnedAvatars, '');
    await p.remove(Keys.offlineSelectedAvatar);
    await p.setString(Keys.offlineOwnedXSkins, '');
    await p.remove(Keys.offlineSelectedXSkin);
    await p.setString(Keys.offlineOwnedOSkins, '');
    await p.remove(Keys.offlineSelectedOSkin);

    if (kDebugMode) {
      debugPrint('[OfflineProfile] Created: name=$resolvedName, type=$resolvedType');
    }

    return OfflinePlayerProfile(
      offlineId: id,
      name: resolvedName,
      characterType: resolvedType,
      coins: 200,
      gamesPlayed: 0,
      wins: 0,
      losses: 0,
      draws: 0,
      isOfflineProfile: true,
      ownedAvatars: const [],
      selectedAvatar: null,
      ownedXSkins: const [],
      selectedXSkin: null,
      ownedOSkins: const [],
      selectedOSkin: null,
    );
  }

  /// Update the offline coin balance (local only, never touches Firestore).
  static Future<void> setOfflineCoins(int amount) async {
    final p = await _p();
    final safe = max(0, amount);
    await p.setInt(Keys.offlineCoinsV2, safe);
    coinsNotifier.value = safe;
  }

  /// Restore the online coin balance and profile from SharedPreferences cache after reconnect.
  static Future<void> restoreOnlineCoins() async {
    final p = await _p();
    final onlineCoins = p.getInt(Keys.coins) ?? 200;
    coinsNotifier.value = onlineCoins;
    // Clear the offline character portrait — online profile handles its own avatar.
    offlineAvatarAssetNotifier.value = null;
    profilePhotoUrlNotifier.value = p.getString(Keys.profilePhotoUrl);
    profileImagePathNotifier.value = p.getString(Keys.profilePhotoPath);
  }

  // ── Zero-Merge Offline Restart ────────────────────────────────────────────

  /// Central "Restart into Offline Mode" entry point.
  ///
  /// Call this from ANY page (match overlay, home, settings) to perform a
  /// clean, atomic transition to offline mode:
  ///
  /// 1. Clears the online match flag immediately.
  /// 2. Sets [AppMode.restartingToOffline] — every Firestore op is blocked.
  /// 3. Cancels HomeHub Firestore/session listeners via registered callback.
  /// 4. Loads (or creates) the isolated [OfflinePlayerProfile].
  /// 5. Applies offline wallet — coinsNotifier reflects offline balance.
  /// 6. Clears Google/Firebase photo URL (offline profile never uses it).
  /// 7. Sets [AppMode.offline].
  ///
  /// Online coins, online stats, and Firestore data are left entirely untouched.
  /// The offline profile has ZERO knowledge of the interrupted online match.
  ///
  /// Returns the loaded [OfflinePlayerProfile] so the caller can navigate
  /// to the offline home and display the correct profile data.
  static Future<OfflinePlayerProfile> restartIntoOfflineMode() async {
    if (kDebugMode) {
      debugPrint('[OFFLINE] restartIntoOfflineMode — begin');
      debugPrint('[MATCH] no result calculated — abandoning online match');
      debugPrint('[MATCH] no Firestore write — zero-merge enforced');
    }

    // Step 1: clear the online match flag so HomeHub doesn't guard again.
    isInOnlineMatch.value = false;

    // Step 2: block all Firestore ops during the transition.
    AppModeService.setMode(AppMode.restartingToOffline);

    // Step 3: cancel HomeHub listeners (Firestore + session streams).
    _cancelListenersCallback?.call();
    if (kDebugMode) {
      debugPrint('[LISTENER] Firestore listener cancelled by restartIntoOfflineMode');
      debugPrint('[LISTENER] session listener cancelled by restartIntoOfflineMode');
    }

    // Step 4: load (or create) the offline profile — completely separate data.
    var profile = await getOfflineProfile();
    if (profile == null) {
      profile = await createOfflineProfile();
      if (kDebugMode) debugPrint('[OFFLINE] no existing offline profile — created fresh');
    } else {
      if (kDebugMode) {
        debugPrint('[OFFLINE] loaded offline profile: ${profile.name}, coins=${profile.coins}');
      }
    }

    // Step 5: apply offline wallet — online coinsNotifier now shows offline balance.
    await setOfflineCoins(profile.coins);

    // Step 6: clear online photo and set offline character portrait asset.
    await setProfilePhotoUrl(null);
    profileImagePathNotifier.value = null;
    offlineAvatarAssetNotifier.value = profile.avatarAssetPath;

    // Step 7: enter offline mode.
    AppModeService.setMode(AppMode.offline);

    if (kDebugMode) {
      debugPrint('[OFFLINE] mode=offline, coins=${profile.coins}');
      debugPrint('[OFFLINE] restartIntoOfflineMode — complete');
    }

    return profile;
  }
}

