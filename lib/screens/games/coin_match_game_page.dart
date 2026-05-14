import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../core/keys.dart';
import '../../services/app_mode_service.dart';
import '../../services/audit_service.dart';
import '../../services/auth_service.dart';
import '../../services/game_reward_service.dart';
import '../../services/local_store.dart';
import '../../services/offline_wallet_service.dart';
import '../../services/sound_service.dart';
import '../../utils/ai_engine.dart';
import '../../utils/board_utils.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/connection_lost_match_overlay.dart';
import 'game_page.dart';
import 'game_widgets.dart';

class CoinMatchGamePage extends StatefulWidget {
  final PlayerSymbol playerSymbol;
  final int entryFee;
  final int boardSize;
  final int winCondition;

  const CoinMatchGamePage({
    super.key,
    required this.playerSymbol,
    required this.entryFee,
    this.boardSize = 3,
    this.winCondition = 3,
  });

  @override
  State<CoinMatchGamePage> createState() => _CoinMatchGamePageState();
}

class _CoinMatchGamePageState extends State<CoinMatchGamePage> {
  late final MatchBoardConfig _boardConfig;
  late final List<List<int>> _winningLines;
  late List<String> board;
  bool gameOver = false;
  String currentTurn = "X";
  String winner = "";
  List<int> winningLine = [];
  bool isAIMoving = false;
  late final String playerChar;
  late final String aiChar;
  Color _xPiece = const Color(0xFFFF3B30);
  Color _oPiece = const Color(0xFF0A84FF);
  String _xSkin = 'default';
  String _oSkin = 'default';
  bool _musicDucked = false;

  /// Prevents double-execution of match result logic.
  /// Set to true the moment [_handleResult] starts; reset on [_resetGame].
  bool _isResolvingResult = false;

  /// Prevents the win/draw reward from being credited more than once for
  /// the current matchId.
  bool _rewardApplied = false;

  /// Prevents double stake deduction. Set the first time [_deductEntryFee]
  /// succeeds and reset by [_resetGame] so a continue/replay starts fresh.
  bool _stakeDeducted = false;

  /// Set when an online match's initialization was cancelled mid-flight by
  /// a connectivity / mode change (e.g. AppMode flipped to
  /// connectionLostDuringOnlineMatch during the SharedPreferences write).
  /// Used by [_handleResult] to refuse to compute a reward for a match
  /// that should never have been allowed to start.
  bool _matchInitCancelled = false;

  /// Captured at [initState] time; true when match started while offline.
  /// Used throughout to route wallet ops and result handling correctly.
  late final bool _isOfflineMatch;

  /// Stable matchId — created in [initState] and refreshed by [_resetGame]
  /// so that continue/replay starts a fresh row in `match_rewards`.
  late String _matchId;

  String _newMatchId() =>
      'cm_${DateTime.now().millisecondsSinceEpoch}_${LocalStore.uid ?? 'guest'}';

  @override
  void initState() {
    super.initState();
    _boardConfig = MatchBoardConfig(
      boardSize: widget.boardSize,
      winLength: widget.winCondition,
    );
    _winningLines = generateWinningLines(
      boardSize: _boardConfig.boardSize,
      winLength: _boardConfig.winLength,
    );
    board = List.filled(_boardConfig.cellCount, "");
    playerChar = widget.playerSymbol == PlayerSymbol.x ? "X" : "O";
    aiChar = playerChar == "X" ? "O" : "X";

    _isOfflineMatch = AppModeService.isOfflineLike;
    _matchId = _newMatchId();
    if (!_isOfflineMatch) {
      // Mark that an online match is active so HomeHub won't auto-switch offline.
      LocalStore.isInOnlineMatch.value = true;
      if (kDebugMode) {
        debugPrint('[MATCH] online match started, isInOnlineMatch=true');
        debugPrint('[COIN_MATCH] matchId=$_matchId stake accepted=${widget.entryFee}');
      }
    } else {
      if (kDebugMode) {
        debugPrint('[COIN_MATCH] offline match started — isInOnlineMatch not set');
        debugPrint('[COIN_MATCH] matchId=$_matchId stake accepted=${widget.entryFee}');
      }
    }

    AuditService.log('match_started',
        {'matchType': 'coin_match', 'entryFee': widget.entryFee});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeMatch();
    });
  }

  Future<void> _initializeMatch() async {
    await Future.wait<void>([
      _duckGameplayMusic(),
      _deductEntryFee(),
      _loadMeta(),
    ]);
    if (!mounted) return;

    if (playerChar == "O") {
      _aiMove();
    }
  }

  Future<void> _duckGameplayMusic() async {
    if (_musicDucked) return;
    _musicDucked = true;
    await SoundService().duckMusic();
  }

  Future<void> _restoreGameplayMusic() async {
    if (!_musicDucked) return;
    _musicDucked = false;
    await SoundService().restoreMusic();
  }

  void _leaveMatch() {
    unawaited(_restoreGameplayMusic());
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    // Clear online match flag when leaving (only relevant for online matches).
    if (!_isOfflineMatch) {
      LocalStore.isInOnlineMatch.value = false;
      if (kDebugMode) debugPrint('[MATCH] online match ended, isInOnlineMatch=false');
    }
    unawaited(_restoreGameplayMusic());
    super.dispose();
  }

  // ── Overlay callbacks ────────────────────────────────────────────────────

  /// Called when user taps "Restart in Offline Mode" on the disconnect overlay.
  /// Delegates to [LocalStore.restartIntoOfflineMode] — the single entry point
  /// for zero-merge offline transitions. No result, no reward, no Firestore write.
  Future<void> _onRestartOffline() async {
    if (kDebugMode) debugPrint('[OFFLINE] user tapped Restart in Offline Mode');
    await LocalStore.restartIntoOfflineMode();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// Called when user taps "Wait for Connection" — the overlay listener handles auto-dismiss.
  void _onWaitForConnection() {
    // The _ConnectionLostMatchOverlayState listener handles reconnection.
    // When AppMode returns to online, it will call this callback to pop back.
    if (kDebugMode) debugPrint('[RECONNECT] user chose wait for connection');
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// Called when user taps "Exit to Home" on the disconnect overlay.
  void _onExitHome() {
    if (kDebugMode) debugPrint('[MATCH] user chose exit to home from disconnect overlay');
    LocalStore.isInOnlineMatch.value = false;
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _deductEntryFee() async {
    // Idempotency: refuse to deduct twice in the same match. _resetGame
    // clears this flag so continue/replay starts a fresh deduction.
    if (_stakeDeducted) {
      if (kDebugMode) {
        debugPrint('[COIN_MATCH] matchId=$_matchId duplicate stake blocked');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('[COIN_MATCH] matchId=$_matchId stake deduction requested');
    }

    // ── Offline match: deduct from offline wallet (never Firestore) ────────
    if (_isOfflineMatch) {
      final before = LocalStore.coinsNotifier.value;
      await OfflineWalletService().deduct(
        widget.entryFee,
        coinsNotifier: LocalStore.coinsNotifier,
      );
      final after = LocalStore.coinsNotifier.value;
      _stakeDeducted = true;
      if (kDebugMode) {
        debugPrint(
          '[COIN_MATCH] matchId=$_matchId mode=offline stake deduction success '
          'before=$before newCoins=$after',
        );
        debugPrint('[WALLET] mode=offline delta=-${widget.entryFee} before=$before after=$after');
      }
      return;
    }

    // ── Online match: hardened against mid-init connection loss ────────────
    // Pre-check: must be stably online before we even start the deduction.
    if (!AppModeService.canUseOnlineServices) {
      _matchInitCancelled = true;
      if (kDebugMode) {
        debugPrint(
          '[COIN_MATCH] matchId=$_matchId stake deduction blocked because '
          'mode=${AppModeService.current}',
        );
      }
      return;
    }

    final before = LocalStore.coinsNotifier.value;
    await LocalStore.updateCoins(-widget.entryFee);

    // Post-check: AppMode can flip during the SharedPreferences write (e.g.
    // a connection-loss event fires between the pre-check and the prefs
    // commit). If that happened, the inner [LocalStore.updateCoins] guard
    // *may* have allowed the write through if it was already past its own
    // mode check. Either way, the match should NOT proceed to result/reward
    // logic — the user has not actually played an online match.
    if (!AppModeService.canUseOnlineServices) {
      _matchInitCancelled = true;
      if (kDebugMode) {
        debugPrint(
          '[COIN_MATCH] matchId=$_matchId stake deduction cancelled because '
          'connection changed during init (mode=${AppModeService.current})',
        );
      }
      return;
    }

    final after = LocalStore.coinsNotifier.value;
    _stakeDeducted = true;
    if (kDebugMode) {
      debugPrint(
        '[COIN_MATCH] matchId=$_matchId mode=online stake deduction success '
        'before=$before newCoins=$after',
      );
      debugPrint('[WALLET] mode=online delta=-${widget.entryFee} before=$before after=$after');
    }
    await LocalStore.addTopupHistory(
        usd: 0.0,
        coins: widget.entryFee,
        type: 'loss',
        description: 'Game Entry',
        balanceBefore: before,
        balanceAfter: before - widget.entryFee);
  }

  Future<void> _loadMeta() async {
    final p = await SharedPreferences.getInstance();
    final xSkin = p.getString(Keys.selectedXSkin) ?? 'default';
    final oSkin = p.getString(Keys.selectedOSkin) ?? 'default';
    if (!mounted) return;
    setState(() {
      _xPiece = const Color(0xFFFF3B30);
      _oPiece = const Color(0xFF0A84FF);
      _xSkin = xSkin;
      _oSkin = oSkin;
    });
  }

  void _makeMove(int index) {
    if (gameOver || isAIMoving) return;
    if (board[index].isNotEmpty) return;
    if (currentTurn != playerChar) return;

    setState(() => board[index] = currentTurn);
    _checkGameState();
    if (gameOver) return;

    setState(() => currentTurn = currentTurn == "X" ? "O" : "X");
    if (currentTurn == aiChar) {
      if (_winningMoveFor(aiChar) != -1) {
        showTopNotification(
          context,
          "Block! AI can win next move.",
          color: AppPalette.danger,
        );
      }
      _aiMove();
    }
  }

  void _checkGameState() {
    for (final line in _winningLines) {
      final first = board[line[0]];
      if (first.isEmpty) {
        continue;
      }

      final allMatch = line.every((index) => board[index] == first);
      if (allMatch) {
        setState(() {
          gameOver = true;
          winner = first;
          winningLine = line;
        });
        _handleResult();
        return;
      }
    }

    if (!board.any((cell) => cell.isEmpty)) {
      setState(() => gameOver = true);
      _handleResult(draw: true);
    }
  }

  Future<void> _handleResult({bool draw = false}) async {
    // Guard 1: prevent double-result (e.g., called by both makeMove and aiMove).
    if (_isResolvingResult) {
      if (kDebugMode) {
        debugPrint('[COIN_MATCH] matchId=$_matchId duplicate result blocked');
      }
      return;
    }
    _isResolvingResult = true;

    // Guard 1b: the match was abandoned during init (connection dropped
    // before/while the stake was being deducted). Refuse to compute any
    // reward; the connection-lost overlay handles user-visible recovery.
    if (_matchInitCancelled) {
      if (kDebugMode) {
        debugPrint('[COIN_MATCH] matchId=$_matchId result blocked — init was cancelled');
      }
      return;
    }

    // Guard 2a: offline match — resolve result via offline wallet and return.
    if (_isOfflineMatch) {
      await _restoreGameplayMusic();
      final resultStr = draw ? 'draw' : (winner == playerChar ? 'win' : 'loss');
      final coinsToAdd = GameRewardService.rewardForCoinMatch(
        stake: widget.entryFee,
        result: resultStr,
      );
      if (kDebugMode) {
        debugPrint(
          '[GAME_REWARD] gameType=coin_match matchId=$_matchId mode=offline '
          'stake=${widget.entryFee} result=$resultStr reward=$coinsToAdd',
        );
      }
      if (coinsToAdd > 0 && !_rewardApplied) {
        final before = LocalStore.coinsNotifier.value;
        await OfflineWalletService().credit(coinsToAdd, coinsNotifier: LocalStore.coinsNotifier);
        final after = LocalStore.coinsNotifier.value;
        _rewardApplied = true;
        if (kDebugMode) {
          debugPrint(
            '[COIN_MATCH] matchId=$_matchId mode=offline reward credited '
            'delta=$coinsToAdd before=$before newCoins=$after',
          );
          debugPrint('[WALLET] mode=offline delta=$coinsToAdd before=$before after=$after');
        }
      } else if (coinsToAdd > 0 && _rewardApplied) {
        if (kDebugMode) {
          debugPrint('[COIN_MATCH] matchId=$_matchId duplicate reward blocked');
        }
      }
      if (!mounted) {
        _isResolvingResult = false;
        return;
      }
      final l10nOffline = AppL10n.of(context);
      if (draw) {
        _showEndDialog(
          title: l10nOffline.drawResult,
          subtitle: "Nobody drops this round.",
          icon: Icons.handshake,
          coinsAdded: coinsToAdd,
          rewardText: coinsToAdd > 0 ? l10nOffline.addedCoins(coinsToAdd) : null,
        );
      } else if (winner == playerChar) {
        _showEndDialog(
          title: l10nOffline.youWin,
          subtitle: "High-stakes arena cleared.",
          icon: Icons.emoji_events_outlined,
          coinsAdded: coinsToAdd,
          rewardText: l10nOffline.addedCoins(coinsToAdd),
        );
      } else {
        _showEndDialog(
          title: l10nOffline.youLost,
          subtitle: "The AI claimed this pot.",
          icon: Icons.sentiment_dissatisfied_outlined,
        );
      }
      AuditService.log('match_ended', {
        'matchType': 'coin_match_offline',
        'entryFee': widget.entryFee,
        'result': resultStr,
      });
      unawaited(LocalStore.addResult(result: resultStr));
      return;
    }

    // Guard 2b: never process result if connection was lost during this online match.
    if (AppModeService.isOfflineLike) {
      if (kDebugMode) {
        debugPrint('[MATCH] no result calculated while offline');
        debugPrint('[MATCH] no Firestore write while offline');
      }
      _isResolvingResult = false;
      return;
    }

    await _restoreGameplayMusic();
    final resultStr = draw ? 'draw' : (winner == playerChar ? 'win' : 'loss');

    final coinsToAdd = GameRewardService.rewardForCoinMatch(
      stake: widget.entryFee,
      result: resultStr,
    );
    if (kDebugMode) {
      debugPrint(
        '[GAME_REWARD] gameType=coin_match matchId=$_matchId mode=online '
        'stake=${widget.entryFee} result=$resultStr reward=$coinsToAdd',
      );
    }

    int? balanceBefore;
    int? balanceAfter;
    if (coinsToAdd > 0 && !_rewardApplied) {
      // Client wallet is the single source of truth. The CF in
      // [_persistCoinMatchResult] is stats-only.
      balanceBefore = LocalStore.coinsNotifier.value;
      await LocalStore.updateCoins(coinsToAdd);
      balanceAfter = LocalStore.coinsNotifier.value;
      _rewardApplied = true;
      if (kDebugMode) {
        debugPrint(
          '[COIN_MATCH] matchId=$_matchId mode=online reward credited '
          'delta=$coinsToAdd before=$balanceBefore newCoins=$balanceAfter',
        );
        debugPrint('[WALLET] mode=online delta=$coinsToAdd before=$balanceBefore after=$balanceAfter');
      }
    } else if (coinsToAdd > 0 && _rewardApplied) {
      if (kDebugMode) {
        debugPrint('[COIN_MATCH] matchId=$_matchId duplicate reward blocked');
      }
    }

    if (!mounted) return;
    final l10n = AppL10n.of(context);
    if (draw) {
      _showEndDialog(
        title: l10n.drawResult,
        subtitle: "Nobody drops this round.",
        icon: Icons.handshake,
        coinsAdded: coinsToAdd,
        rewardText: l10n.addedCoins(coinsToAdd),
      );
    } else if (winner == playerChar) {
      _showEndDialog(
        title: l10n.youWin,
        subtitle: "High-stakes arena cleared.",
        icon: Icons.emoji_events_outlined,
        coinsAdded: coinsToAdd,
        rewardText: l10n.addedCoins(coinsToAdd),
      );
    } else {
      _showEndDialog(
        title: l10n.youLost,
        subtitle: "The AI claimed this pot.",
        icon: Icons.sentiment_dissatisfied_outlined,
      );
    }

    AuditService.log('match_ended', {
      'matchType': 'coin_match',
      'entryFee': widget.entryFee,
      'result': resultStr
    });
    _persistCoinMatchResult(resultStr, coinsToAdd, balanceBefore: balanceBefore, balanceAfter: balanceAfter);
  }

  /// Persist coin match stats in background. The CF is stats-only — the
  /// coin reward has already been credited by [_handleResult].
  Future<void> _persistCoinMatchResult(
    String resultStr,
    int coinsToAdd, {
    int? balanceBefore,
    int? balanceAfter,
  }) async {
    try {
      await LocalStore.addResult(result: resultStr);
      await LocalStore.grantMatchRewardCF(matchId: _matchId, result: resultStr);
      if (coinsToAdd > 0) {
        if (kDebugMode) {
          debugPrint('[REWARD] coin_match stake=${widget.entryFee} reward=$coinsToAdd');
        }
        await LocalStore.addTopupHistory(
          usd: 0.0,
          coins: coinsToAdd,
          type: 'win',
          source: 'coin_match_win',
          description: resultStr == 'draw' ? 'Match Draw Refund' : 'Match Win Reward',
          transactionId: '${_matchId}_win',
          balanceBefore: balanceBefore,
          balanceAfter: balanceAfter,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CoinMatchGamePage] Background persist error: $e');
      }
    }
  }

  void _showEndDialog(
      {required String title,
      required String subtitle,
      required IconData icon,
      int coinsAdded = 0,
      String? rewardText}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EndDialog(
        title: title,
        subtitle: subtitle,
        icon: icon,
        coinsAdded: coinsAdded,
        rewardText: rewardText,
        onRestart: () {
          Navigator.pop(context);
          unawaited(_duckGameplayMusic());
          unawaited(_resetGame());
        },
        onHome: () {
          Navigator.pop(context);
          _leaveMatch();
        },
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 44, color: AppPalette.warning),
                const SizedBox(height: 10),
                Text(
                  AppL10n.of(context).exitCoinBattleTitle,
                  style: safeOrbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppL10n.of(context).leaveCoinMatchBody(widget.entryFee),
                  textAlign: TextAlign.center,
                  style: bodyFont(context).copyWith(height: 1.3),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        label: AppL10n.of(context).stayBtn,
                        fill: Colors.white.withOpacity(0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.pop(context),
                        icon: Icons.close,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: AppL10n.of(context).leaveBtn,
                        fill: AppPalette.danger.withOpacity(0.9),
                        onPressed: () {
                          Navigator.pop(context);
                          _leaveMatch();
                        },
                        icon: Icons.exit_to_app,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resetGame() async {
    if (isAIMoving) return;
    // Can't replay an ONLINE coin match if connection was lost — must be restored first.
    if (!_isOfflineMatch && !AppModeService.canUseOnlineServices) {
      if (kDebugMode) {
        debugPrint('[COIN_MATCH] matchId=$_matchId reset blocked — online match but mode=${AppModeService.current}');
      }
      return;
    }

    final newId = _newMatchId();
    if (kDebugMode) {
      debugPrint('[COIN_MATCH] matchId=$newId reset started (continue same stake)');
    }
    setState(() {
      board = List.filled(_boardConfig.cellCount, "");
      gameOver = false;
      winner = "";
      winningLine = [];
      currentTurn = "X";
      isAIMoving = true; // lock the board until stake deduction completes
      _isResolvingResult = false;
      _rewardApplied = false;
      _stakeDeducted = false;
      _matchInitCancelled = false;
      _matchId = newId;
    });

    if (kDebugMode) {
      debugPrint('[COIN_MATCH] matchId=$_matchId waiting for stake deduction before first move');
    }
    await _deductEntryFee();

    if (!mounted) return;
    if (!_stakeDeducted) {
      // Deduction was blocked / cancelled (e.g. connection dropped). Show
      // the disconnect overlay path — leave gameOver=true so the player
      // cannot tap into a match they never paid for.
      if (kDebugMode) {
        debugPrint('[COIN_MATCH] matchId=$_matchId reset blocked because deduction failed');
      }
      setState(() {
        gameOver = true;
        isAIMoving = false;
      });
      return;
    }

    if (kDebugMode) {
      debugPrint('[COIN_MATCH] matchId=$_matchId match active after deduction success');
    }
    setState(() {
      isAIMoving = false;
    });
    if (playerChar == "O") {
      _aiMove();
    }
  }

  Future<void> _aiMove() async {
    if (isAIMoving || gameOver || !mounted) return;
    setState(() => isAIMoving = true);

    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted || gameOver) {
      if (mounted) setState(() => isAIMoving = false);
      return;
    }

    final best = _findAdaptiveMove();
    if (best != -1) {
      setState(() => board[best] = aiChar);
      _checkGameState();
      if (!gameOver) {
        setState(() => currentTurn = playerChar);
      }
    }

    if (mounted) setState(() => isAIMoving = false);
  }

  int _findAdaptiveMove() {
    return pickStrategicMove(
      board: board,
      winningLines: _winningLines,
      aiPlayer: aiChar,
      humanPlayer: playerChar,
      boardSize: _boardConfig.boardSize,
      winLength: _boardConfig.winLength,
      difficulty: AIDifficulty.hard,
    );
  }

  int _winningMoveFor(String who) {
    for (int i = 0; i < board.length; i++) {
      if (board[i].isEmpty) {
        board[i] = who;
        final ok = _isWinning(who);
        board[i] = "";
        if (ok) return i;
      }
    }
    return -1;
  }

  bool _isWinning(String player) {
    for (final line in _winningLines) {
      if (line.every((index) => board[index] == player)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final boardSpacing = matchBoardSpacing(_boardConfig.boardSize);
    final boardPadding = matchBoardPadding(_boardConfig.boardSize);
    final cellRadius = matchBoardCellRadius(_boardConfig.boardSize);
    final statusColor = gameOver
        ? (winner.isEmpty
            ? AppPalette.goldHighlight
            : (winner == "X" ? _xPiece : _oPiece))
        : AppPalette.text;

    // Wrap with Stack so the disconnect overlay can appear above the full Scaffold.
    return Stack(
      children: [
        _buildGameScaffold(
          context: context,
          l10n: l10n,
          boardSpacing: boardSpacing,
          boardPadding: boardPadding,
          cellRadius: cellRadius,
          statusColor: statusColor,
        ),
        // Connection-lost overlay — shown only when mode == connectionLostDuringOnlineMatch.
        ValueListenableBuilder<AppMode>(
          valueListenable: AppModeService.modeNotifier,
          builder: (ctx, mode, _) {
            if (mode != AppMode.connectionLostDuringOnlineMatch) {
              return const SizedBox.shrink();
            }
            return ConnectionLostMatchOverlay(
              onRestartOffline: _onRestartOffline,
              onWaitForConnection: _onWaitForConnection,
              onExitHome: _onExitHome,
            );
          },
        ),
      ],
    );
  }

  Widget _buildGameScaffold({
    required BuildContext context,
    required AppL10n l10n,
    required double boardSpacing,
    required double boardPadding,
    required double cellRadius,
    required Color statusColor,
  }) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showExitConfirmation();
        }
      },
      child: Scaffold(
        backgroundColor: AppPalette.bgDepth,
        body: SafeArea(
          child: AppBackground(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final landscape = constraints.maxWidth > constraints.maxHeight;
                final buttonHeight = landscape ? 48.0 : 52.0;

                Widget buildHeaderCard() {
                  return AppGlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: LayoutBuilder(
                      builder: (context, headerConstraints) {
                        final stackedHeader = headerConstraints.maxWidth < 360;
                        final coinWidth = clampDouble(
                          headerConstraints.maxWidth * (stackedHeader ? 0.48 : 0.30),
                          stackedHeader ? 118.0 : 132.0,
                          stackedHeader ? 156.0 : 176.0,
                        );
                        final titleWidth = max(
                          0.0,
                          headerConstraints.maxWidth - coinWidth - 66.0,
                        );
                        final coinWidget = SizedBox(
                          width: coinWidth,
                          child: ValueListenableBuilder<int>(
                            valueListenable: LocalStore.coinsNotifier,
                            builder: (_, coins, __) => CoinPill(
                              coins: coins,
                              width: coinWidth,
                            ),
                          ),
                        );

                        final titleBlock = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VS AI • COIN PLAY',
                              style: sectionFont(context),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Entry: ${widget.entryFee} coins',
                              style: bodyFont(context)
                                  .copyWith(color: AppPalette.warning),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_boardConfig.label} • ${_boardConfig.winLength} in a row',
                              style: bodyFont(context).copyWith(
                                color: AppPalette.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );

                        if (stackedHeader) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  AppIconButton(
                                    icon: Icons.arrow_back,
                                    onTap: _showExitConfirmation,
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: max(0.0, headerConstraints.maxWidth - 56.0),
                                    child: Text(
                                      'VS AI • COIN PLAY',
                                      style: sectionFont(context),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              coinWidget,
                              const SizedBox(height: 10),
                              Text(
                                'Entry: ${widget.entryFee} coins',
                                style: bodyFont(context)
                                    .copyWith(color: AppPalette.warning),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_boardConfig.label} • ${_boardConfig.winLength} in a row',
                                style: bodyFont(context).copyWith(
                                  color: AppPalette.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            AppIconButton(
                              icon: Icons.arrow_back,
                              onTap: _showExitConfirmation,
                            ),
                            const SizedBox(width: 12),
                            SizedBox(width: titleWidth, child: titleBlock),
                            const SizedBox(width: 10),
                            coinWidget,
                          ],
                        );
                      },
                    ),
                  );
                }

                Widget buildStatusCard() {
                  return AppGlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    borderColor: statusColor.withValues(alpha: 0.28),
                    child: Center(
                      child: isAIMoving
                          ? Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                Text(
                                  'AI thinking...',
                                  style: bodyFont(context),
                                ),
                              ],
                            )
                          : Text(
                              gameOver
                                  ? (winner.isEmpty ? 'DRAW' : '$winner WINS')
                                  : 'NEXT: $currentTurn',
                              style: safeOrbitron(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: statusColor,
                              ),
                            ),
                    ),
                  );
                }

                Widget buildEntryFeeCard() {
                  return AppGlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    borderColor: AppPalette.gold.withValues(alpha: 0.34),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/coin/COIN.png',
                              width: 26,
                              height: 26,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${widget.entryFee} coins',
                              style: safeOrbitron(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFFFD700),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                Widget buildBoard(BoxConstraints boardConstraints) {
                  final boardViewport = matchBoardViewportSizeForBounds(
                    boardSize: _boardConfig.boardSize,
                    maxWidth: boardConstraints.maxWidth,
                    maxHeight: boardConstraints.maxHeight,
                  );
                  if (boardViewport <= 0) {
                    return const SizedBox.shrink();
                  }

                  return SizedBox(
                    width: boardViewport,
                    height: boardViewport,
                    child: AppGlassCard(
                      padding: EdgeInsets.all(boardPadding),
                      borderColor:
                          AppPalette.strokeStrong.withValues(alpha: 0.55),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppPalette.panelSoft.withValues(alpha: 0.98),
                          AppPalette.panelDeep.withValues(alpha: 0.99),
                        ],
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _boardConfig.boardSize,
                          mainAxisSpacing: boardSpacing,
                          crossAxisSpacing: boardSpacing,
                        ),
                        itemCount: _boardConfig.cellCount,
                        itemBuilder: (context, i) {
                          final isWinning = winningLine.contains(i);
                          final cellAccent = board[i] == 'X' ? _xPiece : _oPiece;
                          return InkWell(
                            onTap: () => _makeMove(i),
                            borderRadius: BorderRadius.circular(cellRadius),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(cellRadius),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isWinning
                                      ? [
                                          cellAccent.withValues(alpha: 0.18),
                                          AppPalette.panelElevated
                                              .withValues(alpha: 0.98),
                                        ]
                                      : [
                                          AppPalette.panelSoft
                                              .withValues(alpha: 0.94),
                                          AppPalette.panelDeep
                                              .withValues(alpha: 0.98),
                                        ],
                                ),
                                border: Border.all(
                                  color: isWinning
                                      ? cellAccent.withValues(alpha: 0.84)
                                      : AppPalette.strokeSoft,
                                  width: isWinning ? 2 : 1,
                                ),
                                boxShadow: isWinning
                                    ? [
                                        BoxShadow(
                                          color: cellAccent.withValues(
                                            alpha: 0.18,
                                          ),
                                          blurRadius: 16,
                                          spreadRadius: -2,
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.16,
                                          ),
                                          blurRadius: 12,
                                          spreadRadius: -5,
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: CellContent(
                                  v: board[i],
                                  xColor: _xPiece,
                                  oColor: _oPiece,
                                  boardSize: _boardConfig.boardSize,
                                  xSkin: _xSkin,
                                  oSkin: _oSkin,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }

                Widget buildFooter() {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: landscape ? 340 : 560,
                    ),
                    child: LayoutBuilder(
                      builder: (context, footerConstraints) {
                        final stackButtons = footerConstraints.maxWidth < 360;
                        if (stackButtons) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppPillButton(
                                label: AppL10n.of(context).restartBtn,
                                minHeight: buttonHeight,
                                fill: Colors.white.withOpacity(0.08),
                                stroke: AppPalette.strokeStrong,
                                onPressed: isAIMoving ? null : _resetGame,
                                icon: Icons.refresh,
                              ),
                              const SizedBox(height: 12),
                              AppPillButton(
                                label: l10n.homeBtn,
                                minHeight: buttonHeight,
                                fill:
                                    AppPalette.goldDeep.withValues(alpha: 0.95),
                                onPressed: _showExitConfirmation,
                                icon: Icons.home_outlined,
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: AppPillButton(
                                label: AppL10n.of(context).restartBtn,
                                minHeight: buttonHeight,
                                fill: Colors.white.withOpacity(0.08),
                                stroke: AppPalette.strokeStrong,
                                onPressed: isAIMoving ? null : _resetGame,
                                icon: Icons.refresh,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppPillButton(
                                label: l10n.homeBtn,
                                minHeight: buttonHeight,
                                fill:
                                    AppPalette.goldDeep.withValues(alpha: 0.95),
                                onPressed: _showExitConfirmation,
                                icon: Icons.home_outlined,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                }

                if (landscape) {
                  return Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 10, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              buildHeaderCard(),
                              const SizedBox(height: 10),
                              buildStatusCard(),
                              const SizedBox(height: 10),
                              buildEntryFeeCard(),
                              const Spacer(),
                              buildFooter(),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 12, 14, 16),
                          child: LayoutBuilder(
                            builder: (context, boardConstraints) {
                              return Center(
                                child: buildBoard(boardConstraints),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                      child: buildHeaderCard(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: buildStatusCard(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      child: buildEntryFeeCard(),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: LayoutBuilder(
                          builder: (context, boardConstraints) {
                            return Center(
                              child: buildBoard(boardConstraints),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: buildFooter(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// ==========================
///   LEVEL GAME SETUP PAGE
/// ==========================
