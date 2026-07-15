import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../models/arena/arena_room.dart';
import '../app_mode_service.dart';
import '../connectivity_service.dart';
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
  kickedCooldown,
  networkTimeout,
  unknown,
}

class ArenaOfflineException implements Exception {
  const ArenaOfflineException();
}

class ArenaJoinResult {
  final ArenaRoom? room;
  final ArenaJoinError? error;

  /// For [ArenaJoinError.kickedCooldown], the absolute epoch (ms) at which
  /// the cooldown lifts. Null for all other errors.
  final int? kickCooldownUntilMs;

  const ArenaJoinResult.success(this.room)
      : error = null,
        kickCooldownUntilMs = null;
  const ArenaJoinResult.failure(this.error, {this.kickCooldownUntilMs})
      : room = null;
  bool get isSuccess => room != null;
}

/// Why a host-kick attempt failed. `null` failure means the kick succeeded.
enum ArenaKickFailure {
  notHost,
  noGuest,
  badStatus,
  permissionDenied,
  network,
  unknown,
}

/// Structured result for [ArenaRepo.kickGuest] so the UI can surface a
/// specific message rather than the generic "Could not kick player" toast.
class ArenaKickResult {
  final bool success;
  final ArenaKickFailure? failure;
  const ArenaKickResult._(this.success, this.failure);
  const ArenaKickResult.ok() : this._(true, null);
  const ArenaKickResult.fail(ArenaKickFailure reason) : this._(false, reason);
}

/// Outcome of validating a user's saved active-room pointer.
enum ActiveRoomValidity {
  /// No saved active-room pointer at all.
  none,

  /// Pointer is valid: room exists, user is still a member, not kicked, and
  /// the room is in a resumable (non-terminal) state.
  valid,

  /// Pointer references a room that no longer exists in RTDB.
  missing,
  finished,
  cancelled,
  expired,
  abandoned,

  /// Room exists but the user is neither host nor guest anymore.
  notMember,

  /// Room exists, the user is not a member, and a kick entry is recorded for
  /// them — i.e. the host removed them.
  kicked,
}

/// Result of [ArenaRepo.validateActiveRoom]. When [validity] is anything other
/// than [ActiveRoomValidity.valid]/[ActiveRoomValidity.none], the underlying
/// mirror has already been cleared as a side effect.
class ActiveRoomCheck {
  final ActiveRoomValidity validity;
  final ArenaRoom? room;
  final String? code;
  const ActiveRoomCheck(this.validity, {this.room, this.code});

  bool get isValid => validity == ActiveRoomValidity.valid && room != null;

  /// Where a valid room should resume to: `'game'` for live play states,
  /// `'lobby'` for pre-play states.
  String get target {
    final s = room?.status ?? '';
    if (s == 'playing' || s == 'round_end' || s == 'countdown') return 'game';
    return 'lobby';
  }
}

/// 60-second rejoin cooldown applied when a host kicks a guest.
const int kArenaKickCooldownMs = 60 * 1000;

/// Maximum room lifetime from creation (10 minutes). Applies ONLY to empty
/// "waiting" rooms where no guest has joined yet.
const int kArenaRoomTtlMs = 10 * 60 * 1000;

/// Inactivity timeout for *occupied* rooms (a guest has joined or the match has
/// started). If the room has had no activity (no `updatedAt` write and no
/// presence heartbeat from either player) for this long it is considered stale
/// and is expired. Mirrored on the Cloud Function janitor.
const int kArenaInactivityTtlMs = 20 * 60 * 1000;

/// How a player's intentional leave was resolved by [ArenaRepo.resolvePlayerLeaveRoom].
enum RoomLeaveMode {
  /// Room was already gone / terminal — nothing to settle.
  alreadyResolved,

  /// Caller is not a member of the room (kicked / never joined).
  notMember,

  /// Pre-play room with no committed bet — room cancelled / seat cleared,
  /// no coin movement.
  cancel,

  /// Coins were locked or the match had started — the leaver forfeits and the
  /// opponent is recorded as the winner. The opponent's client (or its
  /// startup settlement) performs the idempotent payout.
  forfeit,
}

/// Structured outcome of a [ArenaRepo.resolvePlayerLeaveRoom] call so callers
/// can log / surface the right message.
class RoomLeaveResolution {
  final RoomLeaveMode mode;
  final String? winnerUid;
  final String? loserUid;
  final bool betEnabled;
  final int betAmount;
  final int prizePool;
  const RoomLeaveResolution(
    this.mode, {
    this.winnerUid,
    this.loserUid,
    this.betEnabled = false,
    this.betAmount = 0,
    this.prizePool = 0,
  });
}

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

  /// Room codes for which the user back-dismissed the "Active Room Found"
  /// resume prompt during this app session. In-memory only — a full app
  /// restart re-arms the prompt if the room is still valid.
  final Set<String> resumeDismissedThisSession = <String>{};

  /// True while a resume/settlement flow is presenting a dialog. Shared between
  /// the Home startup check and the Arena-tab check so the two can never stack
  /// two dialogs on top of each other in the narrow race where the user opens
  /// the Online tab at the same moment the startup check fires.
  bool resumeFlowBusy = false;

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

  /// Epoch-ms of the most recent activity on a room: the later of its
  /// `updatedAt` and either player's presence `lastSeenMs` heartbeat.
  int _lastActivityMs(ArenaRoom room) {
    int last = room.updatedAt;
    for (final entry in room.playersPresence.values) {
      final ls = entry['lastSeenMs'];
      final v =
          ls is num ? ls.toInt() : int.tryParse(ls?.toString() ?? '') ?? 0;
      if (v > last) last = v;
    }
    return last;
  }

  /// True when an *occupied* room (guest joined, or past the waiting phase) has
  /// had no activity for [kArenaInactivityTtlMs]. Empty "waiting" rooms are
  /// governed by the 10-minute creation TTL ([kArenaRoomTtlMs]) instead and
  /// always return false here. Terminal rooms are never "stale" (already done).
  bool isRoomStaleByInactivity(ArenaRoom room) {
    final occupied = (room.guestUid != null && room.guestUid!.isNotEmpty) ||
        room.status != 'waiting';
    if (!occupied) return false;
    const terminal = <String>{
      'finished',
      'expired',
      'cancelled',
      'abandoned',
    };
    if (terminal.contains(room.status)) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - _lastActivityMs(room) > kArenaInactivityTtlMs;
  }

  /// Authoritative check of whether the user has a *resumable* active room.
  ///
  /// A saved pointer is valid only when the room exists, is not in a terminal
  /// state / expired, the user is still host or guest, and the user has not
  /// been kicked. Any non-valid outcome clears the stale mirror as a side
  /// effect so callers can safely treat a kicked/finished/stale pointer as
  /// "no active room" (this is the fix for the kicked-guest-returns-to-old-room
  /// bug: the host cannot clear the guest's Firestore mirror under the rules,
  /// so the guest's own client must reconcile it here).
  Future<ActiveRoomCheck> validateActiveRoom(String uid) async {
    final code = await getActiveRoomCode(uid);
    if (kDebugMode) {
      debugPrint('[ARENA_ACTIVE_ROOM] check uid=$uid savedRoom=$code');
    }
    if (code == null) {
      return const ActiveRoomCheck(ActiveRoomValidity.none);
    }

    Future<ActiveRoomCheck> clearAnd(
        ActiveRoomValidity v, String reason) async {
      await clearActiveRoomMirror(uid);
      if (kDebugMode) {
        debugPrint('[ARENA_ACTIVE_ROOM] cleared reason=$reason uid=$uid '
            'room=$code');
        debugPrint('[ARENA_ACTIVE_ROOM] check uid=$uid savedRoom=$code '
            'result=$reason');
      }
      return ActiveRoomCheck(v, code: code);
    }

    final room = await readRoom(code);
    if (room == null) {
      return clearAnd(ActiveRoomValidity.missing, 'missing');
    }

    final status = room.status;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (status == 'finished') {
      return clearAnd(ActiveRoomValidity.finished, 'finished');
    }
    if (status == 'cancelled') {
      return clearAnd(ActiveRoomValidity.cancelled, 'cancelled');
    }
    if (status == 'abandoned') {
      return clearAnd(ActiveRoomValidity.abandoned, 'abandoned');
    }
    if (status == 'expired') {
      return clearAnd(ActiveRoomValidity.expired, 'expired');
    }
    final occupied = (room.guestUid != null && room.guestUid!.isNotEmpty) ||
        room.status != 'waiting';
    // Empty waiting room: 10-minute creation TTL. Occupied room: 20-minute
    // inactivity TTL (a long match must not be killed by the creation TTL).
    if (!occupied && room.expiresAt > 0 && now > room.expiresAt) {
      return clearAnd(ActiveRoomValidity.expired, 'expired_waiting_ttl');
    }
    if (occupied && isRoomStaleByInactivity(room)) {
      return clearAnd(ActiveRoomValidity.expired, 'stale_inactive');
    }

    final isMember = uid == room.hostUid || uid == room.guestUid;
    if (!isMember) {
      if (room.kickedUsers[uid] != null) {
        if (kDebugMode) {
          debugPrint('[ARENA_KICK] guest_detected_kicked uid=$uid room=$code');
        }
        return clearAnd(ActiveRoomValidity.kicked, 'kicked');
      }
      return clearAnd(ActiveRoomValidity.notMember, 'not_member');
    }

    if (kDebugMode) {
      debugPrint('[ARENA_ACTIVE_ROOM] check uid=$uid savedRoom=$code '
          'result=valid status=$status');
    }
    return ActiveRoomCheck(ActiveRoomValidity.valid, room: room, code: code);
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
    if (!AppModeService.canUseOnlineServices ||
        !ConnectivityService().isOnline.value) {
      throw const ArenaOfflineException();
    }
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
    if (!AppModeService.canUseOnlineServices ||
        !ConnectivityService().isOnline.value) {
      return const ArenaJoinResult.failure(ArenaJoinError.networkTimeout);
    }
    final uid = _uid;
    if (uid == null) {
      return const ArenaJoinResult.failure(ArenaJoinError.unknown);
    }
    if (kDebugMode) debugPrint('[ARENA] join attempt code=$code');

    // Validate any saved active-room pointer BEFORE the guard. A kicked /
    // stale / finished pointer (which could otherwise surface as a misleading
    // "Already in a room" error on the user's first tap on a fresh code) is
    // cleared as a side effect by validateActiveRoom, so only a *valid* pointer
    // to a different live room blocks the join.
    final active = await validateActiveRoom(uid);
    if (kDebugMode) {
      debugPrint('[ARENA] activeRoom=${active.code} valid=${active.isValid} '
          'requested=$code');
    }
    if (active.isValid && active.code != code) {
      if (kDebugMode) {
        debugPrint('[ARENA] join failed code=$code reason=alreadyInActiveRoom '
            'active=${active.code}');
      }
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
    if (kDebugMode) {
      debugPrint('[ARENA] join room exists=${preSnap.exists} code=$code');
    }
    if (!preSnap.exists) {
      if (kDebugMode) {
        debugPrint('[ARENA] join failed code=$code reason=notFound');
      }
      return const ArenaJoinResult.failure(ArenaJoinError.notFound);
    }
    final raw = _asRoomMap(preSnap.value);
    if (raw == null) {
      if (kDebugMode) {
        debugPrint('[ARENA] join failed code=$code reason=corruptOrMissing');
      }
      return const ArenaJoinResult.failure(ArenaJoinError.notFound);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = (raw['expiresAt'] as num?)?.toInt() ?? 0;
    if (expiresAt > 0 && now > expiresAt) {
      if (kDebugMode) {
        debugPrint(
            '[ARENA] join failed code=$code reason=expired expiresAt=$expiresAt now=$now');
      }
      return const ArenaJoinResult.failure(ArenaJoinError.expired);
    }
    final hostUid = (raw['hostUid'] ?? '').toString();
    if (hostUid == uid) {
      if (kDebugMode) {
        debugPrint('[ARENA] join failed code=$code reason=selfJoin');
      }
      return const ArenaJoinResult.failure(ArenaJoinError.selfJoin);
    }
    // Kick-cooldown guard. The host only writes `kickedUsers/<uid>` entries
    // when removing this specific guest, so the check is per-room.
    final kickedEntry =
        (raw['kickedUsers'] is Map) ? ((raw['kickedUsers'] as Map)[uid]) : null;
    if (kickedEntry is Map) {
      final untilMs = (kickedEntry['untilMs'] as num?)?.toInt() ?? 0;
      if (untilMs > now) {
        if (kDebugMode) {
          final remaining = ((untilMs - now) / 1000).ceil();
          debugPrint('[ARENA_JOIN_BLOCKED] code=$code uid=$uid '
              'reason=kick_cooldown remaining=${remaining}s');
        }
        return ArenaJoinResult.failure(
          ArenaJoinError.kickedCooldown,
          kickCooldownUntilMs: untilMs,
        );
      }
    }
    final status = (raw['status'] ?? 'waiting').toString();
    if (status != 'waiting') {
      if (kDebugMode) {
        debugPrint(
            '[ARENA] join failed code=$code reason=notWaiting status=$status');
      }
      return const ArenaJoinResult.failure(ArenaJoinError.notWaiting);
    }
    final existingGuest = raw['guestUid'] as String?;
    if (existingGuest != null && existingGuest.isNotEmpty) {
      if (kDebugMode) {
        debugPrint(
            '[ARENA] join failed code=$code reason=full guest=$existingGuest');
      }
      return const ArenaJoinResult.failure(ArenaJoinError.full);
    }
    // Wallet check for betting rooms.
    final betEnabled = raw['betEnabled'] == true;
    final betAmount = (raw['betAmount'] as num?)?.toInt() ?? 0;
    if (betEnabled && betAmount > 0 && joinerCoins != null) {
      if (joinerCoins < betAmount) {
        if (kDebugMode) {
          debugPrint(
              '[ARENA] join failed code=$code reason=notEnoughCoins balance=$joinerCoins bet=$betAmount');
        }
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
      debugPrint(
          '[ARENA] join transaction committed=${txn.committed} code=$code');
    }

    if (!txn.committed) {
      // Distinguish "genuine full" from "transient transaction abort" by
      // re-reading server state. Only surface `full` when the room truly has
      // a different guest. This eliminates the false first-tap "Room is full".
      if (kDebugMode) {
        debugPrint(
            '[ARENA] join txn not committed, re-checking server state code=$code');
      }
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
        if (kDebugMode) {
          debugPrint(
              '[ARENA] join failed code=$code reason=corruptOrMissing (recheck)');
        }
        return const ArenaJoinResult.failure(ArenaJoinError.notFound);
      }
      final g2 = (rmap['guestUid'] ?? '').toString();
      final h2 = (rmap['hostUid'] ?? '').toString();
      if (g2 == uid || h2 == uid) {
        await _setActiveRoomMirror(uid, code);
        if (kDebugMode) {
          debugPrint('[ARENA] joined room via recheck code=$code');
        }
        return ArenaJoinResult.success(ArenaRoom.fromMap(rmap));
      }
      if (g2.isEmpty) {
        // Transient abort (local cache miss). Retry once.
        if (kDebugMode) {
          debugPrint('[ARENA] retrying join after transient abort code=$code');
        }
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
      if (kDebugMode) {
        debugPrint(
            '[ARENA] join failed code=$code reason=corruptOrMissing (postSnap)');
      }
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
    if (!AppModeService.canUseOnlineServices ||
        !ConnectivityService().isOnline.value) {
      throw const ArenaOfflineException();
    }
    final field = isHost ? 'hostReady' : 'guestReady';
    await _roomsRef.child(code).update(<String, Object?>{
      field: ready,
      'updatedAt': ServerValue.timestamp,
    });
    if (kDebugMode) {
      debugPrint(
          '[ARENA] ${isHost ? "host" : "guest"} ready=$ready code=$code');
    }
  }

  /// Move from waiting → countdown. Picks the starting turn (X always starts).
  Future<void> startCountdown({required ArenaRoom room}) async {
    if (!AppModeService.canUseOnlineServices ||
        !ConnectivityService().isOnline.value) {
      throw const ArenaOfflineException();
    }
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
    if (!AppModeService.canUseOnlineServices ||
        !ConnectivityService().isOnline.value) {
      throw const ArenaOfflineException();
    }
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

  /// Phase A: Host writes the terminal board state + `status=round_end`.
  /// The board is NOT cleared — both clients see the winning/full board.
  /// `roundVersion` is bumped so the UI can key on it.
  Future<void> applyRoundResult({
    required String code,
    required int currentRound,
    required int currentRoundIndex,
    required int roundsCount,
    required List<String> roundMaps,
    required int scoreHost,
    required int scoreGuest,
    required String? roundWinnerUid,
    required int roundVersion,
  }) async {
    final isDraw = roundWinnerUid == null;
    final nextVersion = roundVersion + 1;
    if (kDebugMode) {
      debugPrint('[ARENA_PHASE_A] code=$code winner=$roundWinnerUid '
          'draw=$isDraw version=$roundVersion->$nextVersion '
          'score=$scoreHost-$scoreGuest');
    }
    await _roomsRef.child(code).update(<String, Object?>{
      'status': 'round_end',
      'score': <String, Object?>{
        'host': scoreHost,
        'guest': scoreGuest,
      },
      'roundWinnerUid': roundWinnerUid,
      'lastRoundResult': isDraw ? 'draw' : 'win',
      'lastRoundEndAt': ServerValue.timestamp,
      'roundVersion': nextVersion,
      'updatedAt': ServerValue.timestamp,
    });
    if (kDebugMode) {
      if (isDraw) {
        debugPrint(
            '[ARENA_DRAW] room=$code round=$currentRound phase=round_end rv=$nextVersion');
        debugPrint(
            '[ARENA_ROUND] room=$code round=$currentRound result=draw phase=round_end');
      } else {
        debugPrint(
            '[ARENA_ROUND] room=$code round=$currentRound result=win winner=$roundWinnerUid '
            'phase=round_end scoreHost=$scoreHost scoreGuest=$scoreGuest rv=$nextVersion');
      }
    }
  }

  /// Phase B: Host advances to the next round. Uses an RTDB transaction
  /// for idempotency — only proceeds if `status` is still `round_end`
  /// and `roundVersion` matches `expectedRoundVersion`.
  Future<bool> advanceToNextRound({
    required String code,
    required int currentRound,
    required int currentRoundIndex,
    required int roundsCount,
    required List<String> roundMaps,
    required String? roundWinnerUid,
    required String xUid,
    required String oUid,
    required int expectedRoundVersion,
  }) async {
    final isDraw = roundWinnerUid == null;
    final nextRound = isDraw ? currentRound : currentRound + 1;
    final nextIndex = isDraw ? currentRoundIndex : currentRoundIndex + 1;
    final safeIndex = nextIndex.clamp(0, roundMaps.length - 1).toInt();
    final nextMap = roundMaps.isEmpty ? '3x3' : roundMaps[safeIndex];
    final nextBoardSize = int.tryParse(nextMap.split('x').first) ?? 3;
    final cellCount = nextBoardSize * nextBoardSize;
    final emptyBoard = List<String>.filled(cellCount, '');
    final firstTurn = xUid;
    final nextRoundVersion = expectedRoundVersion + 1;

    if (kDebugMode) {
      debugPrint('[ARENA_PHASE_B] transaction start room=$code '
          'expectedVersion=$expectedRoundVersion');
    }
    final ref = _roomsRef.child(code);
    final result = await ref.runTransaction((current) {
      if (current == null) {
        if (kDebugMode) {
          debugPrint('[ARENA_PHASE_B] transaction abort reason=no_room '
              'expectedVersion=$expectedRoundVersion');
        }
        return Transaction.abort();
      }
      if (current is! Map) {
        if (kDebugMode) {
          debugPrint('[ARENA_PHASE_B] transaction abort reason=not_a_map '
              'expectedVersion=$expectedRoundVersion');
        }
        return Transaction.abort();
      }
      final map = Map<dynamic, dynamic>.from(current);
      final actualStatus = map['status'];
      if (actualStatus != 'round_end') {
        if (kDebugMode) {
          debugPrint('[ARENA_PHASE_B] transaction abort reason=status_mismatch '
              'actual=$actualStatus expectedVersion=$expectedRoundVersion');
        }
        return Transaction.abort();
      }
      final currentVersion = (map['roundVersion'] as num?)?.toInt() ?? 0;
      if (currentVersion != expectedRoundVersion) {
        if (kDebugMode) {
          debugPrint(
              '[ARENA_PHASE_B] transaction abort reason=version_mismatch '
              'expected=$expectedRoundVersion actual=$currentVersion');
        }
        return Transaction.abort();
      }

      map['status'] = 'playing';
      map['board'] = emptyBoard;
      map['boardSize'] = nextBoardSize;
      map['currentRound'] = nextRound;
      map['currentRoundIndex'] = safeIndex;
      map['turnUid'] = firstTurn;
      map['roundWinnerUid'] = null;
      map['roundVersion'] = nextRoundVersion;
      map['updatedAt'] = ServerValue.timestamp;
      return Transaction.success(map);
    });

    if (kDebugMode) {
      if (result.committed) {
        debugPrint('[ARENA_PHASE_B] transaction committed room=$code '
            'newVersion=$nextRoundVersion nextRound=$nextRound '
            'boardSize=${nextBoardSize}x$nextBoardSize');
      } else {
        debugPrint('[ARENA_PHASE_B] transaction not_committed room=$code '
            'expectedVersion=$expectedRoundVersion');
      }
    }
    return result.committed;
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

  /// Creates one room-level reconnect grace window. The transaction prevents
  /// both clients from racing to replace an already-active window.
  Future<bool> startDisconnectGrace({
    required String code,
    required String disconnectedUid,
    Duration grace = const Duration(minutes: 2),
  }) async {
    final caller = _uid;
    if (caller == null || caller == disconnectedUid) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = await _roomsRef.child(code).runTransaction((current) {
      final raw = _asRoomMap(current);
      if (raw == null) return Transaction.abort();
      final host = (raw['hostUid'] ?? '').toString();
      final guest = (raw['guestUid'] ?? '').toString();
      if (caller != host && caller != guest) return Transaction.abort();
      if (disconnectedUid != host && disconnectedUid != guest) {
        return Transaction.abort();
      }
      final status = (raw['status'] ?? '').toString();
      if (!const <String>{
        'waiting',
        'ready',
        'countdown',
        'playing',
        'round_end'
      }.contains(status)) {
        return Transaction.abort();
      }
      final activeUid = (raw['disconnectUid'] ?? '').toString();
      final deadline = (raw['disconnectDeadlineAt'] as num?)?.toInt() ?? 0;
      if (activeUid.isNotEmpty && deadline > now) return Transaction.abort();
      raw['disconnectUid'] = disconnectedUid;
      raw['disconnectStartedAt'] = now;
      raw['disconnectDeadlineAt'] = now + grace.inMilliseconds;
      raw['disconnectResolved'] = false;
      raw['updatedAt'] = ServerValue.timestamp;
      return Transaction.success(raw);
    });
    return result.committed;
  }

  /// Clears the grace window only when it still belongs to [reconnectedUid].
  Future<bool> clearDisconnectGrace({
    required String code,
    required String reconnectedUid,
  }) async {
    final caller = _uid;
    if (caller == null) return false;
    final result = await _roomsRef.child(code).runTransaction((current) {
      final raw = _asRoomMap(current);
      if (raw == null) return Transaction.abort();
      final host = (raw['hostUid'] ?? '').toString();
      final guest = (raw['guestUid'] ?? '').toString();
      if (caller != host && caller != guest) return Transaction.abort();
      if ((raw['disconnectUid'] ?? '').toString() != reconnectedUid) {
        return Transaction.abort();
      }
      raw.remove('disconnectUid');
      raw.remove('disconnectStartedAt');
      raw.remove('disconnectDeadlineAt');
      raw['disconnectResolved'] = true;
      raw['updatedAt'] = ServerValue.timestamp;
      return Transaction.success(raw);
    });
    return result.committed;
  }

  /// Atomically awards a disconnect forfeit after the grace deadline. Every
  /// precondition is rechecked inside RTDB, making duplicate timeout calls safe.
  Future<bool> finishRoomByDisconnectForfeit({
    required String code,
    required String disconnectedUid,
    required String winnerUid,
  }) async {
    final caller = _uid;
    if (caller == null || caller != winnerUid) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = await _roomsRef.child(code).runTransaction((current) {
      final raw = _asRoomMap(current);
      if (raw == null) return Transaction.abort();
      final host = (raw['hostUid'] ?? '').toString();
      final guest = (raw['guestUid'] ?? '').toString();
      if (winnerUid != host && winnerUid != guest) return Transaction.abort();
      if (disconnectedUid != host && disconnectedUid != guest) {
        return Transaction.abort();
      }
      if ((winnerUid == host ? guest : host) != disconnectedUid) {
        return Transaction.abort();
      }
      final status = (raw['status'] ?? '').toString();
      if (!const <String>{
        'waiting',
        'ready',
        'countdown',
        'playing',
        'round_end'
      }.contains(status)) {
        return Transaction.abort();
      }
      if ((raw['disconnectUid'] ?? '').toString() != disconnectedUid ||
          raw['disconnectResolved'] == true) {
        return Transaction.abort();
      }
      final deadline = (raw['disconnectDeadlineAt'] as num?)?.toInt() ?? 0;
      if (deadline <= 0 || now < deadline) return Transaction.abort();
      final presence = raw['playersPresence'];
      if (presence is Map) {
        final entry = presence[disconnectedUid];
        if (entry is Map && (entry['state'] ?? '').toString() == 'online') {
          final lastSeen = (entry['lastSeenMs'] as num?)?.toInt() ?? 0;
          if (now - lastSeen <= 10000) return Transaction.abort();
        }
      }
      raw['status'] = 'finished';
      raw['roomWinnerUid'] = winnerUid;
      raw['result'] = 'disconnect_forfeit';
      raw['finalResult'] = 'disconnect_forfeit';
      raw['loserUid'] = disconnectedUid;
      raw['leftByUid'] = disconnectedUid;
      raw['finishedAt'] = ServerValue.timestamp;
      raw['updatedAt'] = ServerValue.timestamp;
      raw['disconnectResolved'] = true;
      return Transaction.success(raw);
    });
    return result.committed;
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
    required int roundVersion,
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
      'lastRoundResult': 'win',
      'lastRoundEndAt': ServerValue.timestamp,
      'roundVersion': roundVersion + 1,
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
      debugPrint(
          '[ARENA_ROUND] room=$code round=$currentRound result=match_end winner=$roomWinnerUid');
    }
  }

  /// Host-only: kick the current guest from a lobby room and stamp a
  /// rejoin-cooldown entry under `kickedUsers/<guestUid>` so the same uid
  /// cannot rejoin for [kArenaKickCooldownMs] ms. Allowed only while the
  /// room is pre-play (`status in {waiting, ready, countdown}`).
  ///
  /// All RTDB writes go in a single multi-path [DatabaseReference.update]
  /// so the room can never end up half-cleared if one rule denies.
  ///
  /// Returns a structured [ArenaKickResult] so the UI can show a specific
  /// message instead of a generic "Could not kick player" toast.
  Future<ArenaKickResult> kickGuest({required String code}) async {
    final uid = _uid;
    if (uid == null) {
      return const ArenaKickResult.fail(ArenaKickFailure.notHost);
    }
    final ref = _roomsRef.child(code);
    final snap = await _withTimeoutOrNull(ref.get(),
        timeout: const Duration(seconds: 5), label: 'kickGuest.read');
    if (snap == null) {
      if (kDebugMode) {
        debugPrint('[ARENA_KICK] failed step=read reason=network');
      }
      return const ArenaKickResult.fail(ArenaKickFailure.network);
    }
    if (!snap.exists) {
      if (kDebugMode) {
        debugPrint('[ARENA_KICK] failed step=read reason=no_room');
      }
      return const ArenaKickResult.fail(ArenaKickFailure.unknown);
    }
    final raw = _asRoomMap(snap.value);
    if (raw == null) {
      if (kDebugMode) {
        debugPrint('[ARENA_KICK] failed step=read reason=bad_shape');
      }
      return const ArenaKickResult.fail(ArenaKickFailure.unknown);
    }
    final hostUid = (raw['hostUid'] ?? '').toString();
    if (hostUid != uid) {
      if (kDebugMode) {
        debugPrint('[ARENA_KICK] failed step=preflight reason=notHost '
            'caller=$uid host=$hostUid');
      }
      return const ArenaKickResult.fail(ArenaKickFailure.notHost);
    }
    final guestUid = (raw['guestUid'] ?? '').toString();
    if (guestUid.isEmpty) {
      if (kDebugMode) {
        debugPrint(
            '[ARENA_KICK] failed step=preflight reason=noGuest code=$code');
      }
      return const ArenaKickResult.fail(ArenaKickFailure.noGuest);
    }
    final status = (raw['status'] ?? 'waiting').toString();
    if (status != 'waiting' && status != 'ready' && status != 'countdown') {
      if (kDebugMode) {
        debugPrint('[ARENA_KICK] failed step=preflight reason=badStatus '
            'status=$status code=$code');
      }
      return const ArenaKickResult.fail(ArenaKickFailure.badStatus);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final untilMs = now + kArenaKickCooldownMs;
    final xUid = (raw['xUid'] ?? '').toString();
    final oUid = (raw['oUid'] ?? '').toString();
    if (kDebugMode) {
      debugPrint('[ARENA_KICK] attempt room=$code host=$uid '
          'guest=$guestUid status=$status');
    }

    final updates = <String, Object?>{
      'guestUid': null,
      'guestName': null,
      'guestPhoto': null,
      'guestPhotoURL': null,
      'guestReady': false,
      'status': 'waiting',
      'updatedAt': ServerValue.timestamp,
      if (xUid == guestUid) 'xUid': '__pending__',
      if (oUid == guestUid) 'oUid': '__pending__',
      'kickedUsers/$guestUid': <String, Object?>{
        'kickedAt': ServerValue.timestamp,
        'byUid': uid,
        'untilMs': untilMs,
        'reason': 'host_kick',
      },
      'playersPresence/$guestUid': null,
      'players/$guestUid': null,
    };

    try {
      if (kDebugMode) {
        debugPrint('[ARENA_KICK] step=write_multipath path=/rooms/$code '
            'fields=${updates.keys.length}');
      }
      await ref.update(updates);
      if (kDebugMode) {
        debugPrint('[ARENA_KICK] success room=$code untilMs=$untilMs');
      }
      // Best-effort: drop the kicked guest's active-room mirror so their
      // app doesn't try to re-resume into this room on next launch. Not
      // load-bearing for the kick itself.
      await _withTimeoutOrNull(
        _activeRoomRef(guestUid).delete(),
        label: 'kickGuest.clearMirror',
      );
      return const ArenaKickResult.ok();
    } on FirebaseException catch (e) {
      final reason = e.code == 'permission-denied'
          ? ArenaKickFailure.permissionDenied
          : (e.code == 'network-error' || e.code == 'unavailable'
              ? ArenaKickFailure.network
              : ArenaKickFailure.unknown);
      if (kDebugMode) {
        if (e.code == 'permission-denied') {
          debugPrint(
              '[RTDB_DENIED] op=kickGuest room=$code error=${e.message}');
        }
        debugPrint('[ARENA_KICK] failed step=write_multipath '
            'reason=$reason error=${e.code}:${e.message}');
      }
      return ArenaKickResult.fail(reason);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ARENA_KICK] failed step=write_multipath '
            'reason=unknown error=$e');
      }
      return const ArenaKickResult.fail(ArenaKickFailure.unknown);
    }
  }

  /// Mid-match host-cancel with bet refund. Writes status='cancelled' and
  /// `result='cancelled'` so the guest's listener exits cleanly. Each
  /// client refunds their own bet via [ArenaBetService.refundOwnBet] on the
  /// status flip — this method just signals the cancel.
  Future<void> cancelMatchWithRefund({
    required String code,
    required String selfUid,
  }) async {
    try {
      await _roomsRef.child(code).update(<String, Object?>{
        'status': 'cancelled',
        'result': 'cancelled',
        'finalResult': 'cancelled',
        'cancelledByUid': selfUid,
        'cancelledAt': ServerValue.timestamp,
        'finishedAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      }).timeout(const Duration(seconds: 5));
      if (kDebugMode) {
        debugPrint(
            '[ARENA] match cancelled-with-refund room=$code by=$selfUid');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ARENA] cancelMatchWithRefund failed: $e');
    }
  }

  /// Registers an RTDB `onDisconnect()` write that stamps a leave marker
  /// under `_hostLeftAt` or `_guestLeftAt` if the socket drops without the
  /// app cleanly leaving. The room listener on the other side reacts to
  /// this marker as a fallback for force-kill / OS-killed scenarios.
  ///
  /// The marker is purely informational — primary lifecycle handling
  /// happens in the page's `WidgetsBindingObserver`. This is the
  /// safety net.
  Future<void> registerLeaveOnDisconnect({
    required String code,
    required bool isHost,
  }) async {
    try {
      final field = isHost ? '_hostLeftAt' : '_guestLeftAt';
      await _roomsRef.child(code).child(field).onDisconnect().set(
            ServerValue.timestamp,
          );
    } catch (e) {
      if (kDebugMode) debugPrint('[ARENA] onDisconnect register failed: $e');
    }
  }

  /// Cancel any pending `onDisconnect()` writes for this room. Should be
  /// called from the page's normal exit path so a clean leave does not
  /// trigger a phantom leave-marker after the user returns to the menu.
  Future<void> cancelLeaveOnDisconnect({
    required String code,
    required bool isHost,
  }) async {
    try {
      final field = isHost ? '_hostLeftAt' : '_guestLeftAt';
      await _roomsRef.child(code).child(field).onDisconnect().cancel();
    } catch (_) {}
  }

  /// Reads the active-room mirror reference for an external caller. Used by
  /// the presence service / kick flow to clear the kicked guest's pointer.
  DocumentReference<Map<String, dynamic>> activeRoomRef(String uid) =>
      _activeRoomRef(uid);

  /// Direct RTDB ref to a room — exposed for the presence service to
  /// register its per-room heartbeat + onDisconnect.
  DatabaseReference roomRef(String code) => _roomsRef.child(code);

  /// Host-only: mark the room with a `cleanupAfter` timestamp so any
  /// observer (the host's own Timer, a Cloud Function janitor, or a future
  /// reconnecting client) knows when the RTDB node is safe to remove.
  /// Default grace period is 25 seconds.
  Future<void> setCleanupAfter(String code,
      {Duration grace = const Duration(seconds: 25)}) async {
    final cleanupAt =
        DateTime.now().millisecondsSinceEpoch + grace.inMilliseconds;
    try {
      await _roomsRef.child(code).update(<String, Object?>{
        'cleanupAfter': cleanupAt,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (_) {}
  }

  // NOTE: the legacy `leaveRoom({room, leaverUid})` was removed — every leave
  // now routes through [resolvePlayerLeaveRoom], which records `loserUid` +
  // `leftByUid` so the opponent's idempotent `creditPrize` guard can settle a
  // bet forfeit correctly. Pre-play cancels still reuse [cancelRoomAsHost] /
  // [leaveRoomAsGuest].

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
            debugPrint(
                '[ARENA] cancel skipped — caller is not host room=$code');
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
          debugPrint(
              '[ARENA] cancel remove failed, falling back to status=cancelled: $e');
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
    if (kDebugMode) {
      debugPrint('[ARENA] guest leave requested room=$code uid=$uid');
    }
    final ref = _roomsRef.child(code);
    try {
      final snap = await ref.get().timeout(const Duration(seconds: 5));
      if (!snap.exists) {
        await clearActiveRoomMirror(uid);
        return;
      }
      final raw = _asRoomMap(snap.value) ?? const <dynamic, dynamic>{};
      final status = (raw['status'] ?? 'waiting').toString();
      final beforePlay = status == 'waiting' || status == 'ready';
      if (beforePlay) {
        try {
          await ref
              .child('guestUid')
              .set(null)
              .timeout(const Duration(seconds: 5));
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

  /// Single safe funnel for an *intentional* leave decision (the "Leave Room &
  /// Play Normally" resume choice, the explicit Leave/Cancel buttons, and the
  /// create-room guard). Reads the live room and resolves it fairly:
  ///
  ///  • room missing / already terminal → no-op (clear mirror).
  ///  • caller is not a member → no-op (clear mirror).
  ///  • pre-play AND no coins locked → cancel room (host) / clear seat (guest);
  ///    no coin movement.
  ///  • coins locked OR match started → forfeit: the leaver is the loser and
  ///    the opponent is recorded as `roomWinnerUid`. The opponent's client
  ///    (live, or via its startup settlement) performs the idempotent payout.
  ///
  /// Always clears the leaver's active-room mirror and never throws.
  Future<RoomLeaveResolution> resolvePlayerLeaveRoom({
    required String roomCode,
    required String leaverUid,
    required String reason,
  }) async {
    if (kDebugMode) {
      debugPrint('[ROOM_LEAVE_RESOLVE] start room=$roomCode '
          'leaver=$leaverUid reason=$reason');
    }

    Future<RoomLeaveResolution> finish(RoomLeaveResolution res) async {
      await clearActiveRoomMirror(leaverUid);
      if (kDebugMode) {
        debugPrint('[ROOM_LEAVE_RESOLVE] active_room_cleared uid=$leaverUid');
        debugPrint('[ROOM_LEAVE_RESOLVE] done room=$roomCode');
      }
      return res;
    }

    ArenaRoom? room;
    try {
      room = await readRoom(roomCode).timeout(const Duration(seconds: 6));
    } catch (_) {
      room = null;
    }

    if (room == null) {
      if (kDebugMode) debugPrint('[ROOM_LEAVE_RESOLVE] mode=already_resolved');
      return finish(const RoomLeaveResolution(RoomLeaveMode.alreadyResolved));
    }

    const terminal = <String>{
      'finished',
      'expired',
      'cancelled',
      'abandoned',
    };
    final isMember = leaverUid == room.hostUid || leaverUid == room.guestUid;
    if (terminal.contains(room.status)) {
      if (kDebugMode) debugPrint('[ROOM_LEAVE_RESOLVE] mode=already_resolved');
      return finish(const RoomLeaveResolution(RoomLeaveMode.alreadyResolved));
    }
    if (!isMember) {
      if (kDebugMode) debugPrint('[ROOM_LEAVE_RESOLVE] mode=not_member');
      return finish(const RoomLeaveResolution(RoomLeaveMode.notMember));
    }

    final isHost = leaverUid == room.hostUid;
    final beforePlay = room.status == 'waiting' ||
        room.status == 'ready' ||
        room.status == 'countdown';
    final coinsAtStake =
        room.betEnabled && room.coinsLocked && room.betAmount > 0;

    // ── Cancel path: pre-play with no committed bet. ─────────────────────────
    if (beforePlay && !coinsAtStake) {
      if (isHost) {
        await cancelRoomAsHost(roomCode); // clears its own mirror
      } else {
        await leaveRoomAsGuest(roomCode); // clears its own mirror
      }
      if (kDebugMode) {
        debugPrint('[ROOM_LEAVE_RESOLVE] mode=cancel');
        debugPrint('[ROOM_LEAVE_RESOLVE] betEnabled=${room.betEnabled} '
            'bet=${room.betAmount} prize=${room.prizePool}');
        debugPrint('[ROOM_LEAVE_RESOLVE] payout_applied=false');
      }
      // Both helpers already clear the mirror; finish() is idempotent.
      return finish(RoomLeaveResolution(
        RoomLeaveMode.cancel,
        betEnabled: room.betEnabled,
        betAmount: room.betAmount,
        prizePool: room.prizePool,
      ));
    }

    // ── Forfeit path: coins locked or the match has started. ─────────────────
    final winnerUid = room.opponentOf(leaverUid);
    try {
      await _roomsRef.child(roomCode).update(<String, Object?>{
        'status': 'finished',
        'roomWinnerUid': winnerUid.isEmpty ? null : winnerUid,
        'result': 'forfeit',
        'finalResult': 'opponent_left',
        'loserUid': leaverUid,
        'leftByUid': leaverUid,
        'leftAt': ServerValue.timestamp,
        'finishedAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      }).timeout(const Duration(seconds: 6));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ROOM_LEAVE_RESOLVE] forfeit write failed: $e');
      }
    }
    if (kDebugMode) {
      debugPrint('[ROOM_LEAVE_RESOLVE] mode=forfeit');
      debugPrint('[ROOM_LEAVE_RESOLVE] winner=$winnerUid loser=$leaverUid');
      debugPrint('[ROOM_LEAVE_RESOLVE] betEnabled=${room.betEnabled} '
          'bet=${room.betAmount} prize=${room.prizePool}');
      // Payout is applied by the opponent's client (idempotent), not here.
      debugPrint('[ROOM_LEAVE_RESOLVE] payout_applied=false');
    }
    return finish(RoomLeaveResolution(
      RoomLeaveMode.forfeit,
      winnerUid: winnerUid.isEmpty ? null : winnerUid,
      loserUid: leaverUid,
      betEnabled: room.betEnabled,
      betAmount: room.betAmount,
      prizePool: room.prizePool,
    ));
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

  /// Mark a room expired WITHOUT removing the RTDB node, leaving a grace window
  /// (`cleanupAfter`) so BOTH players can observe the expiry and refund their
  /// own locked bet on their next app open. The Cloud Function janitor (or a
  /// host cleanup timer) removes the node after the grace window. Use this for
  /// *occupied* stale rooms; [expireRoom] (mark + remove) is fine for empty
  /// waiting rooms where there is nothing to refund.
  Future<void> markRoomExpired(
    String code, {
    Duration grace = const Duration(minutes: 2),
  }) async {
    final cleanupAt =
        DateTime.now().millisecondsSinceEpoch + grace.inMilliseconds;
    try {
      await _roomsRef.child(code).update(<String, Object?>{
        'status': 'expired',
        'result': 'expired',
        'finalResult': 'expired',
        'cleanupAfter': cleanupAt,
        'updatedAt': ServerValue.timestamp,
      }).timeout(const Duration(seconds: 5));
      if (kDebugMode) {
        debugPrint('[ROOM_TIMEOUT] expired room=$code reason=20min_inactive');
      }
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
