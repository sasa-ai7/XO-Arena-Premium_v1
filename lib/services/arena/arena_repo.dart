import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../models/arena/arena_room.dart';
import '../app_mode_service.dart';
import 'arena_room_code.dart';

/// Errors returned by [ArenaRepo] in user-facing flows.
enum ArenaJoinError {
  notFound,
  full,
  expired,
  selfJoin,
  alreadyInActiveRoom,
  notWaiting,
  notEnoughCoins,
  networkTimeout,
  unknown,
}

class ArenaJoinResult {
  final ArenaRoom? room;
  final ArenaJoinError? error;
  const ArenaJoinResult.success(this.room) : error = null;
  const ArenaJoinResult.failure(this.error) : room = null;
  bool get isSuccess => room != null;
}

/// Maximum room lifetime from creation (10 minutes).
const int kArenaRoomTtlMs = 10 * 60 * 1000;

/// Project's EU-West RTDB instance URL. The default `FirebaseDatabase.instance`
/// hits the US region; we pin to the matching region so rules and latency
/// work as expected.
const String kArenaDatabaseUrl =
    'https://xo-arenaneon-clash-default-rtdb.europe-west1.firebasedatabase.app';

/// Repository for RTDB-backed friend rooms.
class ArenaRepo {
  ArenaRepo._();
  static final ArenaRepo instance = ArenaRepo._();

  late final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: kArenaDatabaseUrl,
  );
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  DatabaseReference get _roomsRef => _db.ref('rooms');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Bounded-future helper ────────────────────────────────────────────────
  //
  // Many of our reads/writes go through Firestore, which can stall
  // indefinitely on flaky DNS (`Unable to resolve host firestore.googleapis.com`
  // EAI_NODATA). `_withTimeoutOrNull` makes those calls fail soft within a
  // bounded window so the join flow can proceed (or surface a clean error)
  // instead of leaving the user staring at a spinner.
  Future<T?> _withTimeoutOrNull<T>(
    Future<T> future, {
    Duration timeout = const Duration(seconds: 5),
    String? label,
  }) async {
    try {
      return await future.timeout(timeout);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ARENA] net op ${label ?? ""} failed/timeout: $e');
      }
      return null;
    }
  }

  /// Safely coerce an RTDB snapshot value into a Dart map. Returns `null` when
  /// the node is missing OR contains a non-map value (string/list/scalar),
  /// which we treat as corrupt / not-a-room rather than crashing the join flow
  /// with a `TypeError: type 'String' is not a subtype of Map<...>`.
  Map<dynamic, dynamic>? _asRoomMap(Object? value) {
    if (value is Map) return Map<dynamic, dynamic>.from(value);
    return null;
  }

  // ── Active-room mirror (Firestore) ───────────────────────────────────────
  //
  // We keep a tiny pointer at users/{uid}/Arena/activeRoom so a client can
  // check "is the user already in a room?" without scanning RTDB.

  DocumentReference<Map<String, dynamic>> _activeRoomRef(String uid) =>
      _fs.collection('users').doc(uid).collection('Arena').doc('activeRoom');

  Future<String?> getActiveRoomCode(String uid) async {
    final snap = await _withTimeoutOrNull(
      _activeRoomRef(uid).get(),
      label: 'getActiveRoomCode',
    );
    if (snap == null || !snap.exists) return null;
    final code = (snap.data() ?? const {})['roomCode'] as String?;
    if (code == null || code.isEmpty) return null;
    return code;
  }

  Future<void> _setActiveRoomMirror(String uid, String code) async {
    if (!AppModeService.canUseOnlineServices) return;
    await _withTimeoutOrNull(
      _activeRoomRef(uid).set(<String, dynamic>{
        'roomCode': code,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      label: 'setActiveRoomMirror',
    );
  }

  Future<void> clearActiveRoomMirror(String uid) async {
    await _withTimeoutOrNull(
      _activeRoomRef(uid).delete(),
      label: 'clearActiveRoomMirror',
    );
  }

  /// Cleanup helper: if the mirror points at a room that is gone or
  /// finished/expired, drop it. Called when ArenaPage opens.
  Future<void> reconcileActiveRoomMirror(String uid) async {
    final code = await getActiveRoomCode(uid);
    if (code == null) return;
    final snap = await _withTimeoutOrNull(
      _roomsRef.child(code).get(),
      label: 'reconcileMirror.read',
    );
    if (snap == null) return;
    if (!snap.exists) {
      await clearActiveRoomMirror(uid);
      return;
    }
    final raw = _asRoomMap(snap.value);
    if (raw == null) {
      // Node is present but not a map (corrupt). Drop the stale pointer.
      await clearActiveRoomMirror(uid);
      return;
    }
    final status = (raw['status'] ?? '').toString();
    final expiresAt = (raw['expiresAt'] as num?)?.toInt() ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (status == 'finished' ||
        status == 'expired' ||
        status == 'abandoned' ||
        status == 'cancelled' ||
        (expiresAt > 0 && now > expiresAt)) {
      await clearActiveRoomMirror(uid);
    }
  }

  // ── Create / Join / Leave ────────────────────────────────────────────────

  /// Create a new friend room with full settings.
  ///
  /// - [roundMaps] length must equal [roundsCount]; entries are like "3x3".
  /// - When [bettingEnabled] is true and [betAmount] > 0 the room records
  ///   `betAmount` and `prizePool = betAmount * 2`; actual coin deduction
  ///   happens in [ArenaBetService] during countdown.
  /// - [hostProfile] is optional rich host metadata (avatar/skin/coinsAtJoin)
  ///   stored under `players[hostUid]`.
  Future<ArenaRoom> createRoom({
    required String hostName,
    String? hostPhoto,
    required int roundsCount,
    required List<String> roundMaps,
    required bool bettingEnabled,
    required int betAmount,
    Map<String, dynamic>? hostProfile,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Not signed in.');
    }
    if (roundMaps.length != roundsCount) {
      throw ArgumentError(
          'roundMaps length ${roundMaps.length} != roundsCount $roundsCount');
    }
    final code = await ArenaRoomCode.allocate(roomsRef: _roomsRef);
    final now = DateTime.now().millisecondsSinceEpoch;
    final matchId = 'arena_${code}_${now}_$uid';

    final firstMap = roundMaps.first;
    final firstBoardSize = int.tryParse(firstMap.split('x').first) ?? 3;
    final cellCount = firstBoardSize * firstBoardSize;
    final emptyBoard = List<String>.filled(cellCount, '');

    // Randomly assign X/O between host and (future) guest. Guest will be
    // bound when they join — we just pre-assign host's symbol now.
    final hostIsX = Random.secure().nextBool();
    final xUid = hostIsX ? uid : '__pending__';
    final oUid = hostIsX ? '__pending__' : uid;

    final pot = bettingEnabled ? betAmount * 2 : 0;

    final hostPlayerEntry = <String, dynamic>{
      'uid': uid,
      'name': hostName,
      if (hostPhoto != null && hostPhoto.isNotEmpty) 'photoURL': hostPhoto,
      if (hostProfile != null) ...hostProfile,
    };

    final room = ArenaRoom(
      roomCode: code,
      hostUid: uid,
      hostName: hostName,
      hostPhoto: hostPhoto,
      // Host is implicitly ready by virtue of creating the room (no Ready
      // button is shown to the host in the lobby).
      hostReady: true,
      guestUid: null,
      guestName: null,
      guestPhoto: null,
      guestReady: false,
      status: 'waiting',
      boardSize: firstBoardSize,
      board: emptyBoard,
      roundsCount: roundsCount,
      currentRound: 1,
      currentRoundIndex: 0,
      roundMaps: roundMaps,
      scoreHost: 0,
      scoreGuest: 0,
      xUid: xUid,
      oUid: oUid,
      turnUid: null,
      roundWinnerUid: null,
      roomWinnerUid: null,
      result: null,
      finalResult: null,
      betEnabled: bettingEnabled,
      betAmount: bettingEnabled ? betAmount : 0,
      prizePool: pot,
      coinsLocked: false,
      payoutApplied: false,
      betLocks: <String, bool>{},
      players: <String, dynamic>{uid: hostPlayerEntry},
      createdAt: now,
      updatedAt: now,
      startedAt: null,
      expiresAt: now + kArenaRoomTtlMs,
      finishedAt: null,
      matchId: matchId,
    );

    await _roomsRef.child(code).set(room.toMap());
    await _setActiveRoomMirror(uid, code);
    if (kDebugMode) debugPrint('[ARENA] created room code=$code');
    return room;
  }

  /// Attempts to join a 6-digit room as guest.
  ///
  /// Uses an RTDB transaction so that two simultaneous join attempts cannot
  /// both bind themselves as guest.
  Future<ArenaJoinResult> joinRoom({
    required String code,
    required String guestName,
    String? guestPhoto,
    int? joinerCoins,
    Map<String, dynamic>? guestProfile,
  }) async {
    final uid = _uid;
    if (uid == null) return const ArenaJoinResult.failure(ArenaJoinError.unknown);
    if (kDebugMode) debugPrint('[ARENA] join attempt code=$code');

    // Reconcile any stale active-room pointer BEFORE the guard. The pointer
    // could outlive a crashed session / finished room, which would otherwise
    // surface as a misleading "Room is full" or "Already in a room" error
    // on the user's first tap on a fresh code.
    await reconcileActiveRoomMirror(uid);

    // Active room guard.
    final activeCode = await getActiveRoomCode(uid);
    if (kDebugMode) debugPrint('[ARENA] activeRoom=$activeCode requested=$code');
    if (activeCode != null && activeCode != code) {
      if (kDebugMode) debugPrint('[ARENA] join failed code=$code reason=alreadyInActiveRoom');
      return const ArenaJoinResult.failure(ArenaJoinError.alreadyInActiveRoom);
    }

    final ref = _roomsRef.child(code);
    if (kDebugMode) debugPrint('[ARENA] join reading RTDB room code=$code');
    final preSnap = await _withTimeoutOrNull(
      ref.get(),
      timeout: const Duration(seconds: 6),
      label: 'joinRoom.preSnap',
    );
    if (preSnap == null) {
      if (kDebugMode) debugPrint('[ARENA] join read timeout code=$code');
      return const ArenaJoinResult.failure(ArenaJoinError.networkTimeout);
    }
    if (kDebugMode) debugPrint('[ARENA] join room exists=${preSnap.exists} code=$code');
    if (!preSnap.exists) {
      if (kDebugMode) debugPrint('[ARENA] join failed code=$code reason=notFound');
      return const ArenaJoinResult.failure(ArenaJoinError.notFound);
    }
    final raw = _asRoomMap(preSnap.value);
    if (raw == null) {
      if (kDebugMode) debugPrint('[ARENA] join failed code=$code reason=corruptOrMissing');
      return const ArenaJoinResult.failure(ArenaJoinError.notFound);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = (raw['expiresAt'] as num?)?.toInt() ?? 0;
    if (expiresAt > 0 && now > expiresAt) {
      if (kDebugMode) debugPrint('[ARENA] join failed code=$code reason=expired expiresAt=$expiresAt now=$now');
      return const ArenaJoinResult.failure(ArenaJoinError.expired);
    }
    final hostUid = (raw['hostUid'] ?? '').toString();
    if (hostUid == uid) {
      if (kDebugMode) debugPrint('[ARENA] join failed code=$code reason=selfJoin');
      return const ArenaJoinResult.failure(ArenaJoinError.selfJoin);
    }
    final status = (raw['status'] ?? 'waiting').toString();
    if (status != 'waiting') {
      if (kDebugMode) debugPrint('[ARENA] join failed code=$code reason=notWaiting status=$status');
      return const ArenaJoinResult.failure(ArenaJoinError.notWaiting);
    }
    final existingGuest = raw['guestUid'] as String?;
    if (existingGuest != null && existingGuest.isNotEmpty) {
      if (kDebugMode) debugPrint('[ARENA] join failed code=$code reason=full guest=$existingGuest');
      return const ArenaJoinResult.failure(ArenaJoinError.full);
    }
    // Wallet check for betting rooms.
    final betEnabled = raw['betEnabled'] == true;
    final betAmount = (raw['betAmount'] as num?)?.toInt() ?? 0;
    if (betEnabled && betAmount > 0 && joinerCoins != null) {
      if (joinerCoins < betAmount) {
        if (kDebugMode) debugPrint('[ARENA] join failed code=$code reason=notEnoughCoins balance=$joinerCoins bet=$betAmount');
        return const ArenaJoinResult.failure(ArenaJoinError.notEnoughCoins);
      }
    }

    final guestPlayerEntry = <String, dynamic>{
      'uid': uid,
      'name': guestName,
      if (guestPhoto != null && guestPhoto.isNotEmpty) 'photoURL': guestPhoto,
      if (guestProfile != null) ...guestProfile,
    };

    // RTDB transactions can fire first with `current == null` from a stale
    // local cache. We must not abort in that case — if we do, the SDK will
    // report `!committed` and we'd surface a false "Room full" error.
    // Strategy: re-enter the room with our own uid if guestUid already == uid,
    // otherwise occupy if empty. Any other concrete conflict aborts.
    if (kDebugMode) debugPrint('[ARENA] join transaction starting code=$code');
    final txn = await _withTimeoutOrNull(
      ref.runTransaction((current) {
      if (current == null) {
        // No cached snapshot yet; let Firebase retry with server data. We
        // return success(current) so the transaction stays pending until the
        // server value arrives, instead of aborting outright.
        return Transaction.success(current);
      }
      if (current is! Map) {
        // Corrupt node (e.g. a leftover string at /rooms/{code}). Abort so
        // the outer recheck path surfaces a clean notFound instead of
        // throwing a TypeError that the caller would see as a timeout.
        return Transaction.abort();
      }
      final map = Map<dynamic, dynamic>.from(current);
      final g = (map['guestUid'] ?? '').toString();
      final h = (map['hostUid'] ?? '').toString();
      // Re-entry by the same user (host or guest) is a no-op success.
      if (g == uid || h == uid) {
        return Transaction.success(map);
      }
      if (g.isNotEmpty) return Transaction.abort();
      map['guestUid'] = uid;
      map['guestName'] = guestName;
      map['guestPhoto'] = guestPhoto;
      map['guestReady'] = false;
      map['status'] = 'waiting';
      map['updatedAt'] = ServerValue.timestamp;
      // Bind whichever X/O slot was reserved for the guest.
      if (map['xUid'] == '__pending__') map['xUid'] = uid;
      if (map['oUid'] == '__pending__') map['oUid'] = uid;
      // Add guest profile entry under players.
      final players = Map<dynamic, dynamic>.from(
          (map['players'] as Map?) ?? const <dynamic, dynamic>{});
      players[uid] = guestPlayerEntry;
      map['players'] = players;
      return Transaction.success(map);
    }),
      timeout: const Duration(seconds: 8),
      label: 'joinRoom.tx1',
    );

    if (txn == null) {
      if (kDebugMode) debugPrint('[ARENA] join transaction timeout code=$code');
      return const ArenaJoinResult.failure(ArenaJoinError.networkTimeout);
    }
    if (kDebugMode) {
      debugPrint('[ARENA] join transaction committed=${txn.committed} code=$code');
    }

    if (!txn.committed) {
      // Distinguish "genuine full" from "transient transaction abort" by
      // re-reading server state. Only surface `full` when the room truly has
      // a different guest. This eliminates the false first-tap "Room is full".
      if (kDebugMode) debugPrint('[ARENA] join txn not committed, re-checking server state code=$code');
      final recheck = await _withTimeoutOrNull(
        ref.get(),
        timeout: const Duration(seconds: 6),
        label: 'joinRoom.recheck',
      );
      if (recheck == null) {
        if (kDebugMode) debugPrint('[ARENA] join recheck timeout code=$code');
        return const ArenaJoinResult.failure(ArenaJoinError.networkTimeout);
      }
      if (!recheck.exists) {
        return const ArenaJoinResult.failure(ArenaJoinError.notFound);
      }
      final rmap = _asRoomMap(recheck.value);
      if (rmap == null) {
        if (kDebugMode) debugPrint('[ARENA] join failed code=$code reason=corruptOrMissing (recheck)');
        return const ArenaJoinResult.failure(ArenaJoinError.notFound);
      }
      final g2 = (rmap['guestUid'] ?? '').toString();
      final h2 = (rmap['hostUid'] ?? '').toString();
      if (g2 == uid || h2 == uid) {
        await _setActiveRoomMirror(uid, code);
        if (kDebugMode) debugPrint('[ARENA] joined room via recheck code=$code');
        return ArenaJoinResult.success(ArenaRoom.fromMap(rmap));
      }
      if (g2.isEmpty) {
        // Transient abort (local cache miss). Retry once.
        if (kDebugMode) debugPrint('[ARENA] retrying join after transient abort code=$code');
        final retry = await _withTimeoutOrNull(
          ref.runTransaction((current) {
            if (current == null) return Transaction.success(current);
            if (current is! Map) return Transaction.abort();
            final map = Map<dynamic, dynamic>.from(current);
            final g = (map['guestUid'] ?? '').toString();
            final h = (map['hostUid'] ?? '').toString();
            if (g == uid || h == uid) return Transaction.success(map);
            if (g.isNotEmpty) return Transaction.abort();
            map['guestUid'] = uid;
            map['guestName'] = guestName;
            map['guestPhoto'] = guestPhoto;
            map['guestReady'] = false;
            map['status'] = 'waiting';
            map['updatedAt'] = ServerValue.timestamp;
            if (map['xUid'] == '__pending__') map['xUid'] = uid;
            if (map['oUid'] == '__pending__') map['oUid'] = uid;
            final players = Map<dynamic, dynamic>.from(
                (map['players'] as Map?) ?? const <dynamic, dynamic>{});
            players[uid] = guestPlayerEntry;
            map['players'] = players;
            return Transaction.success(map);
          }),
          timeout: const Duration(seconds: 8),
          label: 'joinRoom.tx2',
        );
        if (retry != null && retry.committed) {
          final ns = await _withTimeoutOrNull(
            ref.get(),
            timeout: const Duration(seconds: 6),
            label: 'joinRoom.retryPostSnap',
          );
          if (ns != null && ns.exists) {
            final nsMap = _asRoomMap(ns.value);
            if (nsMap != null) {
              await _setActiveRoomMirror(uid, code);
              return ArenaJoinResult.success(ArenaRoom.fromMap(nsMap));
            }
          }
        }
      }
      return const ArenaJoinResult.failure(ArenaJoinError.full);
    }
    final newSnap = await _withTimeoutOrNull(
      ref.get(),
      timeout: const Duration(seconds: 6),
      label: 'joinRoom.postSnap',
    );
    if (newSnap == null) {
      return const ArenaJoinResult.failure(ArenaJoinError.networkTimeout);
    }
    if (!newSnap.exists) {
      return const ArenaJoinResult.failure(ArenaJoinError.notFound);
    }
    final newMap = _asRoomMap(newSnap.value);
    if (newMap == null) {
      if (kDebugMode) debugPrint('[ARENA] join failed code=$code reason=corruptOrMissing (postSnap)');
      return const ArenaJoinResult.failure(ArenaJoinError.notFound);
    }
    await _setActiveRoomMirror(uid, code);
    if (kDebugMode) debugPrint('[ARENA] joined room code=$code');
    return ArenaJoinResult.success(ArenaRoom.fromMap(newMap));
  }

  // ── Lobby / readiness ────────────────────────────────────────────────────

  Future<void> setReady({
    required String code,
    required bool isHost,
    required bool ready,
  }) async {
    final field = isHost ? 'hostReady' : 'guestReady';
    await _roomsRef.child(code).update(<String, Object?>{
      field: ready,
      'updatedAt': ServerValue.timestamp,
    });
    if (kDebugMode) {
      debugPrint('[ARENA] ${isHost ? "host" : "guest"} ready=$ready code=$code');
    }
  }

  /// Move from waiting → countdown. Picks the starting turn (X always starts).
  Future<void> startCountdown({required ArenaRoom room}) async {
    final firstTurn = room.xUid;
    await _roomsRef.child(room.roomCode).update(<String, Object?>{
      'status': 'countdown',
      'turnUid': firstTurn,
      'startedAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
    });
    if (kDebugMode) {
      debugPrint('[ARENA] countdown started room=${room.roomCode}');
    }
  }

  /// Countdown finished → gameplay.
  Future<void> startPlaying({required String code}) async {
    await _roomsRef.child(code).update(<String, Object?>{
      'status': 'playing',
      'updatedAt': ServerValue.timestamp,
    });
    if (kDebugMode) debugPrint('[ARENA] game started room=$code');
  }

  /// Submit a move. Returns true if accepted, false if rejected (turn,
  /// occupied cell, wrong status, etc.). Uses a transaction for safety.
  Future<bool> submitMove({
    required String code,
    required String uid,
    required int cellIndex,
  }) async {
    final ref = _roomsRef.child(code);
    final result = await ref.runTransaction((current) {
      if (current == null) return Transaction.abort();
      if (current is! Map) return Transaction.abort();
      final map = Map<dynamic, dynamic>.from(current);
      if (map['status'] != 'playing') return Transaction.abort();
      if (map['turnUid'] != uid) return Transaction.abort();
      final boardSize = (map['boardSize'] as num?)?.toInt() ?? 3;
      final cellCount = boardSize * boardSize;
      if (cellIndex < 0 || cellIndex >= cellCount) return Transaction.abort();

      List<String> board;
      final rawBoard = map['board'];
      if (rawBoard is List) {
        board = rawBoard.map((e) => (e ?? '').toString()).toList();
        if (board.length < cellCount) {
          board = List<String>.from(board)
            ..addAll(List<String>.filled(cellCount - board.length, ''));
        }
      } else if (rawBoard is Map) {
        board = List<String>.filled(cellCount, '');
        rawBoard.forEach((k, v) {
          final i = int.tryParse(k.toString());
          if (i != null && i >= 0 && i < cellCount) {
            board[i] = (v ?? '').toString();
          }
        });
      } else {
        board = List<String>.filled(cellCount, '');
      }
      if (board[cellIndex].isNotEmpty) return Transaction.abort();

      final xUid = (map['xUid'] ?? '').toString();
      final oUid = (map['oUid'] ?? '').toString();
      final symbol = uid == xUid ? 'X' : (uid == oUid ? 'O' : '');
      if (symbol.isEmpty) return Transaction.abort();
      board[cellIndex] = symbol;

      final opponent = uid == xUid ? oUid : xUid;
      map['board'] = board;
      map['turnUid'] = opponent;
      map['updatedAt'] = ServerValue.timestamp;
      return Transaction.success(map);
    });
    if (kDebugMode) {
      debugPrint(
          '[ARENA] move uid=$uid cell=$cellIndex committed=${result.committed}');
    }
    return result.committed;
  }

  /// Host writes the resolution of a round (winner advances, draw replays).
  ///
  /// Also rotates [boardSize] to match the *new* round's map when advancing.
  Future<void> applyRoundResult({
    required String code,
    required int currentRound,
    required int currentRoundIndex,
    required int roundsCount,
    required List<String> roundMaps,
    required int scoreHost,
    required int scoreGuest,
    required String? roundWinnerUid,
  }) async {
    final isDraw = roundWinnerUid == null;
    final nextRound = isDraw ? currentRound : currentRound + 1;
    final nextIndex = isDraw ? currentRoundIndex : currentRoundIndex + 1;
    final safeIndex = nextIndex.clamp(0, roundMaps.length - 1).toInt();
    final nextMap = roundMaps.isEmpty ? '3x3' : roundMaps[safeIndex];
    final nextBoardSize = int.tryParse(nextMap.split('x').first) ?? 3;
    final cellCount = nextBoardSize * nextBoardSize;
    final emptyBoard = List<String>.filled(cellCount, '');
    await _roomsRef.child(code).update(<String, Object?>{
      'board': emptyBoard,
      'boardSize': nextBoardSize,
      'score': <String, Object?>{
        'host': scoreHost,
        'guest': scoreGuest,
      },
      'currentRound': nextRound,
      'currentRoundIndex': safeIndex,
      'roundWinnerUid': roundWinnerUid,
      'updatedAt': ServerValue.timestamp,
    });
    if (kDebugMode) {
      if (isDraw) {
        debugPrint('[ARENA] draw replaying round=$currentRound');
      } else {
        debugPrint(
            '[ARENA] round ended winner=$roundWinnerUid round=$currentRound');
      }
    }
  }

  /// Host writes the final room result. Does NOT delete the room — the host
  /// schedules the actual RTDB removal via [scheduleCleanup] after summary
  /// + payout writes complete, with a grace window so the guest receives
  /// the final state before the node disappears.
  Future<void> finishRoom({
    required String code,
    required String? roomWinnerUid,
    required String result,
    String? finalResult,
  }) async {
    await _roomsRef.child(code).update(<String, Object?>{
      'status': 'finished',
      'roomWinnerUid': roomWinnerUid,
      'result': result,
      if (finalResult != null) 'finalResult': finalResult,
      'finishedAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
    });
    if (kDebugMode) {
      debugPrint('[ARENA] room finished winner=$roomWinnerUid');
    }
  }

  /// Host writes the final round result AND the match finish in ONE atomic
  /// RTDB update. Crucially does NOT reset the board or boardSize, so the
  /// winning line stays visible to both clients while the end-of-match
  /// overlay renders. Use this in the host's last-round / decided-winner
  /// branch instead of calling [applyRoundResult] + [finishRoom] sequentially
  /// (those two writes leave a window where the guest can see an empty board
  /// with status='playing', which previously caused the "stuck after a win"
  /// bug).
  Future<void> finishMatchAtomic({
    required String code,
    required int currentRound,
    required int currentRoundIndex,
    required int scoreHost,
    required int scoreGuest,
    required String? roundWinnerUid,
    required String? roomWinnerUid,
    required String result,
    String? finalResult,
  }) async {
    await _roomsRef.child(code).update(<String, Object?>{
      'score': <String, Object?>{
        'host': scoreHost,
        'guest': scoreGuest,
      },
      'currentRound': currentRound,
      'currentRoundIndex': currentRoundIndex,
      'roundWinnerUid': roundWinnerUid,
      'status': 'finished',
      'roomWinnerUid': roomWinnerUid,
      'result': result,
      if (finalResult != null) 'finalResult': finalResult,
      'finishedAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
    });
    if (kDebugMode) {
      debugPrint(
          '[ARENA] match finished atomically winner=$roomWinnerUid round=$currentRound');
    }
  }

  /// Host-only: mark the room with a `cleanupAfter` timestamp so any
  /// observer (the host's own Timer, a Cloud Function janitor, or a future
  /// reconnecting client) knows when the RTDB node is safe to remove.
  /// Default grace period is 25 seconds.
  Future<void> setCleanupAfter(String code,
      {Duration grace = const Duration(seconds: 25)}) async {
    final cleanupAt = DateTime.now().millisecondsSinceEpoch + grace.inMilliseconds;
    try {
      await _roomsRef.child(code).update(<String, Object?>{
        'cleanupAfter': cleanupAt,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (_) {}
  }

  /// Leave / cancel. If the host leaves before the game starts, the room is
  /// removed; otherwise the leaver becomes the loser and the opponent wins.
  ///
  /// All RTDB writes are wrapped in try/catch so a Permission denied (e.g.
  /// from rules validation) cannot bubble up as an unhandled zone error.
  /// Callers should still surface a toast if needed, but the app will never
  /// crash on leave.
  Future<void> leaveRoom({
    required ArenaRoom room,
    required String leaverUid,
  }) async {
    final beforePlay = room.isWaiting || room.isReady;
    if (beforePlay) {
      if (leaverUid == room.hostUid) {
        try {
          await _roomsRef.child(room.roomCode).remove();
          if (kDebugMode) {
            debugPrint('[ARENA] room deleted code=${room.roomCode}');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[ARENA] host leave remove failed: $e');
        }
      } else {
        // Guest leaves before play — clear guest seat.
        //
        // We use individual .set() per field instead of a multi-field
        // update() because update() is reported by RTDB as a write at the
        // parent path (/rooms) for permission evaluation in some SDK
        // versions, which then trips ".write: false" on the /rooms parent
        // even when /rooms/{code} is writable. Individual sets are
        // unambiguously at /rooms/{code}/{field} and use the $roomCode
        // .write rule cleanly.
        final ref = _roomsRef.child(room.roomCode);
        try {
          await ref.child('guestUid').set(null);
          await ref.child('guestName').set(null);
          await ref.child('guestPhoto').set(null);
          await ref.child('guestReady').set(false);
          await ref.child('updatedAt').set(ServerValue.timestamp);
        } catch (e) {
          if (kDebugMode) debugPrint('[ARENA] guest leave clear failed: $e');
        }
      }
      return;
    }
    // Mid-game: leaver loses.
    final winnerUid = room.opponentOf(leaverUid);
    try {
      await finishRoom(
        code: room.roomCode,
        roomWinnerUid: winnerUid.isEmpty ? null : winnerUid,
        result: 'forfeit',
        finalResult: 'opponent_left',
      );
      if (kDebugMode) {
        debugPrint('[ARENA] forfeit loser=$leaverUid winner=$winnerUid');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ARENA] forfeit finish failed: $e');
    }
  }

  /// Host-driven cancel.
  ///
  /// 1. Try to remove `/rooms/{code}` (when no guest joined).
  /// 2. If remove fails, or a guest already joined, fall back to writing
  ///    `status: 'cancelled'` plus audit fields so the guest's listener sees
  ///    the cancellation and exits.
  /// 3. Always clears the active-room mirror so the host is not "stuck" in
  ///    the room from Firestore's point of view.
  ///
  /// Every step has a 5s timeout — the UI must never block forever on this.
  Future<void> cancelRoomAsHost(String code) async {
    final uid = _uid;
    if (uid == null) return;
    if (kDebugMode) debugPrint('[ARENA] cancel requested room=$code uid=$uid');
    final ref = _roomsRef.child(code);
    bool guestPresent = false;
    try {
      final snap = await ref.get().timeout(const Duration(seconds: 5));
      if (snap.exists) {
        final raw = _asRoomMap(snap.value) ?? const <dynamic, dynamic>{};
        final hostUid = (raw['hostUid'] ?? '').toString();
        if (hostUid.isNotEmpty && hostUid != uid) {
          if (kDebugMode) {
            debugPrint('[ARENA] cancel skipped — caller is not host room=$code');
          }
          await clearActiveRoomMirror(uid);
          return;
        }
        final g = (raw['guestUid'] ?? '').toString();
        guestPresent = g.isNotEmpty;
      } else {
        // Already gone — just clear mirror and return.
        await clearActiveRoomMirror(uid);
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ARENA] cancel pre-read failed: $e');
    }

    if (!guestPresent) {
      try {
        await ref.remove().timeout(const Duration(seconds: 5));
        if (kDebugMode) debugPrint('[ARENA] cancel success room=$code');
        await clearActiveRoomMirror(uid);
        return;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ARENA] cancel remove failed, falling back to status=cancelled: $e');
        }
      }
    }

    try {
      await ref.update(<String, Object?>{
        'status': 'cancelled',
        'cancelledByUid': uid,
        'cancelledAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
        'result': 'cancelled',
      }).timeout(const Duration(seconds: 5));
      if (kDebugMode) {
        debugPrint('[ARENA] cancel fallback status=cancelled room=$code');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ARENA] cancel fallback update failed: $e');
    }
    await clearActiveRoomMirror(uid);
  }

  /// Guest-driven leave (used by the lobby and by the back-button path).
  ///
  /// Before play begins: clears the guest seat so the host can keep waiting.
  /// During / after play: writes a forfeit via the existing [finishRoom]
  /// pipeline so prizes / summaries fire correctly.
  ///
  /// Both branches always clear the guest's active-room mirror and never
  /// throw — so the UI can always navigate out.
  Future<void> leaveRoomAsGuest(String code) async {
    final uid = _uid;
    if (uid == null) return;
    if (kDebugMode) debugPrint('[ARENA] guest leave requested room=$code uid=$uid');
    final ref = _roomsRef.child(code);
    try {
      final snap = await ref.get().timeout(const Duration(seconds: 5));
      if (!snap.exists) {
        await clearActiveRoomMirror(uid);
        return;
      }
      final raw = _asRoomMap(snap.value) ?? const <dynamic, dynamic>{};
      final status = (raw['status'] ?? 'waiting').toString();
      final beforePlay =
          status == 'waiting' || status == 'ready';
      if (beforePlay) {
        try {
          await ref.child('guestUid').set(null).timeout(const Duration(seconds: 5));
          await ref.child('guestName').set(null);
          await ref.child('guestPhoto').set(null);
          await ref.child('guestReady').set(false);
          await ref.child('leftByUid').set(uid);
          await ref.child('leftAt').set(ServerValue.timestamp);
          await ref.child('updatedAt').set(ServerValue.timestamp);
          if (kDebugMode) debugPrint('[ARENA] guest seat cleared room=$code');
        } catch (e) {
          if (kDebugMode) debugPrint('[ARENA] guest leave clear failed: $e');
        }
      } else {
        // Mid-game: forfeit via the existing finishRoom helper.
        final hostUid = (raw['hostUid'] ?? '').toString();
        try {
          await ref.update(<String, Object?>{
            'status': 'finished',
            'roomWinnerUid': hostUid.isEmpty ? null : hostUid,
            'result': 'forfeit',
            'finalResult': 'opponent_left',
            'leftByUid': uid,
            'leftAt': ServerValue.timestamp,
            'finishedAt': ServerValue.timestamp,
            'updatedAt': ServerValue.timestamp,
          }).timeout(const Duration(seconds: 5));
        } catch (e) {
          if (kDebugMode) debugPrint('[ARENA] guest forfeit failed: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ARENA] guest leave outer failed: $e');
    }
    await clearActiveRoomMirror(uid);
  }

  /// Mark a room as expired and remove it.
  Future<void> expireRoom(String code) async {
    try {
      await _roomsRef.child(code).update(<String, Object?>{
        'status': 'expired',
        'result': 'expired',
        'finalResult': 'expired',
        'updatedAt': ServerValue.timestamp,
      });
      await _roomsRef.child(code).remove();
      if (kDebugMode) debugPrint('[ARENA] room expired code=$code');
    } catch (_) {}
  }

  /// Remove the live RTDB node entirely. Called by the host after the match
  /// summary has been written to Firestore.
  Future<void> deleteRoom(String code) async {
    try {
      await _roomsRef.child(code).remove();
      if (kDebugMode) debugPrint('[ARENA] room deleted code=$code');
    } catch (_) {}
  }

  /// Listen to a room. Emits `null` if the room is removed (or if the node
  /// somehow contains a non-map value, which we treat as gone).
  Stream<ArenaRoom?> watchRoom(String code) {
    return _roomsRef.child(code).onValue.map((event) {
      final map = _asRoomMap(event.snapshot.value);
      if (map == null) return null;
      return ArenaRoom.fromMap(map);
    });
  }

  Future<ArenaRoom?> readRoom(String code) async {
    final snap = await _roomsRef.child(code).get();
    if (!snap.exists) return null;
    final map = _asRoomMap(snap.value);
    if (map == null) return null;
    return ArenaRoom.fromMap(map);
  }
}
