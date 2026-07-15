import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';
import '../core/keys.dart';
import '../models/user_data.dart';
import 'app_mode_service.dart';
import 'local_store.dart';
import 'referral/referral_service.dart';
import 'wallet_history_service.dart';

class TransactionPage {
  const TransactionPage(this.rows, this.cursor, this.hasMore);

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> rows;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}

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

        if (hasLocalData &&
            (!serverDoc.exists || _isEmptyDoc(serverDoc.data()))) {
          await pushLocalToServer(uid);
        }
        await p.setBool(Keys.migrated, true);
      }

      if (kDebugMode) {
        debugPrint('[AUTH] UserRepo: pullServerToLocal start');
      }
      await pullServerToLocal(uid);

      // Durable history recovery is non-critical for login rendering. Queue it
      // safely; opening History also performs the same idempotent flush.
      unawaited(Future<void>(() async {
        try {
          await WalletHistoryService.instance.migrateLegacyHistory(uid);
          await WalletHistoryService.instance.flushPending(uid);
        } catch (error) {
          if (kDebugMode) {
            debugPrint('[WALLET_HISTORY] post-login sync deferred: $error');
          }
        }
      }));

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
        debugPrint(
            '[FIRESTORE] skipped pullServerToLocal mode=${AppModeService.current}');
      }
      return false;
    }

    final data = await loadUserFromServer(uid);
    if (data != null) {
      await applyUserDataToLocal(data);
    }
    if (kDebugMode) {
      debugPrint('[AUTH] UserRepo: pullServerToLocal success uid=$uid');
    }
    return true;
  }

  /// Write an already-fetched [UserData] into SharedPreferences (cache) and
  /// live notifiers. Split out of [pullServerToLocal] so the login flow can
  /// seed local state from the SAME document it fetched for the new-vs-existing
  /// routing check — avoiding a second Firestore read during sign-in.
  Future<void> applyUserDataToLocal(UserData data) async {
    final p = await _sp();
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
    LocalStore.equippedAvatarNotifier.value = data.cosmetics.equippedAvatar;
    final serverXSkins = data.cosmetics.ownedXSkins;
    await p.setString(Keys.ownedXSkins,
        serverXSkins.isNotEmpty ? serverXSkins.join(',') : 'default');
    final serverOSkins = data.cosmetics.ownedOSkins;
    await p.setString(Keys.ownedOSkins,
        serverOSkins.isNotEmpty ? serverOSkins.join(',') : 'default');
    await p.setString(Keys.selectedXSkin, data.cosmetics.selectedXSkin);
    await p.setString(Keys.selectedOSkin, data.cosmetics.selectedOSkin);
    // Emoji ownership/equip — only persist non-empty server data so a fresh
    // account keeps its local defaults (5 free emojis equipped).
    if (data.cosmetics.ownedEmojis.isNotEmpty) {
      await p.setString(Keys.ownedEmojis, data.cosmetics.ownedEmojis.join(','));
    }
    if (data.cosmetics.equippedEmojis.isNotEmpty) {
      await p.setString(
          Keys.equippedEmojis, data.cosmetics.equippedEmojis.join(','));
    }
    await p.setInt(
        Keys.levelGameCurrentLevel, data.progress.levelGameCurrentLevel);
    await p.setBool(Keys.levelGameCompleted, data.progress.levelGameCompleted);

    // Sync profile photo URL
    final photoUrl = data.profile.photoURL;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      await LocalStore.setProfilePhotoUrl(photoUrl);
    }
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
      ownedEmojis: (p.getString(Keys.ownedEmojis) ?? '')
          .split(',')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      equippedEmojis: (p.getString(Keys.equippedEmojis) ?? '')
          .split(',')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
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

    // WalletHistoryService performs the idempotent deterministic migration to
    // wallet_ledger. Do not copy legacy rows into random transaction docs.
  }

  List<int> _parseOwned(String s) {
    // Empty string means the user owns nothing yet. Returning [0] before
    // implied "owns avatar 0" which was sometimes interpreted as the
    // default Avatar__1 fallback. Return a true empty list.
    if (s.isEmpty) return <int>[];
    return s.split(',').map(int.tryParse).whereType<int>().toSet().toList()
      ..sort();
  }

  List<String> _parseSkinList(String s) {
    if (s.isEmpty) return <String>['default'];
    final ids =
        s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (!ids.contains('default')) ids.add('default');
    return ids.toList();
  }

  /// Sync a partial update to Firestore. Passes through all game data keys.
  Future<void> syncToFirestore(String uid, Map<String, dynamic> updates) async {
    if (updates.isEmpty) return;

    final data = <String, dynamic>{};
    if (updates.containsKey('Profile')) data['Profile'] = updates['Profile'];
    if (updates.containsKey('Wallet')) data['Wallet'] = updates['Wallet'];
    if (updates.containsKey('Stats')) data['Stats'] = updates['Stats'];
    if (updates.containsKey('Cosmetics')) {
      data['Cosmetics'] = updates['Cosmetics'];
    }
    if (updates.containsKey('Inventory')) {
      data['Inventory'] = updates['Inventory'];
    }
    if (updates.containsKey('Progress')) data['Progress'] = updates['Progress'];
    if (updates.containsKey('Settings')) data['Settings'] = updates['Settings'];
    if (updates.containsKey('Session')) data['Session'] = updates['Session'];

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
      {DateTime? createdAt,
      String? transactionId,
      int? balanceBefore,
      int? balanceAfter,
      String? description}) async {
    final rec = TransactionRecord(
      usd: usd,
      coins: coins,
      type: type,
      createdAt: createdAt ?? DateTime.now(),
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      description: description,
    );
    final col =
        _firestore.collection('users').doc(uid).collection('transactions');
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
    final legacyDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    DocumentSnapshot<Map<String, dynamic>>? legacyCursor;
    do {
      final page = await getLegacyTransactionsPage(uid,
          limit: 100, startAfter: legacyCursor);
      legacyDocs.addAll(page.rows);
      legacyCursor = page.cursor;
      if (!page.hasMore) break;
    } while (true);

    final List<Map<String, dynamic>> list = legacyDocs.map((doc) {
      final d = doc.data();
      final ts = d['createdAt'] as Timestamp?;
      final rawType = d['type'] as String? ?? 'purchase';
      return {
        'dateTime': ts?.toDate() ?? DateTime.now(),
        'usd': (d['usd'] as num?)?.toDouble() ?? 0,
        'coins': (d['coins'] as num?)?.toInt() ?? 0,
        'type': TransactionRecord.mapLegacyType(rawType),
        if (d['balanceBefore'] != null)
          'balanceBefore': (d['balanceBefore'] as num).toInt()
        else if (d['previousBalance'] != null)
          'balanceBefore': (d['previousBalance'] as num).toInt(),
        if (d['balanceAfter'] != null)
          'balanceAfter': (d['balanceAfter'] as num).toInt(),
        if (d['description'] != null) 'description': d['description'] as String,
        if (d['source'] != null) 'source': d['source'] as String,
        if (d['itemType'] != null) 'itemType': d['itemType'] as String,
        if (d['assetPath'] != null) 'assetPath': d['assetPath'] as String,
        if (d['title'] != null) 'title': d['title'] as String,
      };
    }).toList();

    // Wallet mutations are canonically recorded in wallet_ledger. Older UI
    // queried only the legacy transactions collection, which hid referrals,
    // mission rewards, arena bets/prizes/refunds, and newer store purchases.
    final ledgerDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    DocumentSnapshot<Map<String, dynamic>>? ledgerCursor;
    do {
      final page =
          await getWalletLedgerPage(uid, limit: 100, startAfter: ledgerCursor);
      ledgerDocs.addAll(page.rows);
      ledgerCursor = page.cursor;
      if (!page.hasMore) break;
    } while (true);
    for (final doc in ledgerDocs) {
      final d = doc.data();
      final ts = d['createdAt'] as Timestamp?;
      final delta = (d['delta'] as num?)?.toInt() ?? 0;
      list.add(<String, dynamic>{
        'dateTime': ts?.toDate() ?? DateTime.now(),
        'usd': 0.0,
        'coins': delta.abs(),
        'delta': delta,
        'type': (d['type'] ?? (delta >= 0 ? 'credit' : 'debit')).toString(),
        'transactionId': (d['transactionId'] ?? doc.id).toString(),
        if (d['before'] != null)
          'balanceBefore': (d['before'] as num).toInt()
        else if (d['balanceBefore'] != null)
          'balanceBefore': (d['balanceBefore'] as num).toInt(),
        if (d['after'] != null)
          'balanceAfter': (d['after'] as num).toInt()
        else if (d['balanceAfter'] != null)
          'balanceAfter': (d['balanceAfter'] as num).toInt(),
        if (d['message'] != null) 'description': d['message'].toString(),
        if (d['source'] != null) 'source': d['source'].toString(),
        if (d['itemType'] != null) 'itemType': d['itemType'].toString(),
        if (d['assetPath'] != null) 'assetPath': d['assetPath'].toString(),
        if (d['title'] != null) 'title': d['title'].toString(),
      });
    }
    // Dedupe by composite key (existing duplicates from before idempotency fix).
    return _dedupeTransactions(list);
  }

  Future<TransactionPage> getWalletLedgerPage(
    String uid, {
    int limit = 100,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) =>
      _getTransactionPage(uid, 'wallet_ledger', limit, startAfter);

  Future<TransactionPage> getLegacyTransactionsPage(
    String uid, {
    int limit = 100,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) =>
      _getTransactionPage(uid, 'transactions', limit, startAfter);

  Future<TransactionPage> _getTransactionPage(
    String uid,
    String collection,
    int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  ) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .doc(uid)
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snapshot = await query.get();
    return TransactionPage(
      snapshot.docs,
      snapshot.docs.isEmpty ? null : snapshot.docs.last,
      snapshot.docs.length == limit,
    );
  }

  /// Dedupe transaction list by (dateTime, coins, type) keeping first occurrence.
  static List<Map<String, dynamic>> _dedupeTransactions(
      List<Map<String, dynamic>> list) {
    final seen = <String>{};
    return list.where((e) {
      final transactionId = (e['transactionId'] ?? '').toString();
      if (transactionId.isNotEmpty) return seen.add('id:$transactionId');
      final dt = e['dateTime'] as DateTime?;
      final coins = e['coins'] as int? ?? 0;
      final type = e['type'] as String? ?? '';
      final key = '${dt?.millisecondsSinceEpoch ?? 0}_${coins}_$type';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }

  /// Clears volatile authentication state only. Durable wallet history and
  /// pending ledger uploads are intentionally not part of session state.
  Future<void> clearSessionCacheOnly() async {
    final p = await _sp();
    await p.setBool(Keys.loggedIn, false);
  }

  /// Clears online profile/UI cache for logout while preserving every
  /// user-scoped history, pending queue, migration marker and offline key.
  Future<void> clearUserProfileCacheForLogout() async {
    final p = await _sp();
    await clearLogoutPreferences(p);

    LocalStore.equippedAvatarNotifier.value = 0;
    LocalStore.cosmeticsVersion.value++;
  }

  @visibleForTesting
  static Future<void> clearLogoutPreferences(SharedPreferences p) async {
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
    await p.remove(Keys.equippedAvatar);
    await p.remove(Keys.ownedAvatars);
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

  /// Backward-compatible logout API. It must never clear durable history.
  Future<void> clearLocalCache() => clearUserProfileCacheForLogout();

  /// Local destructive clear for the explicit, confirmed account-deletion
  /// flow only. AuthService also deletes the remote account data there.
  Future<void> clearAllUserDataForAccountDeletion() async {
    final p = await _sp();
    await p.clear();
    LocalStore.equippedAvatarNotifier.value = 0;
    LocalStore.coinsNotifier.value = 0;
    LocalStore.cosmeticsVersion.value++;
  }
}
