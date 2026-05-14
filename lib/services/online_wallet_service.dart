import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/keys.dart';
import 'app_mode_service.dart';

/// Wallet service for the ONLINE (Firestore) account.
///
/// Reads and writes [Keys.coins] — the local SharedPreferences mirror of
/// the Firestore wallet. Every mutating operation also writes through to
/// Firestore, but ONLY when [AppModeService.canUseOnlineServices] is true.
///
/// ▸ NEVER touches offline wallet keys ([Keys.offlineCoinsV2]).
/// ▸ NEVER writes to Firestore when [AppModeService.isOfflineLike] is true.
/// ▸ The server (Firestore / Cloud Functions) is always authoritative.
///   Call [setFromServer] after a Firestore pull to overwrite the local cache.
class OnlineWalletService {
  static final OnlineWalletService _instance = OnlineWalletService._();
  factory OnlineWalletService() => _instance;
  OnlineWalletService._();

  // ── Internal helpers ──────────────────────────────────────────────────────

  static Future<SharedPreferences> _sp() => SharedPreferences.getInstance();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Returns false and prints a guard log if not in a safe online mode.
  bool _assertOnline(String op) {
    if (!AppModeService.canUseOnlineServices) {
      if (kDebugMode) {
        debugPrint('[GUARD] skipped OnlineWallet.$op — AppMode=${AppModeService.current}');
      }
      return false;
    }
    return true;
  }

  Future<void> _pushToFirestore(int balance) async {
    final uid = _uid;
    if (uid == null) return;
    if (!AppModeService.canUseOnlineServices) {
      if (kDebugMode) debugPrint('[GUARD] skipped Firestore wallet write — not safely online');
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'Wallet': <String, dynamic>{'coins': balance}},
              SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[OnlineWallet] Firestore write error: $e');
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Read the current online balance from the local cache (no Firestore call).
  Future<int> getBalance() async {
    if (!_assertOnline('getBalance')) return 0;
    final p = await _sp();
    return p.getInt(Keys.coins) ?? 0;
  }

  /// Deduct [amount] from the online wallet. Returns the new balance.
  /// No-ops silently if not in online mode.
  Future<int> deduct(int amount, {required ValueNotifier<int> coinsNotifier}) async {
    if (!_assertOnline('deduct')) return coinsNotifier.value;
    final p = await _sp();
    final current = p.getInt(Keys.coins) ?? 0;
    final newBal = max(0, current - amount);
    await p.setInt(Keys.coins, newBal);
    coinsNotifier.value = newBal;
    if (kDebugMode) debugPrint('[OnlineWallet] deduct $amount → balance=$newBal');
    await _pushToFirestore(newBal);
    return newBal;
  }

  /// Credit [amount] to the online wallet. Returns the new balance.
  Future<int> credit(int amount, {required ValueNotifier<int> coinsNotifier}) async {
    if (!_assertOnline('credit')) return coinsNotifier.value;
    final p = await _sp();
    final current = p.getInt(Keys.coins) ?? 0;
    final newBal = current + amount;
    await p.setInt(Keys.coins, newBal);
    coinsNotifier.value = newBal;
    if (kDebugMode) debugPrint('[OnlineWallet] credit $amount → balance=$newBal');
    await _pushToFirestore(newBal);
    return newBal;
  }

  /// Overwrite the local cache with a server-authoritative balance.
  /// Called after [UserRepo.pullServerToLocal] or a Cloud Function response.
  Future<void> setFromServer(int serverBalance,
      {required ValueNotifier<int> coinsNotifier}) async {
    final p = await _sp();
    final safe = max(0, serverBalance);
    await p.setInt(Keys.coins, safe);
    coinsNotifier.value = safe;
    if (kDebugMode) debugPrint('[OnlineWallet] setFromServer → balance=$safe');
  }
}
