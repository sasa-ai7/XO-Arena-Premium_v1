import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';
import '../core/keys.dart';
import 'local_store.dart';
import '../models/user_data.dart';
import 'app_mode_service.dart';
import 'referral/referral_service.dart';

/// Repository for user data sync between SharedPreferences (cache) and Firestore.
class UserRepo {
  static final UserRepo _instance = UserRepo._();
  factory UserRepo() => _instance;

  UserRepo._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<SharedPreferences> _sp() => SharedPreferences.getInstance();

  /// Called after Firebase auth. Runs migration if needed, then pulls server to local.
  Future<void> initAfterAuth(String uid) async {
    try {
      if (kDebugMode) {
        debugPrint('[AUTH] UserRepo: initAfterAuth start');
      }
      final p = await _sp();
      final migrated = p.getBool(Keys.migrated) ?? false;

      if (!migrated) {
        // Check if we have local game data to migrate
        final hasLocalData = _hasLocalGameData(p);
        final serverDoc = await _firestore.collection('users').doc(uid).get();

        if (hasLocalData && (!serverDoc.exists || _isEmptyDoc(serverDoc.data()))) {
          await pushLocalToServer(uid);
        }
        await p.setBool(Keys.migrated, true);
      }

      if (kDebugMode) {
        debugPrint('[AUTH] UserRepo: pullServerToLocal start');
      }
      await pullServerToLocal(uid);

      // Referral: ensure a 9-digit invite code exists. Cross-user reward
      // writes are mediated by the `redeemReferralCode` Cloud Function, so
      // there is no client-side drain step. Best-effort — failures do not
      // block auth.
      if (AppConfig.kEnableReferralRewards) {
        try {
          await ReferralService.instance.ensureCode(uid);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[REFERRAL] initAfterAuth referral step failed: $e');
          }
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AUTH] UserRepo error: $e');
        debugPrint('[AUTH] UserRepo StackTrace: $st');
      }
      rethrow;
    }
  }

  bool _hasLocalGameData(SharedPreferences p) {
    final coins = p.getInt(Keys.coins) ?? 0;
    final gamesPlayed = p.getInt(Keys.gamesPlayed) ?? 0;
    return coins > 0 || gamesPlayed > 0;
  }

  bool _isEmptyDoc(Map<String, dynamic>? data) {
    if (data == null) return true;
    final wallet = data['Wallet'] as Map<String, dynamic>?;
    final stats = data['Stats'] as Map<String, dynamic>?;
    if (wallet != null) {
      final c = (wallet['coins'] as num?)?.toInt() ?? 0;
      if (c > 0) return false;
    }
    if (stats != null) {
      final g = (stats['gamesPlayed'] as num?)?.toInt() ?? 0;
      if (g > 0) return false;
    }
    return true;
  }

  /// Load user data from Firestore.
  Future<UserData?> loadUserFromServer(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserData.fromFirestore(doc);
  }

  /// Pull Firestore data to SharedPreferences (cache).
  /// Returns true if data was actually fetched; false if the guard blocked it.
  Future<bool> pullServerToLocal(String uid) async {
    // Allow during a controlled reconnect token (canUseOnlineServicesForReconnect
    // is true when AppModeService.isReconnecting — the token is active).
    if (!AppModeService.canUseOnlineServicesForReconnect) {
      if (kDebugMode) {
        debugPrint('[FIRESTORE] skipped pullServerToLocal mode=${AppModeService.current}');
      }
      return false;
    }

    final data = await loadUserFromServer(uid);
    final p = await _sp();

    if (data != null) {
      // IMPORTANT: await every write to guarantee disk persistence
      // before the startup transition routes into the destination screen.
      await p.setString(Keys.username, data.profile.name.toUpperCase());
      await p.setString(Keys.email, data.profile.email);
      final serverCoins = max(0, data.wallet.coins);
      final localCoins = p.getInt(Keys.coins) ?? 0;
      // Only update if server has MORE coins (e.g. IAP verified server-side).
      // Never overwrite locally-earned coins that haven't synced yet.
      if (serverCoins > localCoins) {
        await p.setInt(Keys.coins, serverCoins);
        LocalStore.coinsNotifier.value = serverCoins;
      }
      await p.setInt(Keys.gamesPlayed, data.stats.gamesPlayed);
      await p.setInt(Keys.wins, data.stats.wins);
      await p.setInt(Keys.losses, data.stats.losses);
      await p.setInt(Keys.draws, data.stats.draws);
      await p.setString(Keys.xColor, data.cosmetics.xColor);
      await p.setString(Keys.oColor, data.cosmetics.oColor);
      await p.setString(Keys.ownedXColors, data.cosmetics.ownedXColors.join(','));
      await p.setString(Keys.ownedOColors, data.cosmetics.ownedOColors.join(','));
      await p.setInt(Keys.equippedAvatar, data.cosmetics.equippedAvatar);
      await p.setString(Keys.ownedAvatars, data.cosmetics.ownedAvatars.join(','));
      final serverXSkins = data.cosmetics.ownedXSkins;
      await p.setString(Keys.ownedXSkins,
          serverXSkins.isNotEmpty ? serverXSkins.join(',') : 'default');
      final serverOSkins = data.cosmetics.ownedOSkins;
      await p.setString(Keys.ownedOSkins,
          serverOSkins.isNotEmpty ? serverOSkins.join(',') : 'default');
      await p.setString(Keys.selectedXSkin, data.cosmetics.selectedXSkin);
      await p.setString(Keys.selectedOSkin, data.cosmetics.selectedOSkin);
      await p.setInt(Keys.levelGameCurrentLevel, data.progress.levelGameCurrentLevel);
      await p.setBool(Keys.levelGameCompleted, data.progress.levelGameCompleted);

      // Sync profile photo URL
      final photoUrl = data.profile.photoURL;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await LocalStore.setProfilePhotoUrl(photoUrl);
      }
    }
    if (kDebugMode) {
      debugPrint('[AUTH] UserRepo: pullServerToLocal success uid=$uid');
    }
    return true;
  }

  /// Push local SharedPreferences data to Firestore (first-run migration).
  Future<void> pushLocalToServer(String uid) async {
    final p = await _sp();
    final now = DateTime.now();

    final profile = UserProfile(
      name: (p.getString(Keys.username) ?? 'PLAYER').toUpperCase(),
      email: p.getString(Keys.email) ?? '',
      provider: 'email',
      lastLoginAt: now,
    );
    final wallet = UserWallet(
      coins: max(0, p.getInt(Keys.coins) ?? 0),
    );
    final stats = UserStats(
      gamesPlayed: p.getInt(Keys.gamesPlayed) ?? 0,
      wins: p.getInt(Keys.wins) ?? 0,
      losses: p.getInt(Keys.losses) ?? 0,
      draws: p.getInt(Keys.draws) ?? 0,
    );
    final cosmetics = UserCosmetics(
      xColor: p.getString(Keys.xColor) ?? 'ffff3b30',
      oColor: p.getString(Keys.oColor) ?? 'ff0a84ff',
      ownedXColors: _parseOwned(p.getString(Keys.ownedXColors) ?? '0'),
      ownedOColors: _parseOwned(p.getString(Keys.ownedOColors) ?? '0'),
      // New accounts get NO avatar by default. All avatars (including
      // Avatar__1) are paid store items. equippedAvatar=0 means "no avatar
      // selected" — the UI falls back to the Google photo or local
      // character portrait.
      equippedAvatar: p.getInt(Keys.equippedAvatar) ?? 0,
      ownedAvatars: _parseOwned(p.getString(Keys.ownedAvatars) ?? ''),
      ownedXSkins: _parseSkinList(p.getString(Keys.ownedXSkins) ?? 'default'),
      ownedOSkins: _parseSkinList(p.getString(Keys.ownedOSkins) ?? 'default'),
      selectedXSkin: p.getString(Keys.selectedXSkin) ?? 'default',
      selectedOSkin: p.getString(Keys.selectedOSkin) ?? 'default',
    );
    final progress = UserProgress(
      levelGameCurrentLevel: p.getInt(Keys.levelGameCurrentLevel) ?? 1,
      levelGameCompleted: p.getBool(Keys.levelGameCompleted) ?? false,
    );

    final userData = UserData(
      profile: profile,
      wallet: wallet,
      stats: stats,
      cosmetics: cosmetics,
      progress: progress,
    );

    await _firestore.collection('users').doc(uid).set(
          userData.toFirestore(),
          SetOptions(merge: true),
        );

    // Migrate topup history to transactions subcollection.
    final historyStr = p.getString(Keys.topupHistory) ?? '';
    if (historyStr.isNotEmpty) {
      final entries = historyStr.split(',');
      for (final entry in entries) {
        final parts = entry.split('|');
        if (parts.length >= 4) {
          final dateTime = DateTime.tryParse(parts[0]);
          final usd = double.tryParse(parts[1]) ?? 0;
          final coins = int.tryParse(parts[2]) ?? 0;
          final type = parts[3];
          if (dateTime != null) {
            await addTransaction(uid, usd, coins, type, createdAt: dateTime);
          }
        }
      }
    }
  }

  List<int> _parseOwned(String s) {
    // Empty string means the user owns nothing yet. Returning [0] before
    // implied "owns avatar 0" which was sometimes interpreted as the
    // default Avatar__1 fallback. Return a true empty list.
    if (s.isEmpty) return <int>[];
    return s
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _parseSkinList(String s) {
    if (s.isEmpty) return <String>['default'];
    final ids = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (!ids.contains('default')) ids.add('default');
    return ids.toList();
  }

  /// Sync a partial update to Firestore. Passes through all game data keys.
  Future<void> syncToFirestore(String uid, Map<String, dynamic> updates) async {
    if (updates.isEmpty) return;

    final data = <String, dynamic>{};
    if (updates.containsKey('Profile'))   data['Profile']   = updates['Profile'];
    if (updates.containsKey('Wallet'))    data['Wallet']    = updates['Wallet'];
    if (updates.containsKey('Stats'))     data['Stats']     = updates['Stats'];
    if (updates.containsKey('Cosmetics')) data['Cosmetics'] = updates['Cosmetics'];
    if (updates.containsKey('Inventory')) data['Inventory'] = updates['Inventory'];
    if (updates.containsKey('Progress'))  data['Progress']  = updates['Progress'];
    if (updates.containsKey('Settings'))  data['Settings']  = updates['Settings'];
    if (updates.containsKey('Session'))   data['Session']   = updates['Session'];

    if (data.isEmpty) return;

    await _firestore.collection('users').doc(uid).set(
      data,
      SetOptions(merge: true),
    );
  }

  /// Write a wallet ledger entry to users/{uid}/wallet_ledger/{transactionId}.
  /// Uses set (not add) so the transactionId acts as an idempotency key server-side.
  Future<void> writeWalletLedger(
    String uid,
    String transactionId,
    Map<String, dynamic> entry,
  ) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('wallet_ledger')
        .doc(transactionId)
        .set(entry, SetOptions(merge: false));
  }

  /// Add a transaction record.
  /// When [transactionId] is set, uses it as document ID for idempotency (same transaction = one doc).
  Future<void> addTransaction(String uid, double usd, int coins, String type,
      {DateTime? createdAt, String? transactionId, int? balanceBefore, int? balanceAfter, String? description}) async {
    final rec = TransactionRecord(
      usd: usd,
      coins: coins,
      type: type,
      createdAt: createdAt ?? DateTime.now(),
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      description: description,
    );
    final col = _firestore.collection('users').doc(uid).collection('transactions');
    if (transactionId != null && transactionId.isNotEmpty) {
      await col.doc(transactionId).set(rec.toMap());
      if (kDebugMode) {
        debugPrint('[UserRepo] Transaction recorded with id: $transactionId');
      }
    } else {
      await col.add(rec.toMap());
    }
  }

  /// Get transactions (for history). Returns list of map entries compatible with getTopupHistory format.
  Future<List<Map<String, dynamic>>> getTransactions(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    final list = snapshot.docs.map((doc) {
      final d = doc.data();
      final ts = d['createdAt'] as Timestamp?;
      final rawType = d['type'] as String? ?? 'purchase';
      return {
        'dateTime': ts?.toDate() ?? DateTime.now(),
        'usd': (d['usd'] as num?)?.toDouble() ?? 0,
        'coins': (d['coins'] as num?)?.toInt() ?? 0,
        'type': TransactionRecord.mapLegacyType(rawType),
        if (d['balanceBefore'] != null) 'balanceBefore': (d['balanceBefore'] as num).toInt()
        else if (d['previousBalance'] != null) 'balanceBefore': (d['previousBalance'] as num).toInt(),
        if (d['balanceAfter'] != null) 'balanceAfter': (d['balanceAfter'] as num).toInt(),
        if (d['description'] != null) 'description': d['description'] as String,
      };
    }).toList();
    // Dedupe by composite key (existing duplicates from before idempotency fix).
    return _dedupeTransactions(list);
  }

  /// Dedupe transaction list by (dateTime, coins, type) keeping first occurrence.
  static List<Map<String, dynamic>> _dedupeTransactions(List<Map<String, dynamic>> list) {
    final seen = <String>{};
    return list.where((e) {
      final dt = e['dateTime'] as DateTime?;
      final coins = e['coins'] as int? ?? 0;
      final type = e['type'] as String? ?? '';
      final key = '${dt?.millisecondsSinceEpoch ?? 0}_${coins}_$type';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }

  /// Clear local cache (on logout). Keeps migrated flag and justDeletedAccount flag for future.
  Future<void> clearLocalCache() async {
    final p = await _sp();
    
    // Preserve the deletion flag to prevent auto sign-in after account deletion
    final justDeleted = p.getBool(Keys.justDeletedAccount) ?? false;
    
    // Clear all user data
    await p.setBool(Keys.loggedIn, false);
    await p.remove(Keys.username);
    await p.remove(Keys.email);
    await p.remove(Keys.coins);
    await p.remove(Keys.gamesPlayed);
    await p.remove(Keys.wins);
    await p.remove(Keys.losses);
    await p.remove(Keys.draws);
    await p.remove(Keys.xColor);
    await p.remove(Keys.oColor);
    await p.remove(Keys.ownedXColors);
    await p.remove(Keys.ownedOColors);
    await p.remove(Keys.topupHistory);
    await p.remove(Keys.levelGameCurrentLevel);
    await p.remove(Keys.levelGameCompleted);
    await p.remove(Keys.profilePhotoPath);
    await p.remove(Keys.profilePhotoUrl);
    
    // Restore flag if it was set (to prevent auto sign-in after account deletion)
    if (justDeleted) {
      await p.setBool(Keys.justDeletedAccount, true);
    }
    // Keep Keys.migrated - we don't reset it on logout so next login doesn't re-migrate
  }
}
