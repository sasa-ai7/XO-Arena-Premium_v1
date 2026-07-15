/// Live private friend room state mirrored in Firebase Realtime Database
/// under `rooms/{roomCode}`.
///
/// Rooms have a hard maximum lifetime of 10 minutes from [createdAt]. They
/// are deleted from RTDB as soon as the match ends, or opportunistically by
/// any client that observes an expired room.
class ArenaRoom {
  /// 6-digit numeric code (also the RTDB key).
  final String roomCode;

  final String hostUid;
  final String hostName;
  final String? hostPhoto;
  final bool hostReady;

  final String? guestUid;
  final String? guestName;
  final String? guestPhoto;
  final bool guestReady;

  /// One of: waiting | ready | countdown | playing | finished | abandoned | expired.
  final String status;

  /// Current round's board size (3/4/5). Derived from
  /// `roundMaps[currentRoundIndex]` when present; mirrored on this top-level
  /// field for RTDB-rule compatibility and the existing board reset logic.
  final int boardSize;
  final List<String> board;

  final int roundsCount;

  /// 0-based index into [roundMaps]. Kept alongside the legacy 1-based
  /// [currentRound] for back-compat.
  final int currentRoundIndex;
  final int currentRound;

  /// Per-round map labels, length == [roundsCount]. e.g. `["3x3","4x4","5x5"]`.
  final List<String> roundMaps;

  final int scoreHost;
  final int scoreGuest;

  final String xUid;
  final String oUid;
  final String? turnUid;

  final String? roundWinnerUid;
  final String? roomWinnerUid;

  /// One of: null | completed | forfeit | expired | cancelled.
  final String? result;

  /// Plain-English reason for the room ending, persisted to
  /// `online_room_history`. One of: "completed" | "opponent_left" | "expired".
  final String? finalResult;

  final bool betEnabled;
  final int betAmount;
  final int prizePool;

  /// Convenience alias for [prizePool] used in share messages.
  int get potAmount => prizePool;

  final bool coinsLocked;
  final bool payoutApplied;

  /// Entry-bet lock flags keyed by uid. Both players must be true before
  /// coinsLocked can become true and before payout is allowed.
  final Map<String, bool> betLocks;

  /// Rich per-player profile sub-map keyed by uid. Each value is a `Map`
  /// with: `uid`, `name`, `photoURL`, `selectedAvatar`, `selectedXSkin`,
  /// `selectedOSkin`, `coinsAtJoin`. Optional — may be empty on legacy rooms.
  final Map<String, dynamic> players;

  /// Map of uid → kick metadata for users the host has removed from this
  /// room. Each value contains `kickedAt` (server timestamp), `byUid` (host),
  /// and `untilMs` (epoch ms after which the same uid may rejoin).
  final Map<String, Map<String, dynamic>> kickedUsers;

  /// Map of uid → presence record: `state` (online/weak/offline),
  /// `lastSeenMs`, `updatedAt`. Each player only writes their own entry;
  /// `weak` is a derived state computed locally from staleness.
  final Map<String, Map<String, dynamic>> playersPresence;

  /// Active two-minute reconnect grace window, if any.
  final String? disconnectUid;
  final int? disconnectStartedAt;
  final int? disconnectDeadlineAt;
  final bool disconnectResolved;

  /// Most recent round outcome marker, written by the host on every round
  /// resolution. Used by both clients to drive the round-end banner —
  /// especially the draw case where `roundWinnerUid` stays null and the
  /// board is reset, so there is no other signal to react to.
  /// One of: null | "win" | "draw".
  final String? lastRoundResult;

  /// Server timestamp (epoch ms) of the most recent round resolution. The
  /// banner key is `${lastRoundEndAt}:${lastRoundResult}` so a redelivered
  /// snapshot never retriggers the banner.
  final int? lastRoundEndAt;

  /// Monotonically increasing counter bumped on every round transition.
  /// Used by the UI to key the board widget and dedupe round resolution.
  final int roundVersion;

  final int createdAt;
  final int updatedAt;
  final int? startedAt;
  final int expiresAt;
  final int? finishedAt;

  final String matchId;

  const ArenaRoom({
    required this.roomCode,
    required this.hostUid,
    required this.hostName,
    required this.hostPhoto,
    required this.hostReady,
    required this.guestUid,
    required this.guestName,
    required this.guestPhoto,
    required this.guestReady,
    required this.status,
    required this.boardSize,
    required this.board,
    required this.roundsCount,
    required this.currentRoundIndex,
    required this.currentRound,
    required this.roundMaps,
    required this.scoreHost,
    required this.scoreGuest,
    required this.xUid,
    required this.oUid,
    required this.turnUid,
    required this.roundWinnerUid,
    required this.roomWinnerUid,
    required this.result,
    required this.finalResult,
    required this.betEnabled,
    required this.betAmount,
    required this.prizePool,
    required this.coinsLocked,
    required this.payoutApplied,
    required this.betLocks,
    required this.players,
    this.kickedUsers = const <String, Map<String, dynamic>>{},
    this.playersPresence = const <String, Map<String, dynamic>>{},
    this.disconnectUid,
    this.disconnectStartedAt,
    this.disconnectDeadlineAt,
    this.disconnectResolved = false,
    this.lastRoundResult,
    this.lastRoundEndAt,
    this.roundVersion = 0,
    required this.createdAt,
    required this.updatedAt,
    required this.startedAt,
    required this.expiresAt,
    required this.finishedAt,
    required this.matchId,
  });

  bool get isWaiting => status == 'waiting';
  bool get isReady => status == 'ready';
  bool get isCountdown => status == 'countdown';
  bool get isPlaying => status == 'playing';
  bool get isFinished => status == 'finished';
  bool get isExpired => status == 'expired';
  bool get isCancelled => status == 'cancelled';
  bool get isAbandoned => status == 'abandoned';
  bool get isRoundEnd => status == 'round_end';

  /// True when both seats are filled.
  bool get isFull => guestUid != null && guestUid!.isNotEmpty;

  /// Board size for the round currently in play (derived from [roundMaps]).
  int get currentBoardSize {
    if (currentRoundIndex < 0 || currentRoundIndex >= roundMaps.length) {
      return boardSize;
    }
    final label = roundMaps[currentRoundIndex];
    final n = int.tryParse(label.split('x').first);
    return n ?? boardSize;
  }

  /// Symbol ('X' or 'O') for the given uid, or empty when unmatched.
  String symbolFor(String uid) {
    if (uid == xUid) return 'X';
    if (uid == oUid) return 'O';
    return '';
  }

  String opponentOf(String uid) {
    if (uid == hostUid) return guestUid ?? '';
    return hostUid;
  }

  /// Returns the kick `untilMs` (epoch) for the given uid if it is currently
  /// within an active cooldown window; null otherwise.
  int? kickCooldownUntilMs(String uid) {
    final entry = kickedUsers[uid];
    if (entry == null) return null;
    final until = (entry['untilMs'] as num?)?.toInt();
    if (until == null) return null;
    if (until <= DateTime.now().millisecondsSinceEpoch) return null;
    return until;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'roomCode': roomCode,
        'hostUid': hostUid,
        'hostName': hostName,
        'hostPhoto': hostPhoto,
        'hostReady': hostReady,
        'guestUid': guestUid,
        'guestName': guestName,
        'guestPhoto': guestPhoto,
        'guestReady': guestReady,
        'status': status,
        'boardSize': boardSize,
        'board': board,
        'roundsCount': roundsCount,
        'currentRound': currentRound,
        'currentRoundIndex': currentRoundIndex,
        'roundMaps': roundMaps,
        'score': <String, dynamic>{
          'host': scoreHost,
          'guest': scoreGuest,
        },
        'xUid': xUid,
        'oUid': oUid,
        'turnUid': turnUid,
        'roundWinnerUid': roundWinnerUid,
        'roomWinnerUid': roomWinnerUid,
        'result': result,
        'finalResult': finalResult,
        'betEnabled': betEnabled,
        'betAmount': betAmount,
        'prizePool': prizePool,
        'potAmount': prizePool,
        'coinsLocked': coinsLocked,
        'payoutApplied': payoutApplied,
        'betLocks': betLocks,
        'players': players,
        'kickedUsers': kickedUsers,
        'playersPresence': playersPresence,
        if (disconnectUid != null) 'disconnectUid': disconnectUid,
        if (disconnectStartedAt != null)
          'disconnectStartedAt': disconnectStartedAt,
        if (disconnectDeadlineAt != null)
          'disconnectDeadlineAt': disconnectDeadlineAt,
        'disconnectResolved': disconnectResolved,
        if (lastRoundResult != null) 'lastRoundResult': lastRoundResult,
        if (lastRoundEndAt != null) 'lastRoundEndAt': lastRoundEndAt,
        'roundVersion': roundVersion,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'startedAt': startedAt,
        'expiresAt': expiresAt,
        'finishedAt': finishedAt,
        'matchId': matchId,
      };

  static ArenaRoom fromMap(Map<dynamic, dynamic> raw) {
    final score = (raw['score'] as Map?) ?? const <String, dynamic>{};
    final int boardSizeRaw = (raw['boardSize'] as num?)?.toInt() ?? 3;
    final int roundsCount = (raw['roundsCount'] as num?)?.toInt() ?? 1;

    final boardRaw = raw['board'];
    List<String> board;
    if (boardRaw is List) {
      board = boardRaw.map((e) => (e ?? '').toString()).toList();
    } else if (boardRaw is Map) {
      final cellCount = boardSizeRaw * boardSizeRaw;
      board = List<String>.filled(cellCount, '');
      boardRaw.forEach((k, v) {
        final i = int.tryParse(k.toString());
        if (i != null && i >= 0 && i < cellCount) {
          board[i] = (v ?? '').toString();
        }
      });
    } else {
      board = const <String>[];
    }

    final mapsRaw = raw['roundMaps'];
    List<String> roundMaps;
    if (mapsRaw is List) {
      roundMaps = mapsRaw
          .map((e) => (e ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (mapsRaw is Map) {
      final entries = <int, String>{};
      mapsRaw.forEach((k, v) {
        final i = int.tryParse(k.toString());
        if (i != null) entries[i] = (v ?? '').toString();
      });
      final sorted = entries.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      roundMaps = sorted.map((e) => e.value).toList();
    } else {
      roundMaps =
          List<String>.filled(roundsCount, '${boardSizeRaw}x$boardSizeRaw');
    }
    if (roundMaps.length < roundsCount) {
      roundMaps = List<String>.from(roundMaps)
        ..addAll(List<String>.filled(
            roundsCount - roundMaps.length, '${boardSizeRaw}x$boardSizeRaw'));
    } else if (roundMaps.length > roundsCount) {
      roundMaps = roundMaps.sublist(0, roundsCount);
    }

    final currentRound = (raw['currentRound'] as num?)?.toInt() ?? 1;
    final currentRoundIndexRaw = (raw['currentRoundIndex'] as num?)?.toInt();
    final currentRoundIndex = currentRoundIndexRaw ??
        (currentRound - 1).clamp(0, roundsCount - 1).toInt();

    final betLocksRaw = raw['betLocks'];
    final betLocks = <String, bool>{};
    if (betLocksRaw is Map) {
      betLocksRaw.forEach((k, v) {
        betLocks[k.toString()] = v == true;
      });
    }

    final playersRaw = raw['players'];
    final players = <String, dynamic>{};
    if (playersRaw is Map) {
      playersRaw.forEach((k, v) {
        players[k.toString()] = v;
      });
    }

    final kickedRaw = raw['kickedUsers'];
    final kickedUsers = <String, Map<String, dynamic>>{};
    if (kickedRaw is Map) {
      kickedRaw.forEach((k, v) {
        if (v is Map) {
          kickedUsers[k.toString()] = Map<String, dynamic>.from(
              v.map((kk, vv) => MapEntry(kk.toString(), vv)));
        }
      });
    }

    final presenceRaw = raw['playersPresence'];
    final playersPresence = <String, Map<String, dynamic>>{};
    if (presenceRaw is Map) {
      presenceRaw.forEach((k, v) {
        if (v is Map) {
          playersPresence[k.toString()] = Map<String, dynamic>.from(
              v.map((kk, vv) => MapEntry(kk.toString(), vv)));
        }
      });
    }

    final guestUidRaw = raw['guestUid'];
    final guestUid =
        (guestUidRaw is String && guestUidRaw.isNotEmpty) ? guestUidRaw : null;

    final prizePool = (raw['prizePool'] as num?)?.toInt() ??
        (raw['potAmount'] as num?)?.toInt() ??
        0;

    return ArenaRoom(
      roomCode: (raw['roomCode'] ?? '').toString(),
      hostUid: (raw['hostUid'] ?? '').toString(),
      hostName: (raw['hostName'] ?? '').toString(),
      hostPhoto: raw['hostPhoto']?.toString(),
      hostReady: raw['hostReady'] == true,
      guestUid: guestUid,
      guestName: raw['guestName'] as String?,
      guestPhoto: raw['guestPhoto'] as String?,
      guestReady: raw['guestReady'] == true,
      status: (raw['status'] ?? 'waiting').toString(),
      boardSize: boardSizeRaw,
      board: board,
      roundsCount: roundsCount,
      currentRound: currentRound,
      currentRoundIndex: currentRoundIndex,
      roundMaps: roundMaps,
      scoreHost: (score['host'] as num?)?.toInt() ?? 0,
      scoreGuest: (score['guest'] as num?)?.toInt() ?? 0,
      xUid: (raw['xUid'] ?? '').toString(),
      oUid: (raw['oUid'] ?? '').toString(),
      turnUid: raw['turnUid'] as String?,
      roundWinnerUid: raw['roundWinnerUid'] as String?,
      roomWinnerUid: raw['roomWinnerUid'] as String?,
      result: raw['result'] as String?,
      finalResult: raw['finalResult'] as String?,
      betEnabled: raw['betEnabled'] == true,
      betAmount: (raw['betAmount'] as num?)?.toInt() ?? 0,
      prizePool: prizePool,
      coinsLocked: raw['coinsLocked'] == true,
      payoutApplied: raw['payoutApplied'] == true,
      betLocks: betLocks,
      players: players,
      kickedUsers: kickedUsers,
      playersPresence: playersPresence,
      disconnectUid: raw['disconnectUid'] as String?,
      disconnectStartedAt: (raw['disconnectStartedAt'] as num?)?.toInt(),
      disconnectDeadlineAt: (raw['disconnectDeadlineAt'] as num?)?.toInt(),
      disconnectResolved: raw['disconnectResolved'] == true,
      lastRoundResult: raw['lastRoundResult'] as String?,
      lastRoundEndAt: (raw['lastRoundEndAt'] as num?)?.toInt(),
      roundVersion: (raw['roundVersion'] as num?)?.toInt() ?? 0,
      createdAt: (raw['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (raw['updatedAt'] as num?)?.toInt() ?? 0,
      startedAt: (raw['startedAt'] as num?)?.toInt(),
      expiresAt: (raw['expiresAt'] as num?)?.toInt() ?? 0,
      finishedAt: (raw['finishedAt'] as num?)?.toInt(),
      matchId: (raw['matchId'] ?? '').toString(),
    );
  }
}
