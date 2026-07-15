import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../core/keys.dart';
import '../../services/app_mode_service.dart';
import '../../services/audit_service.dart';
import '../../services/game_reward_service.dart';
import '../../services/local_store.dart';
import '../../services/mission_service.dart';
import '../../services/sound_service.dart';
import '../../services/wallet_transaction_service.dart';
import '../../utils/ai_engine.dart';
import '../../utils/board_utils.dart';
import '../../widgets/app_ui.dart';
import 'game_widgets.dart';

class GamePage extends StatefulWidget {
  final GameMode mode;
  final AIDifficulty difficulty;
  final PlayerSymbol playerSymbol;
  final int boardSize;
  final int winCondition;

  const GamePage({
    super.key,
    required this.mode,
    required this.difficulty,
    required this.playerSymbol,
    this.boardSize = 3,
    this.winCondition = 3,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final MatchBoardConfig _boardConfig;
  late final List<List<int>> _winningLines;
  late List<String> board;
  bool gameOver = false;

  // turns are always "X" or "O" on the board
  String currentTurn = "X";
  String winner = "";
  List<int> winningLine = [];

  bool isAIMoving = false;
  int aiThinkingTime = 200;

  // player identity for AI mode
  late final String playerChar; // "X" or "O"
  late final String aiChar; // opposite

  Color _xPiece = const Color(0xFFFF3B30);
  Color _oPiece = const Color(0xFF0A84FF);
  String _xSkin = 'default';
  String _oSkin = 'default';
  bool _musicDucked = false;

  /// Stable matchId generated at match start. Regenerated on every reset so
  /// each replay is a fresh row in the server's match_rewards collection.
  late String _matchId;

  /// Prevents duplicate result handling when _checkGameState runs twice
  /// (e.g. player + AI move both completing a line on the same frame).
  bool _isResolvingResult = false;

  /// Prevents the reward from being credited more than once for the same
  /// matchId — survives across the dialog/await boundaries.
  bool _rewardApplied = false;

  String _newMatchId() =>
      'ai_${DateTime.now().millisecondsSinceEpoch}_${LocalStore.uid ?? 'guest'}';

  @override
  void initState() {
    super.initState();

    _matchId = _newMatchId();
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
    if (widget.mode == GameMode.friend) {
      currentTurn = playerChar;
    }

    if (widget.mode == GameMode.ai) {
      aiThinkingTime = aiThinkingDelayForDifficulty(
        widget.difficulty,
        boardSize: _boardConfig.boardSize,
      );
    }

    AuditService.log('match_started', {
      'matchType': widget.mode == GameMode.friend ? 'friend' : 'ai_free',
      'difficulty': widget.difficulty.name,
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeGame();
    });
  }

  Future<void> _initializeGame() async {
    await Future.wait<void>([
      _duckGameplayMusic(),
      _loadMeta(),
    ]);
    if (!mounted) return;

    // If player chose O, let the first frame paint before the AI opens.
    if (widget.mode == GameMode.ai && playerChar == "O") {
      _aiMove();
    }
  }

  Future<void> _duckGameplayMusic() async {
    // Intentionally a no-op: gameplay must not auto-lower the user's chosen
    // music volume. _musicDucked stays false so _restoreGameplayMusic also
    // short-circuits, leaving the SoundService volume untouched.
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
    unawaited(_restoreGameplayMusic());
    super.dispose();
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

  void _resetGame() {
    if (isAIMoving) return; // prevent reset while AI is moving (optional)
    _matchId = _newMatchId();
    _isResolvingResult = false;
    _rewardApplied = false;
    setState(() {
      board = List.filled(_boardConfig.cellCount, "");
      gameOver = false;
      winner = "";
      winningLine = [];
      currentTurn = widget.mode == GameMode.friend ? playerChar : "X";
      isAIMoving = false;
    });

    if (widget.mode == GameMode.ai && playerChar == "O") {
      _aiMove();
    }
  }

  void _makeMove(int index) {
    // HARD RULE: ignore any taps while AI is moving/thinking
    if (gameOver || isAIMoving) return;
    if (board[index].isNotEmpty) return;

    // In AI mode: only allow player taps on their turn
    if (widget.mode == GameMode.ai && currentTurn != playerChar) return;

    setState(() => board[index] = currentTurn);
    _checkGameState();

    if (gameOver) return;

    // switch turn
    setState(() => currentTurn = currentTurn == "X" ? "O" : "X");

    // AI turn?
    if (widget.mode == GameMode.ai && currentTurn == aiChar) {
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
      final a = line[0];
      final first = board[a];
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
      return;
    }
  }

  Future<void> _handleResult({bool draw = false}) async {
    // Guard: prevent re-entry. _checkGameState can be called from both the
    // player tap and the AI move on the same frame; without this guard we
    // would credit the reward twice.
    if (_isResolvingResult) {
      if (kDebugMode) {
        debugPrint('[AI_REWARD] matchId=$_matchId duplicate result blocked');
      }
      return;
    }
    _isResolvingResult = true;

    await _restoreGameplayMusic();
    final isFriendMode = widget.mode == GameMode.friend;
    final resultStr = draw ? 'draw' : (winner == playerChar ? 'win' : 'loss');
    final modeStr = AppModeService.isStableOnline ? 'online' : 'offline';

    final coinsToAdd = GameRewardService.rewardForAi(
      difficulty: widget.difficulty,
      result: resultStr,
      isFriendMode: isFriendMode,
    );

    if (kDebugMode) {
      debugPrint(
        '[GAME_REWARD] gameType=ai matchId=$_matchId mode=$modeStr '
        'difficulty=${widget.difficulty.name} result=$resultStr reward=$coinsToAdd',
      );
    }

    int? balanceBefore;
    int? balanceAfter;
    if (coinsToAdd > 0) {
      if (_rewardApplied) {
        if (kDebugMode) {
          debugPrint('[AI_REWARD] matchId=$_matchId duplicate reward blocked');
        }
      } else {
        // Client wallet is the single source of truth (see GameRewardService
        // + LocalStore.grantMatchRewardCF docs). The CF is stats-only.
        // Credit + ledger row go through the canonical transaction service so
        // the wallet can never move without a history entry.
        balanceBefore = LocalStore.coinsNotifier.value;
        final result = await WalletTransactionService.instance.applyCredit(
          coins: coinsToAdd,
          transactionId: 'ai_${_matchId}_reward',
          source: 'ai_reward',
          title: 'AI Match Reward',
          message: 'AI Match Reward',
          matchId: _matchId,
        );
        balanceAfter = LocalStore.coinsNotifier.value;
        _rewardApplied = result.success;
        if (kDebugMode) {
          debugPrint(
            '[AI_REWARD] matchId=$_matchId mode=$modeStr applied amount=$coinsToAdd '
            'before=$balanceBefore newCoins=$balanceAfter',
          );
          debugPrint(
              '[WALLET] mode=$modeStr delta=$coinsToAdd before=$balanceBefore after=$balanceAfter');
        }
      }
    }

    if (!mounted) return;
    final l10n = AppL10n.of(context);
    if (draw) {
      _showEndDialog(
          title: l10n.drawResult,
          subtitle: "Perfect match!\nNo one loses today.",
          icon: Icons.handshake,
          coinsAdded: 0);
    } else {
      final isWin = winner == playerChar;
      _showEndDialog(
        title: isFriendMode
            ? l10n.xWins(winner)
            : (isWin ? l10n.youWin : l10n.youLost),
        subtitle: isFriendMode
            ? "Round complete."
            : (isWin ? "Arena cleared." : "The AI took this round."),
        icon: isWin || isFriendMode
            ? Icons.emoji_events_outlined
            : Icons.sentiment_dissatisfied_outlined,
        coinsAdded: isWin ? coinsToAdd : 0,
        rewardText:
            isWin && coinsToAdd > 0 ? l10n.addedCoins(coinsToAdd) : null,
      );
    }

    AuditService.log('match_ended', {
      'matchType': isFriendMode ? 'friend' : 'ai_free',
      'difficulty': widget.difficulty.name,
      'result': resultStr,
    });

    // Missions tracking (local-only; never credits coins here). Guarded by the
    // _isResolvingResult re-entry gate above + per-matchId dedupe in the service.
    MissionService.instance
        .trackEvent('any_match_completed', matchId: _matchId);
    if (resultStr == 'win') {
      MissionService.instance.trackEvent('any_match_won', matchId: _matchId);
    }
    if (isFriendMode) {
      MissionService.instance
          .trackEvent('friend_match_completed', matchId: _matchId);
    } else {
      MissionService.instance
          .trackEvent('ai_match_completed', matchId: _matchId);
      if (resultStr == 'win') {
        MissionService.instance
            .trackEvent('ai_win_${widget.difficulty.name}', matchId: _matchId);
      }
    }

    if (!isFriendMode) {
      _persistAIResult(resultStr, coinsToAdd,
          balanceBefore: balanceBefore, balanceAfter: balanceAfter);
    }

    if (FirebaseAuth.instance.currentUser == null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showGuestSignInPrompt();
      });
    }
  }

  /// Persist game stats (and trigger the stats-only CF) in background.
  ///
  /// The CF is stats-only as of 2026-05 — it records the match in
  /// `match_rewards/{uid}_{matchId}` for idempotency and increments
  /// `Stats.*`, but it does NOT touch `Wallet.coins`. The coin reward has
  /// already been credited locally by [LocalStore.updateCoins] above and
  /// synced to Firestore through the standard wallet path.
  Future<void> _persistAIResult(
    String resultStr,
    int coinsToAdd, {
    int? balanceBefore,
    int? balanceAfter,
  }) async {
    await LocalStore.addResult(result: resultStr);
    await LocalStore.grantMatchRewardCF(matchId: _matchId, result: resultStr);
    // The coin reward + its ledger row were already recorded atomically by
    // WalletTransactionService.applyCredit in _handleResult.
    if (coinsToAdd > 0 && kDebugMode) {
      debugPrint(
          '[REWARD] ai difficulty=${widget.difficulty.name} reward=$coinsToAdd');
    }
  }

  void _showGuestSignInPrompt() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 56, color: AppPalette.primary),
                const SizedBox(height: 16),
                Text(
                  "Sign In for Coin Rewards! 🎁",
                  style: safeOrbitron(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Sign in to earn coins and track your progress!",
                  textAlign: TextAlign.center,
                  style: bodyFont(context)
                      .copyWith(height: 1.4, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        label: "LATER",
                        fill: Colors.white.withOpacity(0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.pop(context),
                        icon: Icons.close,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: "SIGN IN",
                        fill: AppPalette.primary.withOpacity(0.9),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamed('/login');
                        },
                        icon: Icons.login,
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
          _resetGame();
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
                  AppL10n.of(context).exitMatchTitle,
                  style: safeOrbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppL10n.of(context).exitMatchBody,
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

  Future<void> _aiMove() async {
    if (isAIMoving || gameOver || !mounted) return;
    setState(() => isAIMoving = true);

    await Future.delayed(Duration(milliseconds: aiThinkingTime));
    if (!mounted || gameOver) {
      if (mounted) setState(() => isAIMoving = false);
      return;
    }

    final best = _findBestMove(widget.difficulty, aiChar, playerChar);
    if (best != -1) {
      setState(() => board[best] = aiChar);
      _checkGameState();
      if (!gameOver) {
        setState(() => currentTurn = playerChar);
      }
    }

    if (mounted) setState(() => isAIMoving = false);
  }

  int _findBestMove(AIDifficulty difficulty, String ai, String human) {
    return pickStrategicMove(
      board: board,
      winningLines: _winningLines,
      aiPlayer: ai,
      humanPlayer: human,
      boardSize: _boardConfig.boardSize,
      winLength: _boardConfig.winLength,
      difficulty: difficulty,
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
    final headerLabel = widget.mode == GameMode.ai
        ? "VS AI • ${widget.difficulty.name.toUpperCase()}"
        : l10n.vsFriendTitle;
    final boardSpacing = matchBoardSpacing(_boardConfig.boardSize);
    final boardPadding = matchBoardPadding(_boardConfig.boardSize);
    final cellRadius = matchBoardCellRadius(_boardConfig.boardSize);
    final statusColor = gameOver
        ? (winner.isEmpty
            ? AppPalette.goldHighlight
            : (winner == "X" ? _xPiece : _oPiece))
        : AppPalette.text;

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
            // Force LTR for the entire gameplay UI so Arabic locale never
            // mirrors the board cells, score bar, or layout.
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final landscape =
                      constraints.maxWidth > constraints.maxHeight;
                  final buttonHeight = landscape ? 48.0 : 52.0;

                  Widget buildHeaderCard() {
                    return AppGlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: LayoutBuilder(
                        builder: (context, headerConstraints) {
                          final stackedHeader =
                              headerConstraints.maxWidth < 360;
                          final coinWidth = clampDouble(
                            headerConstraints.maxWidth *
                                (stackedHeader ? 0.48 : 0.30),
                            stackedHeader ? 118.0 : 132.0,
                            stackedHeader ? 156.0 : 176.0,
                          );
                          final titleWidth = max(
                            0.0,
                            headerConstraints.maxWidth - coinWidth - 66.0,
                          );
                          final titleBlock = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                headerLabel,
                                style:
                                    sectionFont(context).copyWith(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_boardConfig.label} • ${_boardConfig.winLength} in a row',
                                style: bodyFont(context).copyWith(
                                  fontSize: 12,
                                  color: AppPalette.textMuted,
                                ),
                              ),
                            ],
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
                                      width: max(0.0,
                                          headerConstraints.maxWidth - 56.0),
                                      child: Text(
                                        headerLabel,
                                        style: sectionFont(context)
                                            .copyWith(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                coinWidget,
                                const SizedBox(height: 10),
                                Text(
                                  '${_boardConfig.label} • ${_boardConfig.winLength} in a row',
                                  style: bodyFont(context).copyWith(
                                    fontSize: 12,
                                    color: AppPalette.textMuted,
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
                        child: gameOver
                            ? Text(
                                winner.isEmpty ? 'DRAW' : '$winner WINS',
                                style: safeOrbitron(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.4,
                                  color: statusColor,
                                ),
                              )
                            : Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  Text(
                                    l10n.nextTurnLabel,
                                    style: sectionFont(context)
                                        .copyWith(fontSize: 12),
                                  ),
                                  TurnPill(
                                    text: currentTurn,
                                    color:
                                        currentTurn == 'X' ? _xPiece : _oPiece,
                                  ),
                                  if (isAIMoving) ...[
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    Text(
                                      l10n.aiThinking,
                                      style: sectionFont(context)
                                          .copyWith(fontSize: 11),
                                    ),
                                  ],
                                ],
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
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          // Isolate board repaints from the rest of the page so a
                          // move/win-glow only repaints the board layer.
                          child: RepaintBoundary(
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _boardConfig.boardSize,
                                crossAxisSpacing: boardSpacing,
                                mainAxisSpacing: boardSpacing,
                              ),
                              itemCount: _boardConfig.cellCount,
                              itemBuilder: (context, i) {
                                final isWinCell = winningLine.contains(i);
                                final cellAccent =
                                    board[i] == 'X' ? _xPiece : _oPiece;
                                return InkWell(
                                  borderRadius:
                                      BorderRadius.circular(cellRadius),
                                  onTap: () => _makeMove(i),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(cellRadius),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: isWinCell
                                            ? [
                                                cellAccent.withValues(
                                                    alpha: 0.18),
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
                                        color: isWinCell
                                            ? cellAccent.withValues(alpha: 0.85)
                                            : AppPalette.strokeSoft,
                                        width: isWinCell ? 2.2 : 1.0,
                                      ),
                                      boxShadow: isWinCell
                                          ? [
                                              BoxShadow(
                                                color: cellAccent.withValues(
                                                  alpha: 0.20,
                                                ),
                                                blurRadius: 16,
                                                spreadRadius: 1,
                                                offset: const Offset(0, 8),
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
                                  fill: AppPalette.goldDeep
                                      .withValues(alpha: 0.95),
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
                                  fill: AppPalette.goldDeep
                                      .withValues(alpha: 0.95),
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
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
      ),
    );
  }
}

class TurnPill extends StatelessWidget {
  final String text;
  final Color color;
  const TurnPill({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(0.14),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        text,
        style: safeOrbitron(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
          color: Colors.white,
        ),
      ),
    );
  }
}

class CellContent extends StatelessWidget {
  final String v;
  final Color xColor;
  final Color oColor;
  final int boardSize;
  final String xSkin;
  final String oSkin;

  const CellContent({
    super.key,
    required this.v,
    required this.xColor,
    required this.oColor,
    this.boardSize = 3,
    this.xSkin = 'default',
    this.oSkin = 'default',
  });

  double _strokeFor(double sz) => (sz * 0.13).clamp(5.0, 12.0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final sz = constraints.maxWidth * 0.75;
      if (v == "X") {
        if (xSkin != 'default') {
          return Center(
            child: SizedBox(
              width: sz,
              height: sz,
              child: Image.asset(
                'assets/x/$xSkin.webp',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => CustomPaint(
                  size: Size(sz, sz),
                  painter: XPainter(color: xColor, strokeWidth: _strokeFor(sz)),
                ),
              ),
            ),
          );
        }
        return Center(
          child: CustomPaint(
            size: Size(sz, sz),
            painter: XPainter(color: xColor, strokeWidth: _strokeFor(sz)),
          ),
        );
      }
      if (v == "O") {
        if (oSkin != 'default') {
          return Center(
            child: SizedBox(
              width: sz,
              height: sz,
              child: Image.asset(
                'assets/o/$oSkin.webp',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) {
                  final sw = _strokeFor(sz);
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: oColor, width: sw),
                    ),
                  );
                },
              ),
            ),
          );
        }
        final sw = _strokeFor(sz);
        return Center(
          child: SizedBox(
            width: sz,
            height: sz,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: oColor, width: sw),
                boxShadow: [
                  BoxShadow(
                    color: oColor.withOpacity(0.22),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return const SizedBox();
    });
  }
}

/// Elegant X painter (kept correct)

/// End dialog (fixed layout / no broken buttons)
class EndDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onRestart;
  final VoidCallback onHome;
  final String? restartLabel;
  final IconData restartIcon;
  final int coinsAdded;
  final String? rewardText;

  const EndDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onRestart,
    required this.onHome,
    this.restartLabel,
    this.restartIcon = Icons.refresh,
    this.coinsAdded = 0,
    this.rewardText,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final effectiveRestartLabel = restartLabel ?? l10n.replayBtn;
    final isLoss = icon == Icons.sentiment_dissatisfied_outlined ||
        icon == Icons.sentiment_very_dissatisfied;
    final isDraw = icon == Icons.handshake;
    final accent = isLoss
        ? AppPalette.danger
        : isDraw
            ? AppPalette.primary
            : AppPalette.goldHighlight;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AppGlassCard(
          padding: const EdgeInsets.all(20),
          borderColor: accent.withValues(alpha: 0.34),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppPalette.panelElevated.withValues(alpha: 0.98),
              AppPalette.panelDeep.withValues(alpha: 0.98),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.22),
                      AppPalette.panelDeep.withValues(alpha: 0.98),
                    ],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.32)),
                ),
                child: Center(
                  child: isLoss
                      ? Image.asset('assets/game/skull.webp',
                          width: 44, height: 44)
                      : Icon(
                          icon,
                          size: 40,
                          color: isDraw ? AppPalette.primary : accent,
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppL10n.of(context).matchResolved,
                style: safeOrbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.3,
                  color: accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: safeOrbitron(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: bodyFont(context).copyWith(height: 1.3),
              ),
              if (coinsAdded > 0 && rewardText != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppPalette.gold.withValues(alpha: 0.16),
                        AppPalette.primary.withValues(alpha: 0.14),
                      ],
                    ),
                    border: Border.all(
                        color: AppPalette.gold.withValues(alpha: 0.38)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/coin/dollar.webp',
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        rewardText!,
                        style: safeOrbitron(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppPalette.goldHighlight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppPillButton(
                      label: AppL10n.of(context).homeBtn,
                      fill: Colors.white.withOpacity(0.08),
                      stroke: AppPalette.strokeStrong,
                      onPressed: onHome,
                      icon: Icons.home_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppPillButton(
                      label: effectiveRestartLabel,
                      fill: isLoss ? AppPalette.danger : AppPalette.primary,
                      onPressed: onRestart,
                      icon: restartIcon,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ==========================
///   LEVEL CONTINUE DIALOG
/// ==========================
class ContinueDialog extends StatefulWidget {
  final int level;
  final int cost;
  final int currentCoins;
  final VoidCallback onContinue;
  final VoidCallback onDecline;

  const ContinueDialog({
    super.key,
    required this.level,
    required this.cost,
    required this.currentCoins,
    required this.onContinue,
    required this.onDecline,
  });

  @override
  State<ContinueDialog> createState() => _ContinueDialogState();
}

class _ContinueDialogState extends State<ContinueDialog> {
  int _seconds = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _seconds--);
      if (_seconds <= 0) {
        t.cancel();
        widget.onDecline();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAfford = widget.currentCoins >= widget.cost;
    final timerColor =
        _seconds > 2 ? AppPalette.goldHighlight : AppPalette.danger;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: AppGlassCard(
          padding: const EdgeInsets.all(24),
          borderColor: AppPalette.goldHighlight.withOpacity(0.38),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppPalette.panelElevated.withOpacity(0.98),
              AppPalette.panelDeep.withOpacity(0.98),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.34),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: AppPalette.goldHighlight.withOpacity(0.16),
              blurRadius: 26,
              spreadRadius: -8,
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _seconds / 5.0,
                      backgroundColor: Colors.white12,
                      color: timerColor,
                      strokeWidth: 4,
                    ),
                    Text(
                      '$_seconds',
                      style: safeOrbitron(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'CONTINUE?',
                style: safeOrbitron(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Level ${widget.level} — keep your progress',
                style: bodyFont(context).copyWith(
                  color: AppPalette.textMuted,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppPalette.gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppPalette.gold.withOpacity(0.30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/coin/COIN.webp',
                        height: 18, fit: BoxFit.contain),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.cost} XO COINS',
                      style: safeOrbitron(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: canAfford
                            ? AppPalette.goldHighlight
                            : AppPalette.danger,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              if (!canAfford) ...[
                const SizedBox(height: 8),
                Text(
                  'Not enough coins',
                  style: bodyFont(context)
                      .copyWith(color: AppPalette.danger, fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: AppPillButton(
                      label: 'GIVE UP',
                      fill: Colors.white.withOpacity(0.06),
                      stroke: AppPalette.strokeStrong,
                      onPressed: widget.onDecline,
                      icon: Icons.close,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppPillButton(
                      label: 'CONTINUE',
                      fill: canAfford ? AppPalette.goldDeep : Colors.white12,
                      stroke: canAfford
                          ? AppPalette.goldHighlight.withOpacity(0.55)
                          : AppPalette.strokeStrong,
                      onPressed: canAfford ? widget.onContinue : null,
                      icon: Icons.bolt_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
//  CONNECTION LOST DURING ONLINE MATCH — full-screen overlay
// ────────────────────────────────────────────────────────────────────────────

/// Shown when the internet disconnects while the user is inside an online match.
///
/// Blocks the match UI completely. No result is calculated, no coins are
/// awarded/deducted, and no Firestore writes occur while this overlay is visible.
///
/// The user must choose one of three actions:
///   1. Restart in Offline Mode — abandons the match, loads offline profile.
///   2. Wait for Connection   — keeps overlay, auto-dismisses on reconnect.
///   3. Exit to Home          — pops back to home screen.

// Connection lost overlay → lib/widgets/connection_lost_match_overlay.dart
