import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/keys.dart';
import 'app_mode_service.dart';
import 'auth_service.dart';
import 'local_store.dart';
import 'wallet_history_service.dart';

/// Outcome of a wallet mutation routed through [WalletTransactionService].
class WalletTransactionResult {
  const WalletTransactionResult({
    required this.applied,
    required this.recorded,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.transactionId,
    this.reason,
  });

  /// The wallet balance actually changed.
  final bool applied;

  /// A durable history/ledger row was created for this transaction.
  final bool recorded;

  final int balanceBefore;
  final int balanceAfter;
  final String transactionId;

  /// null on a fresh success; otherwise one of
  /// 'zero' | 'blocked' | 'insufficient' | 'no_uid' | 'duplicate'.
  final String? reason;

  /// The economic effect for this [transactionId] is in place — either it was
  /// applied+recorded now, or it was already processed earlier (`duplicate`).
  /// Every call site gates its irreversible action (unlock, claim) on this.
  bool get success =>
      reason == null ? (applied && recorded) : reason == 'duplicate';

  factory WalletTransactionResult.rejected(
    int balance,
    String reason,
    String transactionId,
  ) =>
      WalletTransactionResult(
        applied: false,
        recorded: false,
        balanceBefore: balance,
        balanceAfter: balance,
        transactionId: transactionId,
        reason: reason,
      );
}

/// The single canonical entry point for every coin mutation in the app.
///
/// Guarantees the core invariant: **the wallet can never change without a
/// durable ledger row.** It records history FIRST (to SharedPreferences, which
/// is durable even offline and even before any network write), and only then
/// applies the wallet delta. If the row cannot be recorded, the wallet is left
/// untouched.
///
/// Trusted server-authoritative flows that already write their own canonical
/// `wallet_ledger` doc inside a Firestore transaction (arena bets, IAP grants)
/// must NOT go through [applyDelta] — they use
/// [recordExistingRemoteLedgerLocally] to mirror the already-committed row
/// locally without re-mutating the wallet.
class WalletTransactionService {
  /// Production default wires the singletons; tests inject fakes for every
  /// seam so the whole apply/record flow runs without Firebase.
  WalletTransactionService({
    WalletHistoryService? historyService,
    String? Function()? uidProvider,
    int Function()? balanceReader,
    Future<void> Function(int delta)? walletMutator,
    PreferencesLoader? preferencesLoader,
    bool Function()? isOfflineMode,
    bool Function()? canUseOnline,
  })  : _history = historyService ?? WalletHistoryService.instance,
        _uidProvider = uidProvider ??
            (() => AuthService().currentUser?.uid ?? LocalStore.uid),
        _readBalance = balanceReader ?? (() => LocalStore.coinsNotifier.value),
        _applyWallet = walletMutator ?? LocalStore.updateCoins,
        _prefs = preferencesLoader ?? SharedPreferences.getInstance,
        _isOffline =
            isOfflineMode ?? (() => AppModeService.current == AppMode.offline),
        _canUseOnline =
            canUseOnline ?? (() => AppModeService.canUseOnlineServices);

  static final WalletTransactionService instance = WalletTransactionService();

  final WalletHistoryService _history;
  final String? Function() _uidProvider;
  final int Function() _readBalance;
  final Future<void> Function(int delta) _applyWallet;
  final PreferencesLoader _prefs;
  final bool Function() _isOffline;
  final bool Function() _canUseOnline;

  /// Credit [coins] (must be positive) to the wallet + ledger.
  Future<WalletTransactionResult> applyCredit({
    required int coins,
    required String transactionId,
    required String source,
    required String title,
    String? message,
    String? itemType,
    String? itemId,
    String? assetPath,
    String? roomCode,
    String? matchId,
    double usd = 0,
  }) {
    return applyDelta(
      delta: coins.abs(),
      transactionId: transactionId,
      source: source,
      title: title,
      message: message,
      itemType: itemType,
      itemId: itemId,
      assetPath: assetPath,
      roomCode: roomCode,
      matchId: matchId,
      usd: usd,
    );
  }

  /// Debit [coins] (pass a positive magnitude) from the wallet + ledger.
  /// Rejected without side effects when the balance is insufficient.
  Future<WalletTransactionResult> applyDebit({
    required int coins,
    required String transactionId,
    required String source,
    required String title,
    String? message,
    String? itemType,
    String? itemId,
    String? assetPath,
    String? roomCode,
    String? matchId,
    double usd = 0,
  }) {
    return applyDelta(
      delta: -coins.abs(),
      transactionId: transactionId,
      source: source,
      title: title,
      message: message,
      itemType: itemType,
      itemId: itemId,
      assetPath: assetPath,
      roomCode: roomCode,
      matchId: matchId,
      usd: usd,
    );
  }

  /// Apply a signed [delta] to the wallet, recording a ledger row first.
  ///
  /// Returns a [WalletTransactionResult]; callers gate irreversible actions
  /// (unlock, claim) on [WalletTransactionResult.success].
  Future<WalletTransactionResult> applyDelta({
    required int delta,
    required String transactionId,
    required String source,
    required String title,
    String? message,
    String? itemType,
    String? itemId,
    String? assetPath,
    String? roomCode,
    String? matchId,
    Map<String, dynamic>? metadata,
    double usd = 0,
  }) async {
    final before = _readBalance();

    // 1) Never fabricate a transaction for a no-op.
    if (delta == 0) {
      return WalletTransactionResult.rejected(before, 'zero', transactionId);
    }

    // 2) Mirror LocalStore.updateCoins' mode guards so we never record a row
    //    for a delta the wallet would silently reject.
    final offline = _isOffline();
    final writable = offline || _canUseOnline();
    if (!writable) {
      if (kDebugMode) {
        debugPrint('[WALLET_TX] blocked $transactionId '
            'mode=${AppModeService.current}');
      }
      return WalletTransactionResult.rejected(before, 'blocked', transactionId);
    }

    // 3) Reject insufficient-funds debits up front (updateCoins would otherwise
    //    silently clamp to 0 and record a wrong delta).
    if (delta < 0 && before + delta < 0) {
      if (kDebugMode) {
        debugPrint('[WALLET_TX] insufficient $transactionId '
            'need=${-delta} have=$before');
      }
      return WalletTransactionResult.rejected(
          before, 'insufficient', transactionId);
    }

    // 4) Idempotency: a given transactionId may move the LOCAL wallet at most
    //    once. Online atomic flows (arena/IAP) enforce this in Firestore; the
    //    client-authoritative flows that go through here rely on this guard so
    //    a retry / double-tap can never double-credit or double-debit.
    final prefs = await _prefs();
    final logged = (prefs.getString(Keys.loggedTransactionIds) ?? '')
        .split(',')
        .where((s) => s.isNotEmpty)
        .toSet();
    if (logged.contains(transactionId)) {
      if (kDebugMode) {
        debugPrint('[WALLET_TX] duplicate blocked $transactionId');
      }
      return WalletTransactionResult(
        applied: false,
        recorded: true,
        balanceBefore: before,
        balanceAfter: before,
        transactionId: transactionId,
        reason: 'duplicate',
      );
    }

    final after = before + delta;

    // 5) Record the ledger row FIRST — durable to SharedPreferences before any
    //    wallet mutation. If it cannot be recorded, leave the wallet untouched.
    final recorded = await _record(
      offline: offline,
      delta: delta,
      transactionId: transactionId,
      source: source,
      title: title,
      message: message,
      balanceBefore: before,
      balanceAfter: after,
      itemType: itemType,
      itemId: itemId,
      assetPath: assetPath,
      usd: usd,
    );
    if (!recorded) {
      return WalletTransactionResult.rejected(before, 'no_uid', transactionId);
    }

    // 6) Apply the wallet delta (mode-aware routing lives in updateCoins).
    await _applyWallet(delta);
    final newBalance = _readBalance();

    // 7) Mark processed so the same transactionId can't move the wallet again.
    logged.add(transactionId);
    await prefs.setString(Keys.loggedTransactionIds, logged.join(','));

    if (kDebugMode) {
      debugPrint('[WALLET_TX] applied $transactionId delta=$delta '
          'before=$before after=$newBalance source=$source');
    }

    return WalletTransactionResult(
      applied: newBalance != before,
      recorded: true,
      balanceBefore: before,
      balanceAfter: newBalance,
      transactionId: transactionId,
    );
  }

  Future<bool> _record({
    required bool offline,
    required int delta,
    required String transactionId,
    required String source,
    required String title,
    String? message,
    int? balanceBefore,
    int? balanceAfter,
    String? itemType,
    String? itemId,
    String? assetPath,
    double usd = 0,
  }) async {
    if (offline) {
      await _history.recordOffline(
        delta: delta,
        transactionId: transactionId,
        source: source,
        title: title,
        description: message,
        balanceBefore: balanceBefore,
        balanceAfter: balanceAfter,
        itemType: itemType,
        itemId: itemId,
        assetPath: assetPath,
        usd: usd,
      );
      return true;
    }
    final uid = _uidProvider();
    if (uid == null) return false;
    await _history.recordPending(
      uid: uid,
      delta: delta,
      transactionId: transactionId,
      source: source,
      title: title,
      description: message,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      itemType: itemType,
      itemId: itemId,
      assetPath: assetPath,
      usd: usd,
    );
    return true;
  }

  /// Mirror an already-committed remote ledger row locally.
  ///
  /// For trusted flows (arena bet Firestore transaction, IAP grant) the wallet
  /// and the canonical `wallet_ledger` doc were already written together. This
  /// only refreshes the local history cache; the idempotent upload is a no-op
  /// because the doc already exists, so it never double-mutates the wallet.
  Future<void> recordExistingRemoteLedgerLocally({
    required String uid,
    required int delta,
    required String transactionId,
    required String source,
    required String title,
    String? message,
    int? balanceBefore,
    int? balanceAfter,
    String? itemType,
    String? itemId,
    String? assetPath,
    double usd = 0,
  }) {
    return _history.recordPending(
      uid: uid,
      delta: delta,
      transactionId: transactionId,
      source: source,
      title: title,
      description: message,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      itemType: itemType,
      itemId: itemId,
      assetPath: assetPath,
      usd: usd,
    );
  }

  /// Display-only local history that MUST NOT write Firestore (Part 10). Use
  /// when a canonical ledger already exists elsewhere and only a local cache
  /// row is wanted for immediate UI feedback.
  Future<void> recordDisplayHistoryLocalOnly({
    required String uid,
    required int delta,
    required String transactionId,
    required String source,
    required String title,
    String? message,
    int? balanceBefore,
    int? balanceAfter,
    String? itemType,
    String? itemId,
    String? assetPath,
    double usd = 0,
  }) {
    return _history.recordLocalDisplayOnly(
      uid: uid,
      delta: delta,
      transactionId: transactionId,
      source: source,
      title: title,
      description: message,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      itemType: itemType,
      itemId: itemId,
      assetPath: assetPath,
      usd: usd,
    );
  }

  // ── Delegated reads / maintenance ─────────────────────────────────────────

  Future<void> flushPending(String uid) => _history.flushPending(uid);

  Future<void> migrateLegacyHistory(String uid) =>
      _history.migrateLegacyHistory(uid);

  Future<WalletHistoryReadResult> readMergedHistory(String? uid) =>
      _history.readMergedHistory(uid);
}
