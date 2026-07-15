// `Transaction` exists in both cloud_firestore and firebase_database. We
// only reference Firestore's transaction type via the inferred `txn`
// parameter of `_fs.runTransaction(...)`, so hide that name here and keep
// the RTDB Transaction.success/abort helpers reachable unambiguously.
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_config.dart';
import '../../core/keys.dart';
import '../../models/arena/arena_room.dart';
import '../local_store.dart';
import '../wallet_ledger_types.dart';
import '../wallet_transaction_service.dart';
import 'arena_repo.dart';

/// Coin-bet operations for friend rooms.
///
/// **All public methods short-circuit when [AppConfig.kEnableFriendRoomBetting]
/// is false.**
///
/// Wallet mutations use Firestore transactions on `users/{uid}.Wallet.coins`
/// to avoid the lost-update race the plain client-authoritative wallet would
/// suffer when two devices interact with the same room. After a transaction
/// commits, the local SharedPreferences cache (`Keys.coins`) and the
/// reactive [LocalStore.coinsNotifier] are mirrored so the UI stays in sync.
///
/// Idempotency for prize payout is enforced four ways:
///  1. A SharedPreferences set of processed `transactionId`s
///     (`Keys.loggedTransactionIds`) — populated by
///     [LocalStore.addTopupHistory].
///  2. A live RTDB read of the room state before any wallet write —
///     validates `roomWinnerUid == selfUid` and `leftByUid != selfUid`
///     against the *server* (never the local in-memory snapshot).
///  3. An atomic RTDB transaction that flips `payoutApplied`/`prizePaid`
///     from false to true — only one client can win this transaction, so
///     a stale local snapshot or a double-listener fire can never trigger
///     a loser-side payout.
///  4. A Firestore transaction on `users/{uid}/wallet_ledger/{txnId}` that
///     short-circuits if a ledger row with the same deterministic id
///     already exists (cross-device replay safety).
///
/// TODO: Move Arena paid bet payout to Cloud Function before production
/// economy launch. The client-side guards above are defense-in-depth but
/// the wallet write is still client-authoritative today.
class ArenaBetService {
  ArenaBetService._();

  static final FirebaseFirestore _fs = FirebaseFirestore.instance;

  static DatabaseReference get _roomsRef => FirebaseDatabase.instanceFor(
        app: FirebaseDatabase.instance.app,
        databaseURL: kArenaDatabaseUrl,
      ).ref('rooms');

  static Future<bool> _alreadyApplied(String transactionId) async {
    final p = await SharedPreferences.getInstance();
    final logged = p.getString(Keys.loggedTransactionIds) ?? '';
    return logged
        .split(',')
        .where((s) => s.isNotEmpty)
        .toSet()
        .contains(transactionId);
  }

  /// Each player calls this for themselves during the countdown to debit
  /// their entry. Returns true on success, false on failure (no balance,
  /// flag off, etc.).
  static Future<bool> lockOwnBet({
    required ArenaRoom room,
    required String selfUid,
  }) async {
    if (!AppConfig.kEnableFriendRoomBetting) return false;
    if (!room.betEnabled) return false;
    if (room.betAmount <= 0) return false;

    // Fast path: if the RTDB already reflects our lock, skip every Firestore
    // call and the prefs read — this is the common re-entry case from the
    // arena room listener.
    if (room.betLocks[selfUid] == true || room.coinsLocked) {
      return true;
    }
    final lockRef = _roomsRef.child('${room.roomCode}/betLocks/$selfUid');
    final liveLockSnap = await lockRef.get();
    if (liveLockSnap.value == true) {
      return true;
    }

    final transactionId = '${room.matchId}_bet_$selfUid';
    if (await _alreadyApplied(transactionId)) {
      // Same device replay: wallet already debited locally but the RTDB lock
      // never made it. Repair the RTDB flag silently.
      await lockRef.set(true);
      return true;
    }

    try {
      final userRef = _fs.collection('users').doc(selfUid);
      final ledgerRef = userRef.collection('wallet_ledger').doc(transactionId);
      // Single Firestore transaction: ledger guard + balance check + debit.
      // Prevents a fresh device install (where SharedPrefs is empty) from
      // double-debiting if RTDB lockflag write was lost.
      final result = await _fs.runTransaction<Map<String, int>?>((txn) async {
        final ledgerSnap = await txn.get(ledgerRef);
        if (ledgerSnap.exists) {
          // Already debited cross-device — return the existing balance so we
          // can mirror local cache below without re-debiting.
          return const <String, int>{'already': 1};
        }
        final snap = await txn.get(userRef);
        final wallet = (snap.data()?['Wallet'] as Map?) ?? const {};
        final current = (wallet['coins'] as num?)?.toInt() ?? 0;
        if (current < room.betAmount) return null;
        final newBalance = current - room.betAmount;
        txn.set(
          userRef,
          <String, dynamic>{
            'Wallet': <String, dynamic>{'coins': newBalance},
          },
          SetOptions(merge: true),
        );
        txn.set(ledgerRef, <String, dynamic>{
          'uid': selfUid,
          'type': LedgerType.friendRoomBetEntry,
          'source': LedgerType.friendRoomBetEntry,
          'delta': -room.betAmount,
          'coins': room.betAmount,
          'before': current,
          'after': newBalance,
          'transactionId': transactionId,
          'title': 'Friend Room Bet Entry',
          'mode': 'online',
          'status': 'synced',
          'localCreatedAtMs': DateTime.now().millisecondsSinceEpoch,
          'roomCode': room.roomCode,
          'matchId': room.matchId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return <String, int>{
          'before': current,
          'after': newBalance,
        };
      });
      if (result == null) {
        if (kDebugMode) {
          debugPrint('[ARENA_BET] insufficient coins uid=$selfUid');
        }
        return false;
      }
      if (result['already'] == 1) {
        // Repair RTDB lock and exit — no local mutation needed.
        await lockRef.set(true);
        return true;
      }
      // Mirror local cache + reactive notifier.
      final p = await SharedPreferences.getInstance();
      await p.setInt(Keys.coins, result['after']!);
      LocalStore.coinsNotifier.value = result['after']!;

      // Mirror the already-committed remote ledger row locally — the Firestore
      // transaction above wrote both Wallet.coins and the wallet_ledger doc, so
      // this only refreshes the local history cache (idempotent upload no-ops).
      await WalletTransactionService.instance.recordExistingRemoteLedgerLocally(
        uid: selfUid,
        delta: -room.betAmount,
        transactionId: transactionId,
        source: LedgerType.friendRoomBetEntry,
        title: 'Friend Room Bet Entry',
        message: 'Friend Room Bet Entry',
        balanceBefore: result['before'],
        balanceAfter: result['after'],
      );
      await _roomsRef.child('${room.roomCode}/betLocks/$selfUid').set(true);
      if (kDebugMode) {
        debugPrint(
            '[ARENA_BET] debit success uid=$selfUid amount=${room.betAmount}');
        debugPrint(
            '[ARENA_BET] locked bet uid=$selfUid amount=${room.betAmount} prizePool=${room.betAmount * 2}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ARENA_BET] lockOwnBet error: $e');
      return false;
    }
  }

  /// Mark the RTDB room as having coins locked only after both users have
  /// successfully deducted their own entry fee.
  static Future<bool> markRoomCoinsLockedIfBoth({
    required ArenaRoom room,
  }) async {
    if (!AppConfig.kEnableFriendRoomBetting) return false;
    if (!room.betEnabled || room.betAmount <= 0) return false;
    final guestUid = room.guestUid;
    if (guestUid == null || guestUid.isEmpty) return false;

    final snap = await _roomsRef.child(room.roomCode).get();
    if (!snap.exists) return false;
    final raw = (snap.value as Map?) ?? const {};
    final locks = (raw['betLocks'] as Map?) ?? const {};
    final hostLocked = locks[room.hostUid] == true;
    final guestLocked = locks[guestUid] == true;
    if (!hostLocked || !guestLocked) {
      if (kDebugMode) {
        debugPrint(
            '[ARENA_BET] waiting for bet locks host=$hostLocked guest=$guestLocked code=${room.roomCode}');
      }
      return false;
    }

    await _roomsRef.child(room.roomCode).update(<String, Object?>{
      'coinsLocked': true,
      'prizePool': room.betAmount * 2,
      'potAmount': room.betAmount * 2,
      'updatedAt': ServerValue.timestamp,
    });
    if (kDebugMode) {
      debugPrint(
          '[ARENA_BET] both bets locked code=${room.roomCode} prizePool=${room.betAmount * 2}');
    }
    return true;
  }

  @Deprecated('Use markRoomCoinsLockedIfBoth')
  static Future<void> markRoomCoinsLocked({
    required String code,
    required int prizePool,
  }) async {
    if (!AppConfig.kEnableFriendRoomBetting) return;
    await _roomsRef.child(code).update(<String, Object?>{
      'coinsLocked': true,
      'prizePool': prizePool,
      'potAmount': prizePool,
      'updatedAt': ServerValue.timestamp,
    });
  }

  /// Credit the winner with the prizePool.
  ///
  /// Returns `true` when this caller is the legitimate winner and the prize
  /// is now applied to their wallet (or was already applied by an earlier
  /// session of the same user). Returns `false` for *every* loser/leaver/
  /// non-winner case — callers can use the bool to decide whether to render
  /// "+coins" in the final result UI.
  ///
  /// The function takes the in-memory [room] only for `roomCode`,
  /// `prizePool`, `matchId`, and bet-lock metadata. The winner/loser/leftBy
  /// decision is made by reading the *live* RTDB room and by an atomic
  /// RTDB transaction. A stale local snapshot cannot trick this function
  /// into crediting a loser.
  static Future<bool> creditPrize({
    required ArenaRoom room,
    required String selfUid,
  }) async {
    if (!AppConfig.kEnableFriendRoomBetting) return false;
    if (!room.betEnabled || !room.coinsLocked) return false;
    final guestUid = room.guestUid;
    if (guestUid == null ||
        room.betLocks[room.hostUid] != true ||
        room.betLocks[guestUid] != true) {
      if (kDebugMode) {
        debugPrint(
            '[ARENA_BET] payout blocked: both bet locks are not confirmed');
      }
      return false;
    }
    if (room.prizePool <= 0) return false;

    if (kDebugMode) {
      debugPrint(
          '[ARENA_BET] payout check room=${room.roomCode} self=$selfUid');
    }

    final liveRef = _roomsRef.child(room.roomCode);

    // ── Live RTDB read — never trust the in-memory ArenaRoom snapshot. ────
    Map<Object?, Object?>? live;
    try {
      final liveSnap = await liveRef.get().timeout(const Duration(seconds: 5));
      final raw = liveSnap.value;
      if (raw is Map) {
        live = Map<Object?, Object?>.from(raw);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ARENA_BET] payout blocked: live read failed: $e');
      }
      return false;
    }
    if (live == null) {
      if (kDebugMode) {
        debugPrint('[ARENA_BET] payout blocked: room missing/non-map');
      }
      return false;
    }

    final liveStatus = live['status']?.toString();
    final liveWinnerUid =
        (live['roomWinnerUid'] ?? live['winnerUid'])?.toString();
    final liveLoserUid = live['loserUid']?.toString();
    final liveLeftByUid = live['leftByUid']?.toString();
    final alreadyPaid =
        live['payoutApplied'] == true || live['prizePaid'] == true;

    if (liveStatus != 'finished') {
      if (kDebugMode) {
        debugPrint('[ARENA_BET] payout blocked: status=$liveStatus');
      }
      return false;
    }
    if (liveWinnerUid == null ||
        liveWinnerUid.isEmpty ||
        liveWinnerUid != selfUid) {
      if (kDebugMode) {
        debugPrint('[ARENA_BET] payout blocked: reason=notWinner '
            'self=$selfUid winner=$liveWinnerUid');
      }
      return false;
    }
    if (liveLoserUid == selfUid || liveLeftByUid == selfUid) {
      if (kDebugMode) {
        debugPrint('[ARENA_BET] payout blocked: reason=loserOrLeft '
            'self=$selfUid loser=$liveLoserUid leftBy=$liveLeftByUid');
      }
      return false;
    }

    final transactionId = '${room.matchId}_prize_$selfUid';
    final resultReason = (live['finalResult'] ??
            live['result'] ??
            room.finalResult ??
            room.result)
        ?.toString();
    final prizeSource = resultReason == 'disconnect_forfeit' ||
            resultReason == 'forfeit' ||
            (liveLeftByUid != null && liveLeftByUid.isNotEmpty)
        ? LedgerType.disconnectForfeitPrize
        : LedgerType.friendRoomPrize;
    if (await _alreadyApplied(transactionId)) {
      // Same-device replay — wallet was credited locally on a previous run.
      // Repair the RTDB flag silently and report success so the caller still
      // renders the "+coins" UI for this winner.
      try {
        await liveRef.update(<String, Object?>{
          'payoutApplied': true,
          'prizePaid': true,
        });
      } catch (_) {}
      return true;
    }

    if (alreadyPaid) {
      // Another client (or an earlier session of this same user on another
      // device) already paid. Mirror coins from server, do NOT double-credit,
      // but DO report success — the user is the legitimate winner.
      if (kDebugMode) {
        debugPrint('[ARENA_BET] payout blocked: alreadyPaid (mirroring coins)');
      }
      try {
        final userRef = _fs.collection('users').doc(selfUid);
        final snap = await userRef.get();
        final coins =
            ((snap.data()?['Wallet'] as Map?)?['coins'] as num?)?.toInt();
        if (coins != null) {
          final p = await SharedPreferences.getInstance();
          await p.setInt(Keys.coins, coins);
          LocalStore.coinsNotifier.value = coins;
        }
      } catch (_) {}
      return true;
    }

    // ── Atomic RTDB transaction — only one client can flip payoutApplied. ─
    // Re-validates every guard against the server's CURRENT state so any
    // race between the host's finishRoom write and the listener tick is
    // resolved by the database, not by the client.
    TransactionResult txnRes;
    try {
      txnRes = await liveRef.runTransaction((Object? current) {
        if (current is! Map) return Transaction.abort();
        final map = Map<Object?, Object?>.from(current);
        final status = map['status']?.toString();
        final winnerUid =
            (map['roomWinnerUid'] ?? map['winnerUid'])?.toString();
        final loserUid = map['loserUid']?.toString();
        final leftByUid = map['leftByUid']?.toString();
        final paid = map['payoutApplied'] == true || map['prizePaid'] == true;
        if (status != 'finished') return Transaction.abort();
        if (winnerUid == null || winnerUid.isEmpty || winnerUid != selfUid) {
          return Transaction.abort();
        }
        if (loserUid == selfUid || leftByUid == selfUid) {
          return Transaction.abort();
        }
        if (paid) return Transaction.abort();
        map['payoutApplied'] = true;
        map['prizePaid'] = true;
        return Transaction.success(map);
      }).timeout(const Duration(seconds: 6));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ARENA_BET] payout blocked: transaction error: $e');
      }
      return false;
    }
    if (!txnRes.committed) {
      if (kDebugMode) {
        debugPrint('[ARENA_BET] payout blocked: transaction not committed');
      }
      return false;
    }
    if (kDebugMode) {
      debugPrint('[ARENA_BET] payout locked room=${room.roomCode} '
          'winner=$selfUid amount=${room.prizePool}');
    }

    // ── Wallet credit (Firestore txn). RTDB flag is already set, so even
    //    if this Firestore write fails the loser can never claim the prize.
    try {
      final userRef = _fs.collection('users').doc(selfUid);
      final ledgerRef = userRef.collection('wallet_ledger').doc(transactionId);
      final result = await _fs.runTransaction<Map<String, int>?>((txn) async {
        final ledgerSnap = await txn.get(ledgerRef);
        if (ledgerSnap.exists) return null; // already paid cross-device
        final snap = await txn.get(userRef);
        final wallet = (snap.data()?['Wallet'] as Map?) ?? const {};
        final current = (wallet['coins'] as num?)?.toInt() ?? 0;
        final newBalance = current + room.prizePool;
        txn.set(
          userRef,
          <String, dynamic>{
            'Wallet': <String, dynamic>{'coins': newBalance},
          },
          SetOptions(merge: true),
        );
        txn.set(ledgerRef, <String, dynamic>{
          'uid': selfUid,
          'type': LedgerType.friendRoomPrize,
          'source': prizeSource,
          'delta': room.prizePool,
          'coins': room.prizePool,
          'before': current,
          'after': newBalance,
          'transactionId': transactionId,
          'title': 'Friend Room Prize',
          'mode': 'online',
          'status': 'synced',
          'localCreatedAtMs': DateTime.now().millisecondsSinceEpoch,
          'roomCode': room.roomCode,
          'matchId': room.matchId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return <String, int>{
          'before': current,
          'after': newBalance,
        };
      });
      if (result == null) {
        // Ledger row already existed cross-device — mirror coins, do NOT
        // unset the RTDB payoutApplied flag we just claimed.
        try {
          final snap = await userRef.get();
          final coins =
              ((snap.data()?['Wallet'] as Map?)?['coins'] as num?)?.toInt();
          if (coins != null) {
            final p = await SharedPreferences.getInstance();
            await p.setInt(Keys.coins, coins);
            LocalStore.coinsNotifier.value = coins;
          }
        } catch (_) {}
        return true;
      }
      final p = await SharedPreferences.getInstance();
      await p.setInt(Keys.coins, result['after']!);
      LocalStore.coinsNotifier.value = result['after']!;

      await WalletTransactionService.instance.recordExistingRemoteLedgerLocally(
        uid: selfUid,
        delta: room.prizePool,
        transactionId: transactionId,
        source: prizeSource,
        title: 'Friend Room Prize',
        message: 'Friend Room Prize',
        balanceBefore: result['before'],
        balanceAfter: result['after'],
      );
      if (kDebugMode) {
        debugPrint(
            '[ARENA_BET] payout success winner=$selfUid amount=${room.prizePool}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ARENA_BET] creditPrize wallet error: $e');
      return false;
    }
  }

  /// Refund the player's own entry (called when an expiry forces a no-op end).
  static Future<void> refundOwnBet({
    required ArenaRoom room,
    required String selfUid,
  }) async {
    if (!AppConfig.kEnableFriendRoomBetting) return;
    if (!room.betEnabled || !room.coinsLocked) return;
    if (room.betAmount <= 0) return;

    final transactionId = '${room.matchId}_refund_$selfUid';
    if (await _alreadyApplied(transactionId)) return;

    try {
      final userRef = _fs.collection('users').doc(selfUid);
      final ledgerRef = userRef.collection('wallet_ledger').doc(transactionId);
      final result = await _fs.runTransaction<Map<String, int>?>((txn) async {
        final ledger = await txn.get(ledgerRef);
        if (ledger.exists) return null;
        final snap = await txn.get(userRef);
        final wallet = (snap.data()?['Wallet'] as Map?) ?? const {};
        final current = (wallet['coins'] as num?)?.toInt() ?? 0;
        final newBalance = current + room.betAmount;
        txn.set(
          userRef,
          <String, dynamic>{
            'Wallet': <String, dynamic>{'coins': newBalance},
          },
          SetOptions(merge: true),
        );
        txn.set(ledgerRef, <String, dynamic>{
          'uid': selfUid,
          'type': LedgerType.friendRoomRefund,
          'source': LedgerType.friendRoomRefund,
          'delta': room.betAmount,
          'coins': room.betAmount,
          'before': current,
          'after': newBalance,
          'transactionId': transactionId,
          'title': 'Friend Room Refund',
          'roomCode': room.roomCode,
          'matchId': room.matchId,
          'mode': 'online',
          'status': 'synced',
          'localCreatedAtMs': DateTime.now().millisecondsSinceEpoch,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return <String, int>{
          'before': current,
          'after': newBalance,
        };
      });
      if (result == null) return;
      final p = await SharedPreferences.getInstance();
      await p.setInt(Keys.coins, result['after']!);
      LocalStore.coinsNotifier.value = result['after']!;
      await WalletTransactionService.instance.recordExistingRemoteLedgerLocally(
        uid: selfUid,
        delta: room.betAmount,
        transactionId: transactionId,
        source: LedgerType.friendRoomRefund,
        title: 'Friend Room Refund',
        message: 'Friend Room Refund',
        balanceBefore: result['before'],
        balanceAfter: result['after'],
      );
      if (kDebugMode) {
        debugPrint(
            '[ARENA_BET] refund success uid=$selfUid amount=${room.betAmount}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ARENA_BET] refundOwnBet error: $e');
    }
  }
}
