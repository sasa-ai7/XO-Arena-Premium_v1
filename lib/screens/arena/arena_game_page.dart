import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_config.dart';
import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../core/keys.dart';
import '../../models/arena/arena_room.dart';
import '../../models/game_avatar.dart';
import '../../services/arena/arena_bet_service.dart';
import '../../services/arena/arena_match_summary.dart';
import '../../services/arena/arena_repo.dart';
import '../../utils/board_utils.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/arena_toast.dart';
import '../games/game_page.dart' show CellContent;
import 'widgets/arena_leave_dialog.dart';
import 'widgets/arena_player_card.dart';
import 'widgets/countdown_overlay.dart';

class ArenaGamePage extends StatefulWidget {
  final ArenaRoom initialRoom;
  const ArenaGamePage({super.key, required this.initialRoom});

  @override
  State<ArenaGamePage> createState() => _ArenaGamePageState();
}

class _ArenaGamePageState extends State<ArenaGamePage> {
  late ArenaRoom _room;
  StreamSubscription<ArenaRoom?>? _sub;

  bool _showCountdown = false;
  bool _movePending = false;
  bool _summaryWritten = false;
  bool _roundResolving = false;
  bool _isLeaving = false;
  bool _hasExitedRoom = false;
  Timer? _cleanupTimer;

  // Connection tracking — used to distinguish transient network loss from
  // a real room deletion. While disconnected we show a "Reconnecting…"
  // overlay and refuse to forfeit or exit.
  StreamSubscription<DatabaseEvent>? _connSub;
  bool _isConnected = true;
  bool _everConnected = false;

  /// Tracks scores we've already credited towards in case of replays.
  int? _lastResolvedRound;

  // Bet-lock guards — prevent the room listener from re-locking on every snapshot.
  bool _betLockCheckRunning = false;
  bool _betLockDoneForThisRoom = false;
  bool _coinsLockMarked = false;
  String? _lastBetLockRoomCode;
  String? _lastBetLockMatchId;

  // Round-end winning-cells glow (local-only animation; no RTDB writes).
  // `_lastAnimatedRoundKey` keys on `currentRoundIndex|winnerUid` so the
  // same snapshot redelivered does not retrigger the animation.
  Set<int> _winningCells = const <int>{};
  String? _lastAnimatedRoundKey;
  _RoundEndBanner? _roundEndBanner;

  // Captured at payout time so the final-result dialog can render the
  // gold "+N coins" line only when the wallet was actually credited.
  int _finalCoinsWon = 0;

  // Self-equipped cosmetics (mirrors the local game). Loaded once at init so
  // the board renders the same X/O artwork the user sees in offline modes.
  String _selfXSkin = 'default';
  String _selfOSkin = 'default';
  int _selfAvatarId = 0;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool get _isHost => _uid != null && _uid == _room.hostUid;

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    _sub = ArenaRepo.instance.watchRoom(_room.roomCode).listen(
          _onRoomChange,
          onError: (Object e) {
            // Treat stream errors as transient — do NOT forfeit.
            if (mounted) setState(() => _isConnected = false);
          },
        );
    _listenForConnectivity();
    _loadSelfCosmetics();
    _maybeStartCountdown();
    _maybeLockBet();
  }

  Future<void> _loadSelfCosmetics() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _selfXSkin = p.getString(Keys.selectedXSkin) ?? 'default';
        _selfOSkin = p.getString(Keys.selectedOSkin) ?? 'default';
        _selfAvatarId = p.getInt(Keys.equippedAvatar) ?? 0;
      });
    } catch (_) {}
  }

  /// Resolve which X/O skin string to render for a given owner uid + symbol.
  /// Self always uses prefs; opponent falls back to whatever was persisted
  /// under `room.players[uid].selected{X,O}Skin`.
  String _skinFor(String? uid, String symbol) {
    if (uid == null || uid.isEmpty) return 'default';
    if (uid == _uid) {
      return symbol == 'X' ? _selfXSkin : _selfOSkin;
    }
    final entry = _room.players[uid];
    if (entry is Map) {
      final key = symbol == 'X' ? 'selectedXSkin' : 'selectedOSkin';
      final v = entry[key];
      if (v is String && v.isNotEmpty) return v;
    }
    return 'default';
  }

  GameAvatar? _avatarFor(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    if (uid == _uid) return gameAvatarByIdOrNull(_selfAvatarId);
    final entry = _room.players[uid];
    if (entry is Map) {
      final raw = entry['selectedAvatar'];
      final id = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '') ?? 0;
      return gameAvatarByIdOrNull(id);
    }
    return null;
  }

  String? _photoFor(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    if (uid == _uid) return null; // self uses bound notifiers
    final entry = _room.players[uid];
    if (entry is Map) {
      final v = entry['photoURL'];
      if (v is String && v.isNotEmpty) return v;
    }
    if (uid == _room.hostUid) return _room.hostPhoto;
    if (uid == _room.guestUid) return _room.guestPhoto;
    return null;
  }

  void _listenForConnectivity() {
    try {
      final connRef = FirebaseDatabase.instanceFor(
        app: FirebaseDatabase.instance.app,
        databaseURL: kArenaDatabaseUrl,
      ).ref('.info/connected');
      _connSub = connRef.onValue.listen((event) {
        final connected = (event.snapshot.value == true);
        if (!mounted) return;
        setState(() {
          _isConnected = connected;
          if (connected) _everConnected = true;
        });
      });
    } catch (_) {}
  }

  Future<void> _maybeLockBet() async {
    final uid = _uid;
    if (uid == null || !_room.betEnabled || !AppConfig.kEnableFriendRoomBetting) {
      return;
    }
    if (_betLockCheckRunning) return;
    // Hard short-circuits: if room-level lock is set, we're fully done.
    if (_room.coinsLocked) {
      _betLockDoneForThisRoom = true;
      _coinsLockMarked = true;
      _lastBetLockRoomCode = _room.roomCode;
      _lastBetLockMatchId = _room.matchId;
      return;
    }
    if (_betLockDoneForThisRoom &&
        _lastBetLockRoomCode == _room.roomCode &&
        _lastBetLockMatchId == _room.matchId) {
      return;
    }
    final selfAlreadyLocked = _room.betLocks[uid] == true;
    final guestUid = _room.guestUid;
    final bothAlreadyLocked = selfAlreadyLocked &&
        guestUid != null &&
        _room.betLocks[guestUid] == true &&
        _room.betLocks[_room.hostUid] == true;

    _betLockCheckRunning = true;
    try {
      if (!selfAlreadyLocked) {
        final locked =
            await ArenaBetService.lockOwnBet(room: _room, selfUid: uid);
        if (!locked) {
          if (mounted) {
            final l10n = AppL10n.of(context);
            ArenaToast.error(context, l10n.notEnoughCoinsCreate);
          }
          return;
        }
      }
      // Only the host writes the room-level coinsLocked flag, and only once
      // per room, and only when both bet locks are visible in the snapshot.
      if (_isHost && !_coinsLockMarked && bothAlreadyLocked) {
        final both =
            await ArenaBetService.markRoomCoinsLockedIfBoth(room: _room);
        if (both) {
          _coinsLockMarked = true;
          _betLockDoneForThisRoom = true;
          _lastBetLockRoomCode = _room.roomCode;
          _lastBetLockMatchId = _room.matchId;
        }
      } else if (!_isHost && selfAlreadyLocked) {
        _betLockDoneForThisRoom = true;
        _lastBetLockRoomCode = _room.roomCode;
        _lastBetLockMatchId = _room.matchId;
      }
    } finally {
      _betLockCheckRunning = false;
    }
  }

  void _maybeStartCountdown() {
    if (_room.status == 'countdown' && !_showCountdown) {
      setState(() => _showCountdown = true);
    }
  }

  void _onRoomChange(ArenaRoom? room) {
    if (!mounted) return;
    if (room == null) {
      // Two cases:
      //   1. We never received a snapshot AND we're disconnected → transient
      //      reconnection issue, show the Reconnecting overlay and wait.
      //   2. We had a real snapshot before, and now the node is gone — this
      //      is a legitimate room removal (host deleteRoom / expired). Only
      //      proceed to summary/exit when we know the room actually ended.
      final wasFinished = _room.status == 'finished';
      if (!_isConnected && !wasFinished) {
        // Hold position until we reconnect.
        return;
      }
      _handleRoomGone();
      return;
    }
    setState(() => _room = room);
    _maybeStartCountdown();
    if ((room.status == 'countdown' || room.status == 'playing') &&
        !_betLockDoneForThisRoom) {
      _maybeLockBet();
    }
    if (room.status == 'playing') {
      _evaluateBoardIfHost();
    }
    _maybeAnimateRoundWin(room);
    if (room.status == 'finished' && !_summaryWritten) {
      _summaryWritten = true;
      _onRoomFinished();
    }
  }

  /// Detect a fresh round-end and pulse the winning cells locally for ~900ms,
  /// then surface a compact ROUND WON/LOST/DRAW banner for ~1.4s. Driven
  /// purely off the latest RTDB snapshot — both clients compute the same
  /// line from the same `board` + `roundWinnerUid`. Keyed on
  /// `currentRoundIndex|winnerUid` so a repeated snapshot doesn't retrigger.
  void _maybeAnimateRoundWin(ArenaRoom room) {
    final winnerUid = room.roundWinnerUid;
    if (winnerUid == null || winnerUid.isEmpty) return;
    // Don't double-animate when the match is finished — the final-result
    // dialog handles that visual beat.
    if (room.status == 'finished') return;
    final key = '${room.currentRoundIndex}|$winnerUid';
    if (_lastAnimatedRoundKey == key) return;
    _lastAnimatedRoundKey = key;
    final symbol = room.symbolFor(winnerUid);
    if (symbol.isEmpty) return;
    final line = _computeWinningLine(room.board, room.currentBoardSize, symbol);
    if (line.isNotEmpty) {
      setState(() => _winningCells = line.toSet());
    }
    // Queue the banner to show right after the cell-glow window.
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_lastAnimatedRoundKey != key) return;
      setState(() {
        _winningCells = const <int>{};
        _roundEndBanner = _RoundEndBanner(
          isSelfWinner: _uid != null && winnerUid == _uid,
        );
      });
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        if (_lastAnimatedRoundKey != key) return;
        setState(() => _roundEndBanner = null);
      });
    });
  }

  List<int> _computeWinningLine(
      List<String> board, int boardSize, String symbol) {
    if (board.isEmpty) return const <int>[];
    final cfg = standardBoardConfig(boardSize);
    final lines =
        generateWinningLines(boardSize: boardSize, winLength: cfg.winLength);
    for (final line in lines) {
      if (line.any((i) => i < 0 || i >= board.length)) continue;
      if (line.every((i) => board[i] == symbol)) {
        return line;
      }
    }
    return const <int>[];
  }

  Future<void> _copyRoomCode(AppL10n l10n) async {
    await Clipboard.setData(ClipboardData(text: _room.roomCode));
    if (!mounted) return;
    ArenaToast.success(context, l10n.codeCopied);
  }

  void _handleRoomGone() {
    if (!_summaryWritten) {
      _summaryWritten = true;
      // Save a tiny "cancelled/expired" summary so user_logs/audit reflect it.
      ArenaMatchSummary.writeForRoom(room: _room, coinsWon: 0);
    }
    _exitToArena();
  }

  Future<void> _exitToArena() async {
    if (_hasExitedRoom) {
      if (kDebugMode) {
        debugPrint('[ARENA] exit ignored — already exited room=${_room.roomCode}');
      }
      return;
    }
    _hasExitedRoom = true;
    if (kDebugMode) {
      debugPrint('[ARENA] exit room once room=${_room.roomCode}');
    }
    await _sub?.cancel();
    _sub = null;
    final uid = _uid;
    if (uid != null) {
      try {
        await ArenaRepo.instance.clearActiveRoomMirror(uid);
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _connSub?.cancel();
    // Keep the cleanup Timer alive past dispose so the host's room removal
    // still fires even after they leave the screen — it's intentionally not
    // cancelled here. If you want eager teardown, call cleanupTimer cancel
    // from a deliberate path (e.g. host taps Leave) before dispose runs.
    super.dispose();
  }

  // ── Move handling ─────────────────────────────────────────────────────

  Future<void> _onCellTap(int idx) async {
    if (_movePending) return;
    if (_room.status != 'playing') return;
    if (_uid == null || _room.turnUid != _uid) return;
    if (idx < 0 || idx >= _room.board.length) return;
    if (_room.board[idx].isNotEmpty) return;
    _movePending = true;
    try {
      await ArenaRepo.instance
          .submitMove(code: _room.roomCode, uid: _uid!, cellIndex: idx);
    } finally {
      _movePending = false;
    }
  }

  // ── Win/draw detection (host writes the round outcome) ────────────────

  void _evaluateBoardIfHost() {
    if (!_isHost || _roundResolving) return;
    if (_room.status != 'playing') return;
    final boardSize = _room.currentBoardSize;
    final cfg = standardBoardConfig(boardSize);
    final lines =
        generateWinningLines(boardSize: boardSize, winLength: cfg.winLength);
    final board = _room.board;
    String? winnerSymbol;
    for (final line in lines) {
      if (line.any((i) => i >= board.length)) continue;
      final first = board[line[0]];
      if (first.isEmpty) continue;
      if (line.every((i) => board[i] == first)) {
        winnerSymbol = first;
        break;
      }
    }
    final boardFull = board.every((c) => c.isNotEmpty);
    if (winnerSymbol == null && !boardFull) return;
    // Guard against duplicate-evaluation when host re-receives the same snap.
    if (_lastResolvedRound == _room.currentRound) return;
    _roundResolving = true;
    _lastResolvedRound = _room.currentRound;
    _resolveRound(winnerSymbol);
  }

  Future<void> _resolveRound(String? winnerSymbol) async {
    final winnerUid = winnerSymbol == null
        ? null
        : (winnerSymbol == 'X' ? _room.xUid : _room.oUid);
    int scoreHost = _room.scoreHost;
    int scoreGuest = _room.scoreGuest;
    if (winnerUid != null) {
      if (winnerUid == _room.hostUid) {
        scoreHost++;
      } else {
        scoreGuest++;
      }
    }
    final isLastRound = _room.currentRound >= _room.roundsCount;
    final isDraw = winnerUid == null;

    if (!isDraw && isLastRound) {
      // Determine room winner — tie ⇒ extra round.
      if (scoreHost == scoreGuest) {
        await ArenaRepo.instance.applyRoundResult(
          code: _room.roomCode,
          currentRound: _room.currentRound,
          currentRoundIndex: _room.currentRoundIndex,
          roundsCount: _room.roundsCount,
          roundMaps: _room.roundMaps,
          scoreHost: scoreHost,
          scoreGuest: scoreGuest,
          roundWinnerUid: winnerUid,
        );
        _roundResolving = false;
        return;
      }
      final roomWinner =
          scoreHost > scoreGuest ? _room.hostUid : (_room.guestUid ?? '');
      // Atomic finish: write the final round score AND the match-finished
      // status in a single RTDB update so the guest cannot observe an
      // intermediate "empty board + status=playing" snapshot. Preserves the
      // winning line on screen so the round-end animation can highlight it.
      await ArenaRepo.instance.finishMatchAtomic(
        code: _room.roomCode,
        currentRound: _room.currentRound,
        currentRoundIndex: _room.currentRoundIndex,
        scoreHost: scoreHost,
        scoreGuest: scoreGuest,
        roundWinnerUid: winnerUid,
        roomWinnerUid: roomWinner.isEmpty ? null : roomWinner,
        result: 'completed',
        finalResult: 'completed',
      );
    } else {
      await ArenaRepo.instance.applyRoundResult(
        code: _room.roomCode,
        currentRound: _room.currentRound,
        currentRoundIndex: _room.currentRoundIndex,
        roundsCount: _room.roundsCount,
        roundMaps: _room.roundMaps,
        scoreHost: scoreHost,
        scoreGuest: scoreGuest,
        roundWinnerUid: winnerUid,
      );
    }
    _roundResolving = false;
  }

  Future<void> _onRoomFinished() async {
    final selfUid = _uid;
    if (selfUid == null) return;
    int coinsWon = 0;
    final isLiveWinner = _room.roomWinnerUid != null
        && _room.roomWinnerUid!.isNotEmpty
        && _room.roomWinnerUid == selfUid;
    if (_room.betEnabled &&
        AppConfig.kEnableFriendRoomBetting &&
        isLiveWinner) {
      final credited =
          await ArenaBetService.creditPrize(room: _room, selfUid: selfUid);
      if (credited) coinsWon = _room.prizePool;
    } else if (kDebugMode &&
        _room.betEnabled &&
        AppConfig.kEnableFriendRoomBetting) {
      debugPrint('[ARENA_BET] payout check skipped room=${_room.roomCode} '
          'self=$selfUid winner=${_room.roomWinnerUid}');
    }
    // Stash for the final-result dialog so it can render the gold "+coins"
    // line iff a credit actually happened.
    _finalCoinsWon = coinsWon;
    // Write summary (idempotent via matchId), user_logs, audit_logs.
    await ArenaMatchSummary.writeForRoom(room: _room, coinsWon: coinsWon);
    final opponentUid = _room.opponentOf(selfUid);
    final opponentName = (selfUid == _room.hostUid)
        ? (_room.guestName ?? '')
        : _room.hostName;
    await ArenaMatchSummary.writeUserLogs(
      room: _room,
      uid: selfUid,
      opponentUid: opponentUid,
      opponentName: opponentName,
      coinsWon: coinsWon,
    );
    // Host: instead of deleting immediately (which can race the guest's
    // listener), publish a cleanupAfter timestamp and schedule the actual
    // RTDB removal after a 25-second grace window. The guest sees the
    // final state, then the node disappears.
    if (_isHost) {
      final code = _room.roomCode;
      await ArenaRepo.instance.setCleanupAfter(code);
      _cleanupTimer?.cancel();
      _cleanupTimer = Timer(const Duration(seconds: 25), () {
        ArenaRepo.instance.deleteRoom(code);
      });
    }
    await _showEndDialog();
  }

  Future<void> _showEndDialog() async {
    if (!mounted) return;
    final l10n = AppL10n.of(context);
    final selfUid = _uid;
    final win = selfUid != null
        && _room.roomWinnerUid != null
        && _room.roomWinnerUid == selfUid;
    final draw = _room.roomWinnerUid == null
        || _room.roomWinnerUid!.isEmpty;
    final forfeit = _room.result == 'forfeit';
    final accent = win
        ? AppPalette.success
        : draw
            ? AppPalette.primary
            : AppPalette.danger;
    final title = win
        ? l10n.youWon.toUpperCase()
        : draw
            ? l10n.drawShort
            : l10n.youLost.toUpperCase();
    final body = forfeit
        ? (win ? l10n.opponentLeftYouWin : l10n.leaveCountsAsLoss)
        : l10n.roomFinished;
    // Only display "+coins" when the wallet was actually credited — this
    // matches the live RTDB transaction outcome from creditPrize and never
    // shows a phantom prize on a blocked payout.
    final showPrize = win && _finalCoinsWon > 0;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              colors: [
                AppPalette.panel.withValues(alpha: 0.96),
                AppPalette.panelDeep.withValues(alpha: 0.98),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(color: accent, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                win
                    ? Icons.emoji_events_rounded
                    : draw
                        ? Icons.handshake_rounded
                        : Icons.shield_moon_rounded,
                color: accent,
                size: 44,
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    fontFamily: 'Orbitron',
                    shadows: [
                      Shadow(
                        color: accent.withValues(alpha: 0.55),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppPalette.text.withValues(alpha: 0.82),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (showPrize) ...[
                const SizedBox(height: 14),
                _PrizeWonBadge(
                  coins: _finalCoinsWon,
                  label: l10n.coinsWonBadge(_finalCoinsWon),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _exitToArena();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        AppPalette.primary.withValues(alpha: 0.16),
                    foregroundColor: AppPalette.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(
                          color: AppPalette.primary, width: 1.3),
                    ),
                  ),
                  child: Text(
                    l10n.backToArena,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Leave handling ────────────────────────────────────────────────────

  Future<void> _confirmLeave() async {
    if (_isLeaving || _hasExitedRoom) {
      if (kDebugMode) {
        debugPrint('[ARENA] confirmLeave ignored '
            'isLeaving=$_isLeaving hasExited=$_hasExitedRoom');
      }
      return;
    }
    final beforePlay = _room.isWaiting || _room.isReady || _room.isCountdown;
    final hasBet = _room.betEnabled &&
        AppConfig.kEnableFriendRoomBetting &&
        _room.coinsLocked;
    final ok = await showArenaLeaveDialog(
      context,
      beforePlay: beforePlay,
      hasBet: hasBet,
    );
    if (ok) await _doLeave();
  }

  Future<void> _doLeave() async {
    final uid = _uid;
    if (uid == null) return;
    if (_isLeaving || _hasExitedRoom) {
      if (kDebugMode) {
        debugPrint('[ARENA] leave ignored '
            'isLeaving=$_isLeaving hasExited=$_hasExitedRoom');
      }
      return;
    }
    _isLeaving = true;
    if (kDebugMode) {
      debugPrint('[ARENA] leave requested room=${_room.roomCode} uid=$uid');
    }
    try {
      await ArenaRepo.instance
          .leaveRoom(room: _room, leaverUid: uid)
          .timeout(const Duration(seconds: 6));
      if (kDebugMode) {
        debugPrint('[ARENA] leave success, exiting room=${_room.roomCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ARENA] leave failed but exiting locally: $e');
      }
    }
    // _exitToArena handles subscription cancel + mirror clear + single pop.
    await _exitToArena();
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackground(
          variant: AppBackgroundVariant.homeNeon,
          child: SafeArea(
            // Force LTR for the entire gameplay UI so Arabic locale never
            // mirrors the board, score bar (host/guest), or round numbering.
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
              children: [
                _buildScaffold(context),
                if (_showCountdown && _room.status == 'countdown')
                  Positioned.fill(
                    child: CountdownOverlay(
                      onComplete: () async {
                        if (_isHost) {
                          await ArenaRepo.instance
                              .startPlaying(code: _room.roomCode);
                        }
                        if (mounted) {
                          setState(() => _showCountdown = false);
                        }
                      },
                    ),
                  ),
                if (!_isConnected &&
                    _everConnected &&
                    _room.status != 'finished')
                  const Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: _ReconnectingBanner(),
                  ),
                if (_roundEndBanner != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: true,
                      child: Center(
                        child: _RoundEndBannerView(banner: _roundEndBanner!),
                      ),
                    ),
                  ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final l10n = AppL10n.of(context);
    final isMyTurn = _uid != null && _uid == _room.turnUid;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          child: AppGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            borderColor: AppPalette.homeStroke.withValues(alpha: 0.55),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Tooltip(
                  message: l10n.leaveBtn,
                  child: AppIconButton(
                    icon: Icons.arrow_back,
                    onTap: _confirmLeave,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        l10n.roundWord,
                        style: TextStyle(
                          color: AppPalette.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${_room.currentRound} / ${_room.roundsCount}',
                          style: TextStyle(
                            color: AppPalette.text,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Orbitron',
                            letterSpacing: 2,
                            shadows: [
                              Shadow(
                                color:
                                    AppPalette.primary.withValues(alpha: 0.55),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _copyRoomCode(l10n),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${l10n.roomLabel} ${_room.roomCode}',
                                style: TextStyle(
                                  color:
                                      AppPalette.text.withValues(alpha: 0.72),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.copy_rounded,
                                size: 13,
                                color: AppPalette.text.withValues(alpha: 0.55),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Balance back-button width on the right so center column is
                // visually centered relative to the screen.
                const SizedBox(width: 40),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        _buildScoreBar(),
        const SizedBox(height: 4),
        // Compact turn hint — the active player's card already glows green,
        // this is just a textual reinforcement during the playing phase.
        if (_room.status == 'playing')
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Text(
              isMyTurn ? l10n.yourTurn : l10n.opponentTurn,
              style: TextStyle(
                color: isMyTurn ? AppPalette.success : AppPalette.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
            ),
          ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildBoard(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreBar() {
    final hostSym = _room.symbolFor(_room.hostUid);
    final guestSym =
        _room.guestUid == null ? '' : _room.symbolFor(_room.guestUid ?? '');
    final turnUid = _room.turnUid;
    final hostActive =
        _room.status == 'playing' && turnUid != null && turnUid == _room.hostUid;
    final guestActive = _room.status == 'playing' &&
        turnUid != null &&
        _room.guestUid != null &&
        turnUid == _room.guestUid;

    Widget hostCard;
    if (_room.hostUid == _uid) {
      hostCard = ArenaPlayerCard.self(
        symbol: hostSym,
        name: _room.hostName,
        score: _room.scoreHost,
        isActiveTurn: hostActive,
        avatar: _avatarFor(_room.hostUid),
        xSkin: _skinFor(_room.hostUid, 'X'),
        oSkin: _skinFor(_room.hostUid, 'O'),
      );
    } else {
      hostCard = ArenaPlayerCard.opponent(
        symbol: hostSym,
        name: _room.hostName,
        score: _room.scoreHost,
        isActiveTurn: hostActive,
        avatar: _avatarFor(_room.hostUid),
        photoUrl: _photoFor(_room.hostUid),
        xSkin: _skinFor(_room.hostUid, 'X'),
        oSkin: _skinFor(_room.hostUid, 'O'),
      );
    }

    Widget guestCard;
    final guestUid = _room.guestUid;
    final guestName = _room.guestName ?? '—';
    if (guestUid != null && guestUid == _uid) {
      guestCard = ArenaPlayerCard.self(
        symbol: guestSym,
        name: guestName,
        score: _room.scoreGuest,
        isActiveTurn: guestActive,
        avatar: _avatarFor(guestUid),
        xSkin: _skinFor(guestUid, 'X'),
        oSkin: _skinFor(guestUid, 'O'),
      );
    } else {
      guestCard = ArenaPlayerCard.opponent(
        symbol: guestSym,
        name: guestName,
        score: _room.scoreGuest,
        isActiveTurn: guestActive,
        avatar: _avatarFor(guestUid),
        photoUrl: _photoFor(guestUid),
        xSkin: _skinFor(guestUid, 'X'),
        oSkin: _skinFor(guestUid, 'O'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: hostCard),
          const SizedBox(width: 12),
          Expanded(child: guestCard),
        ],
      ),
    );
  }

  Widget _buildBoard(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final maxW = c.maxWidth;
        final maxH = c.maxHeight;
        final size = matchBoardViewportSizeForBounds(
          boardSize: _room.currentBoardSize,
          maxWidth: maxW,
          maxHeight: maxH,
        );
        // X owner equipped skin (rendered for any cell containing "X") and
        // O owner equipped skin (rendered for any cell containing "O").
        // Each symbol uses whichever player owns that mark on the board.
        final xSkin = _skinFor(_room.xUid, 'X');
        final oSkin = _skinFor(_room.oUid, 'O');
        return SizedBox(
          width: size,
          height: size,
          child: _BoardGrid(
            board: _room.board,
            boardSize: _room.currentBoardSize,
            onTap: _onCellTap,
            interactive: _room.status == 'playing' && _room.turnUid == _uid,
            xSkin: xSkin,
            oSkin: oSkin,
            winningCells: _winningCells,
          ),
        );
      },
    );
  }
}

class _BoardGrid extends StatelessWidget {
  final List<String> board;
  final int boardSize;
  final void Function(int index) onTap;
  final bool interactive;
  final String xSkin;
  final String oSkin;

  /// Cells that should pulse a green win-glow (transient, set after a
  /// round resolves and cleared after the highlight window).
  final Set<int> winningCells;

  const _BoardGrid({
    required this.board,
    required this.boardSize,
    required this.onTap,
    required this.interactive,
    required this.xSkin,
    required this.oSkin,
    required this.winningCells,
  });

  @override
  Widget build(BuildContext context) {
    final padding = matchBoardPadding(boardSize);
    final spacing = matchBoardSpacing(boardSize);
    final cellRadius = matchBoardCellRadius(boardSize);
    final cellCount = boardSize * boardSize;
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppPalette.panel,
        borderRadius: BorderRadius.circular(cellRadius + 6),
        border: Border.all(
          color: AppPalette.primary.withValues(alpha: 0.7),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.28),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cellCount,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: boardSize,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
        ),
        itemBuilder: (ctx, i) {
          final v = i < board.length ? board[i] : '';
          final empty = v.isEmpty;
          final isWinning = winningCells.contains(i);
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(cellRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(cellRadius),
              onTap: empty && interactive ? () => onTap(i) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isWinning
                      ? AppPalette.success.withValues(alpha: 0.22)
                      : AppPalette.panelDeep,
                  borderRadius: BorderRadius.circular(cellRadius),
                  border: Border.all(
                    color: isWinning
                        ? AppPalette.success
                        : AppPalette.strokeSoft,
                    width: isWinning ? 2.2 : 1,
                  ),
                  boxShadow: isWinning
                      ? [
                          BoxShadow(
                            color:
                                AppPalette.success.withValues(alpha: 0.55),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: empty
                    ? const SizedBox.shrink()
                    : CellContent(
                        v: v,
                        xColor: AppPalette.danger,
                        oColor: AppPalette.accentBlue,
                        boardSize: boardSize,
                        xSkin: xSkin,
                        oSkin: oSkin,
                      ),
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}

class _ReconnectingBanner extends StatelessWidget {
  const _ReconnectingBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return IgnorePointer(
      ignoring: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppPalette.panel.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppPalette.gold.withValues(alpha: 0.6),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppPalette.gold.withValues(alpha: 0.25),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppPalette.gold,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.reconnectingShort,
              style: const TextStyle(
                color: AppPalette.text,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundEndBanner {
  final bool isSelfWinner;
  const _RoundEndBanner({required this.isSelfWinner});
}

class _RoundEndBannerView extends StatelessWidget {
  final _RoundEndBanner banner;
  const _RoundEndBannerView({required this.banner});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final color =
        banner.isSelfWinner ? AppPalette.success : AppPalette.danger;
    final label =
        banner.isSelfWinner ? l10n.roundWonBanner : l10n.roundLostBanner;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            AppPalette.panel.withValues(alpha: 0.94),
            AppPalette.panelDeep.withValues(alpha: 0.96),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: color, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFamily: 'Orbitron',
            letterSpacing: 3,
            shadows: [
              Shadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrizeWonBadge extends StatelessWidget {
  final int coins;
  final String label;
  const _PrizeWonBadge({required this.coins, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C4212), Color(0xFF1A1320)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.gold, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppPalette.gold.withValues(alpha: 0.4),
            blurRadius: 22,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/coin/COIN.png',
            width: 22,
            height: 22,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.monetization_on_rounded,
              color: AppPalette.gold,
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppPalette.gold,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: 0.8,
              fontFamily: 'Orbitron',
            ),
          ),
        ],
      ),
    );
  }
}
