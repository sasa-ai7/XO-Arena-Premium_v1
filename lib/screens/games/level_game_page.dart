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
import '../../services/sound_service.dart';
import '../../utils/ai_engine.dart';
import '../../utils/board_utils.dart';
import '../../widgets/app_ui.dart';
import 'game_page.dart';
import 'game_widgets.dart';

class LevelGamePage extends StatefulWidget {
  final int initialLevel;
  final PlayerSymbol playerSymbol;

  const LevelGamePage(
      {super.key, required this.initialLevel, required this.playerSymbol});

  @override
  State<LevelGamePage> createState() => _LevelGamePageState();
}

class _LevelGamePageState extends State<LevelGamePage> {
  late int _currentLevel;
  late int _boardSize;
  late int _winCondition;
  late AIDifficulty _difficulty;
  late List<String> board;
  bool gameOver = false;
  late String currentTurn;
  late String playerChar;
  late String aiChar;
  String winner = "";
  List<int> winningLine = [];
  bool isAIMoving = false;
  Color _xPiece = const Color(0xFFFF3B30);
  Color _oPiece = const Color(0xFF0A84FF);
  String _xSkin = 'default';
  String _oSkin = 'default';
  bool _musicDucked = false;
  int _continueCount = 0;

  /// Stable matchId for the current level attempt. Regenerated whenever the
  /// player advances, retries, or continues — so each row in
  /// `match_rewards` corresponds to exactly one resolved level.
  late String _levelMatchId;

  bool _isResolvingResult = false;
  bool _rewardApplied = false;

  String _newLevelMatchId() =>
      'level${_currentLevel}_${DateTime.now().millisecondsSinceEpoch}_${LocalStore.uid ?? 'guest'}';

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.initialLevel;
    playerChar = widget.playerSymbol == PlayerSymbol.x ? "X" : "O";
    aiChar = playerChar == "X" ? "O" : "X";
    currentTurn = playerChar; // Human plays first if X, AI plays first if O
    _levelMatchId = _newLevelMatchId();
    AuditService.log('match_started',
        {'matchType': 'level_campaign', 'level': widget.initialLevel});
    _updateLevelConfig();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeLevelMatch();
    });
  }

  Future<void> _initializeLevelMatch() async {
    await Future.wait<void>([
      _duckGameplayMusic(),
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

  void _leaveLevelGame() {
    unawaited(_restoreGameplayMusic());
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    unawaited(_restoreGameplayMusic());
    super.dispose();
  }

  void _updateLevelConfig() {
    if (_currentLevel <= 8) {
      _boardSize = 3;
      _winCondition = 3;
      final diffIndex = (_currentLevel - 1) % 3;
      _difficulty = [
        AIDifficulty.easy,
        AIDifficulty.medium,
        AIDifficulty.hard
      ][diffIndex];
    } else if (_currentLevel <= 15) {
      _boardSize = 4;
      _winCondition = 4;
      _difficulty = AIDifficulty.hard;
    } else {
      _boardSize = 5;
      _winCondition = 5;
      _difficulty = AIDifficulty.hard;
    }
    board = List.filled(_boardSize * _boardSize, "");
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

    setState(() => currentTurn = aiChar);
    if (_winningMoveFor(aiChar) != -1) {
      showTopNotification(
        context,
        "Block! AI can win next move.",
        color: AppPalette.danger,
      );
    }
    _aiMove();
  }

  void _checkGameState() {
    final lines = _generateWinLines();
    for (final line in lines) {
      if (line.length < _winCondition) continue;
      final first = board[line[0]];
      if (first.isEmpty) continue;
      bool allMatch = true;
      for (int i = 1; i < _winCondition; i++) {
        if (board[line[i]] != first) {
          allMatch = false;
          break;
        }
      }
      if (allMatch) {
        setState(() {
          gameOver = true;
          winner = first;
          winningLine = line.sublist(0, _winCondition);
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

  List<List<int>> _generateWinLines() {
    return generateWinningLines(
      boardSize: _boardSize,
      winLength: _winCondition,
    );
  }

  Future<void> _handleResult({bool draw = false}) async {
    if (_isResolvingResult) {
      if (kDebugMode) {
        debugPrint('[LEVEL_REWARD] matchId=$_levelMatchId duplicate result blocked');
      }
      return;
    }
    _isResolvingResult = true;

    await _restoreGameplayMusic();
    final resultStr = draw ? 'draw' : (winner == playerChar ? 'win' : 'loss');
    final modeStr = AppModeService.isStableOnline ? 'online' : 'offline';

    if (winner == aiChar) {
      if (!mounted) return;
      if (_currentLevel >= 3 &&
          LocalStore.coinsNotifier.value >= 100 * (1 << _continueCount)) {
        _showContinueDialog();
      } else {
        _doLoss(resultStr);
      }
    } else if (draw) {
      if (!mounted) return;
      _showEndDialog(
        title: "DRAW",
        subtitle: "Replay same level.",
        icon: Icons.handshake,
        resetLevel: false,
        isDraw: true,
        isWin: false,
      );
      AuditService.log('match_ended', {
        'matchType': 'level_campaign',
        'level': _currentLevel,
        'result': resultStr
      });
      _persistLevelResult(resultStr, 0);
    } else {
      final reward = GameRewardService.rewardForLevel(
        level: _currentLevel,
        result: resultStr,
      );
      final nextLevel = _currentLevel < 20 ? _currentLevel + 1 : _currentLevel;

      if (kDebugMode) {
        debugPrint(
          '[GAME_REWARD] gameType=level matchId=$_levelMatchId mode=$modeStr '
          'level=$_currentLevel result=$resultStr reward=$reward',
        );
      }

      int? balanceBefore;
      int balanceAfter = LocalStore.coinsNotifier.value;
      if (reward > 0 && !_rewardApplied) {
        balanceBefore = LocalStore.coinsNotifier.value;
        await LocalStore.updateCoins(reward);
        balanceAfter = LocalStore.coinsNotifier.value;
        _rewardApplied = true;
        if (kDebugMode) {
          debugPrint(
            '[LEVEL_REWARD] matchId=$_levelMatchId mode=$modeStr level=$_currentLevel '
            'applied amount=$reward before=$balanceBefore newCoins=$balanceAfter',
          );
          debugPrint('[WALLET] mode=$modeStr delta=$reward before=$balanceBefore after=$balanceAfter');
        }
      } else if (reward > 0 && _rewardApplied) {
        if (kDebugMode) {
          debugPrint('[LEVEL_REWARD] matchId=$_levelMatchId duplicate reward blocked');
        }
      }

      if (!mounted) return;
      if (_currentLevel >= 20) {
        _showEndDialog(
          title: "CONGRATULATIONS!",
          subtitle: "You completed all 20 levels!",
          icon: Icons.emoji_events,
          resetLevel: false,
          isDraw: false,
          isWin: true,
          coinsAdded: reward,
          rewardText: AppL10n.of(context).addedCoins(reward),
        );
      } else {
        _showEndDialog(
          title: AppL10n.of(context).levelCompleteTitle(_currentLevel),
          subtitle: AppL10n.of(context).startingLevel(nextLevel),
          icon: Icons.check_circle_outline,
          resetLevel: false,
          isDraw: false,
          isWin: true,
          coinsAdded: reward,
          rewardText: AppL10n.of(context).addedCoins(reward),
        );
      }

      AuditService.log('match_ended', {
        'matchType': 'level_campaign',
        'level': _currentLevel,
        'result': resultStr
      });
      _persistLevelResult(
        resultStr,
        reward,
        balanceBefore: balanceBefore,
        balanceAfter: balanceAfter,
        nextLevel: nextLevel,
      );
    }
  }

  /// Persist level stats (and trigger the stats-only CF) in background.
  /// The coin reward has already been credited by [_handleResult] via
  /// [LocalStore.updateCoins]; the CF only records the match for
  /// idempotency and increments `Stats.*` server-side.
  Future<void> _persistLevelResult(String resultStr, int reward,
      {bool isLoss = false, int? nextLevel, int? balanceBefore, int? balanceAfter}) async {
    try {
      if (isLoss) {
        await LocalStore.resetLevelGame();
      }
      await LocalStore.addResult(result: resultStr);
      await LocalStore.grantMatchRewardCF(matchId: _levelMatchId, result: resultStr);
      if (reward > 0) {
        if (kDebugMode) {
          debugPrint('[REWARD] level=$_currentLevel reward=$reward');
        }
        await LocalStore.addTopupHistory(
          usd: 0.0,
          coins: reward,
          type: 'win',
          source: 'level_win',
          description: 'Level $_currentLevel Reward',
          transactionId: _levelMatchId,
          balanceBefore: balanceBefore,
          balanceAfter: balanceAfter,
        );
      }
      if (nextLevel != null) {
        if (_currentLevel < 20) {
          await LocalStore.setLevelGameCurrentLevel(nextLevel);
        } else {
          await LocalStore.setLevelGameCompleted(true);
          await LocalStore.incrementLevelGameCompletions();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LevelGamePage] Background persist error: $e');
      }
    }
  }

  void _doLoss(String resultStr) {
    if (!mounted) return;
    _continueCount = 0;
    _showEndDialog(
      title: 'YOU LOST',
      subtitle: 'Level reset to 1\nStart from beginning!',
      icon: Icons.sentiment_dissatisfied_outlined,
      resetLevel: true,
      isDraw: false,
      isWin: false,
    );
    AuditService.log('match_ended', {
      'matchType': 'level_campaign',
      'level': _currentLevel,
      'result': resultStr,
    });
    _persistLevelResult(resultStr, 0, isLoss: true);
  }

  void _showContinueDialog() {
    final cost = 100 * (1 << _continueCount);
    final currentCoins = LocalStore.coinsNotifier.value;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ContinueDialog(
        level: _currentLevel,
        cost: cost,
        currentCoins: currentCoins,
        onContinue: () {
          Navigator.pop(context);
          _doContinue(cost, currentCoins);
        },
        onDecline: () {
          Navigator.pop(context);
          _doLoss('loss');
        },
      ),
    );
  }

  Future<void> _doContinue(int cost, int coinsBefore) async {
    // Mode-aware, awaited deduction. The previous implementation used
    // applyCoinDeltaLocally + an unawaited syncCoinBalance, which raced
    // with the board reset and could let the player resume the level
    // before Firestore had recorded the spend.
    final modeStr = AppModeService.isStableOnline ? 'online' : 'offline';
    final isOffline = AppModeService.current == AppMode.offline;
    if (!isOffline && !AppModeService.canUseOnlineServices) {
      if (kDebugMode) {
        debugPrint(
          '[LEVEL_CONTINUE] matchId=$_levelMatchId blocked because app is not safely online '
          '(mode=${AppModeService.current})',
        );
      }
      if (mounted) {
        showTopNotification(
          context,
          'Connection unstable — continue is unavailable.',
          color: AppPalette.danger,
        );
      }
      _isResolvingResult = false; // allow re-entry once connection returns
      return;
    }

    _continueCount++;
    final before = LocalStore.coinsNotifier.value;
    await LocalStore.updateCoins(-cost); // mode-aware: offline → offline wallet; online → Firestore-synced
    final after = LocalStore.coinsNotifier.value;
    await LocalStore.addTopupHistory(
      usd: 0.0,
      coins: -cost,
      type: 'spend',
      description: 'Level $_currentLevel Continue',
      balanceBefore: coinsBefore,
      balanceAfter: coinsBefore - cost,
    );
    if (kDebugMode) {
      debugPrint(
        '[LEVEL_CONTINUE] matchId=$_levelMatchId mode=$modeStr cost=$cost '
        'before=$before newCoins=$after',
      );
    }

    unawaited(_duckGameplayMusic());
    if (!mounted) return;
    // Continue keeps the same level but counts as a new match attempt for
    // idempotency and result/reward guards.
    _levelMatchId = _newLevelMatchId();
    _isResolvingResult = false;
    _rewardApplied = false;
    setState(() {
      board = List.filled(_boardSize * _boardSize, '');
      gameOver = false;
      winner = '';
      winningLine = [];
      currentTurn = playerChar;
      isAIMoving = false;
    });
    if (currentTurn == aiChar) _aiMove();
  }

  void _showEndDialog({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool resetLevel,
    required bool isDraw,
    required bool isWin,
    int coinsAdded = 0,
    String? rewardText,
  }) {
    final useNext = isWin;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EndDialog(
        title: title,
        subtitle: subtitle,
        icon: icon,
        coinsAdded: coinsAdded,
        rewardText: rewardText,
        restartLabel: useNext ? AppL10n.of(context).nextBtn : AppL10n.of(context).replayBtn,
        restartIcon: useNext ? Icons.arrow_forward : Icons.refresh,
        onRestart: () {
          Navigator.pop(context);
          unawaited(_duckGameplayMusic());
          if (resetLevel) {
            _currentLevel = 1;
            _continueCount = 0;
            _updateLevelConfig();
          } else if (!isDraw) {
            final nextLevel =
                _currentLevel < 20 ? _currentLevel + 1 : _currentLevel;
            _currentLevel = nextLevel;
            _updateLevelConfig();
          }
          // Fresh match attempt — new matchId, reset guards.
          _levelMatchId = _newLevelMatchId();
          _isResolvingResult = false;
          _rewardApplied = false;
          setState(() {
            board = List.filled(_boardSize * _boardSize, "");
            gameOver = false;
            winner = "";
            winningLine = [];
            currentTurn = playerChar;
            isAIMoving = false;
          });
          if (currentTurn == aiChar) _aiMove();
        },
        onHome: () {
          Navigator.pop(context);
          _leaveLevelGame();
        },
      ),
    );
  }

  Future<void> _aiMove() async {
    if (isAIMoving || gameOver || !mounted) return;
    setState(() => isAIMoving = true);

    final thinkingTime = aiThinkingDelayForDifficulty(
      _difficulty,
      boardSize: _boardSize,
    );

    await Future.delayed(Duration(milliseconds: thinkingTime));
    if (!mounted || gameOver) {
      if (mounted) setState(() => isAIMoving = false);
      return;
    }

    final best = _findBestMove();
    if (best != -1) {
      setState(() => board[best] = aiChar);
      _checkGameState();
      if (!gameOver) {
        setState(() => currentTurn = playerChar);
      }
    }

    if (mounted) setState(() => isAIMoving = false);
  }

  int _findBestMove() {
    return pickStrategicMove(
      board: board,
      winningLines: _generateWinLines(),
      aiPlayer: aiChar,
      humanPlayer: playerChar,
      boardSize: _boardSize,
      winLength: _winCondition,
      difficulty: _difficulty,
    );
  }

  int _winningMoveFor(String who) {
    final lines = _generateWinLines();
    for (final line in lines) {
      if (line.length < _winCondition) continue;
      int count = 0;
      int emptyIndex = -1;
      for (int i = 0; i < _winCondition; i++) {
        if (board[line[i]] == who) {
          count++;
        } else if (board[line[i]].isEmpty) {
          emptyIndex = line[i];
        } else {
          break;
        }
      }
      if (count == _winCondition - 1 && emptyIndex != -1) {
        return emptyIndex;
      }
    }
    return -1;
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
                  AppL10n.of(context).exitLevelRunTitle,
                  style: safeOrbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppL10n.of(context).exitLevelBody,
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
                        onPressed: () async {
                          Navigator.pop(context);
                          await _restoreGameplayMusic();
                          await LocalStore.resetLevelGame();
                          if (!mounted) return;
                          _leaveLevelGame();
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

  @override
  Widget build(BuildContext context) {
    final boardSpacing = matchBoardSpacing(_boardSize);
    final boardPadding = matchBoardPadding(_boardSize);
    final cellRadius = matchBoardCellRadius(_boardSize);
    final statusColor = gameOver
        ? (winner.isEmpty
            ? AppPalette.goldHighlight
            : (winner == "X" ? _xPiece : _oPiece))
        : AppPalette.text;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showExitConfirmation();
      },
      child: Scaffold(
        body: SafeArea(
          child: AppBackground(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final landscape = constraints.maxWidth > constraints.maxHeight;

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
                              'LEVEL $_currentLevel',
                              style: sectionFont(context),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_boardSize×$_boardSize • $_winCondition in a row',
                              style: bodyFont(context),
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
                                      'LEVEL $_currentLevel',
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
                                '$_boardSize×$_boardSize • $_winCondition in a row',
                                style: bodyFont(context),
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

                Widget buildBoard(BoxConstraints boardConstraints) {
                  final boardViewport = matchBoardViewportSizeForBounds(
                    boardSize: _boardSize,
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
                          crossAxisCount: _boardSize,
                          mainAxisSpacing: boardSpacing,
                          crossAxisSpacing: boardSpacing,
                        ),
                        itemCount: _boardSize * _boardSize,
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
                                      ? cellAccent.withValues(alpha: 0.85)
                                      : AppPalette.strokeSoft,
                                  width: isWinning ? 2 : 1,
                                ),
                                boxShadow: isWinning
                                    ? [
                                        BoxShadow(
                                          color: cellAccent.withValues(
                                            alpha: 0.20,
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
                                  boardSize: _boardSize,
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

                return Stack(
                  children: [
                    if (landscape)
                      Row(
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
                      )
                    else
                      Column(
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
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
///   STORE (CONSISTENT UI)
/// ==========================
