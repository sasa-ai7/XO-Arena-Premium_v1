import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/keys.dart';
import 'app_mode_service.dart';

/// Wallet service for the OFFLINE (Guest) profile.
///
/// Reads and writes [Keys.offlineCoinsV2] — completely separate from the
/// online wallet ([Keys.coins]).
///
/// ▸ NEVER reads from or writes to Firestore.
/// ▸ NEVER touches online wallet keys ([Keys.coins]).
/// ▸ All operations silently no-op when AppMode is not [AppMode.offline].
///   This prevents accidental offline wallet mutations from online code paths.
class OfflineWalletService {
  static final OfflineWalletService _instance = OfflineWalletService._();
  factory OfflineWalletService() => _instance;
  OfflineWalletService._();

  // ── Internal helpers ──────────────────────────────────────────────────────

  static Future<SharedPreferences> _sp() => SharedPreferences.getInstance();

  /// Returns false and prints a guard log if not in pure offline mode.
  bool _assertOffline(String op) {
    if (AppModeService.current != AppMode.offline) {
      if (kDebugMode) {
        debugPrint('[GUARD] skipped OfflineWallet.$op — AppMode=${AppModeService.current}');
      }
      return false;
    }
    return true;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Read the current offline balance from SharedPreferences.
  Future<int> getBalance() async {
    final p = await _sp();
    return p.getInt(Keys.offlineCoinsV2) ?? 200;
  }

  /// Deduct [amount] from the offline wallet. Returns the new balance.
  /// No-ops silently if not in [AppMode.offline].
  Future<int> deduct(int amount, {required ValueNotifier<int> coinsNotifier}) async {
    if (!_assertOffline('deduct')) return coinsNotifier.value;
    final p = await _sp();
    final current = p.getInt(Keys.offlineCoinsV2) ?? 200;
    final newBal = max(0, current - amount);
    await p.setInt(Keys.offlineCoinsV2, newBal);
    coinsNotifier.value = newBal;
    if (kDebugMode) debugPrint('[OfflineWallet] deduct $amount → balance=$newBal');
    return newBal;
  }

  /// Credit [amount] to the offline wallet. Returns the new balance.
  Future<int> credit(int amount, {required ValueNotifier<int> coinsNotifier}) async {
    if (!_assertOffline('credit')) return coinsNotifier.value;
    final p = await _sp();
    final current = p.getInt(Keys.offlineCoinsV2) ?? 200;
    final newBal = current + amount;
    await p.setInt(Keys.offlineCoinsV2, newBal);
    coinsNotifier.value = newBal;
    if (kDebugMode) debugPrint('[OfflineWallet] credit $amount → balance=$newBal');
    return newBal;
  }

  /// Overwrite the offline balance directly (e.g., from profile load).
  /// Can be called regardless of AppMode — used during the offline setup flow.
  Future<void> setBalance(int amount, {required ValueNotifier<int> coinsNotifier}) async {
    final p = await _sp();
    final safe = max(0, amount);
    await p.setInt(Keys.offlineCoinsV2, safe);
    coinsNotifier.value = safe;
    if (kDebugMode) debugPrint('[OfflineWallet] setBalance → $safe');
  }
}
