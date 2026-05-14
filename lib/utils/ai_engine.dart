import 'dart:math';

import 'board_utils.dart';

final _rng = Random();

int aiThinkingDelayForDifficulty(
  AIDifficulty difficulty, {
  required int boardSize,
}) {
  final boardDelay = boardSize >= 5
      ? 24
      : boardSize == 4
          ? 12
          : 0;
  switch (difficulty) {
    case AIDifficulty.easy:
      return 95 + boardDelay;
    case AIDifficulty.medium:
      return 140 + boardDelay;
    case AIDifficulty.hard:
      return 175 + boardDelay;
  }
}

int countOpenThreatsForPlayer({
  required List<String> board,
  required List<List<int>> winningLines,
  required String player,
  required int winLength,
}) {
  var total = 0;
  for (final line in winningLines) {
    var playerCount = 0;
    var opponentCount = 0;
    var emptyCount = 0;
    for (final index in line) {
      final value = board[index];
      if (value == player) {
        playerCount++;
      } else if (value.isEmpty) {
        emptyCount++;
      } else {
        opponentCount++;
      }
    }

    if (opponentCount == 0 && playerCount == winLength - 1 && emptyCount == 1) {
      total++;
    }
  }
  return total;
}

int adjacentSupportCount({
  required List<String> board,
  required int moveIndex,
  required String player,
  required int boardSize,
}) {
  final row = moveIndex ~/ boardSize;
  final col = moveIndex % boardSize;
  var total = 0;

  for (int rowOffset = -1; rowOffset <= 1; rowOffset++) {
    for (int colOffset = -1; colOffset <= 1; colOffset++) {
      if (rowOffset == 0 && colOffset == 0) continue;
      final nextRow = row + rowOffset;
      final nextCol = col + colOffset;
      if (nextRow < 0 ||
          nextRow >= boardSize ||
          nextCol < 0 ||
          nextCol >= boardSize) {
        continue;
      }

      final nextIndex = nextRow * boardSize + nextCol;
      if (board[nextIndex] == player) {
        total++;
      }
    }
  }

  return total;
}

int adjacentOccupiedCount({
  required List<String> board,
  required int moveIndex,
  required int boardSize,
}) {
  final row = moveIndex ~/ boardSize;
  final col = moveIndex % boardSize;
  var total = 0;

  for (int rowOffset = -1; rowOffset <= 1; rowOffset++) {
    for (int colOffset = -1; colOffset <= 1; colOffset++) {
      if (rowOffset == 0 && colOffset == 0) continue;
      final nextRow = row + rowOffset;
      final nextCol = col + colOffset;
      if (nextRow < 0 ||
          nextRow >= boardSize ||
          nextCol < 0 ||
          nextCol >= boardSize) {
        continue;
      }

      final nextIndex = nextRow * boardSize + nextCol;
      if (board[nextIndex].isNotEmpty) {
        total++;
      }
    }
  }

  return total;
}

double boardControlScore({
  required int moveIndex,
  required int boardSize,
}) {
  final row = moveIndex ~/ boardSize;
  final col = moveIndex % boardSize;
  final midpoint = (boardSize - 1) / 2;
  final distance = (row - midpoint).abs() + (col - midpoint).abs();
  final maxDistance = midpoint * 2;
  final normalized = max(0.0, maxDistance - distance);
  return normalized * (boardSize >= 4 ? 5.0 : 4.0);
}

double candidateHeatForMove({
  required List<String> board,
  required List<List<int>> winningLines,
  required int moveIndex,
  required String aiPlayer,
  required String humanPlayer,
  required int boardSize,
}) {
  var heat = boardControlScore(moveIndex: moveIndex, boardSize: boardSize);
  heat += adjacentOccupiedCount(
        board: board,
        moveIndex: moveIndex,
        boardSize: boardSize,
      ) *
      10;

  for (final line in winningLines) {
    if (!line.contains(moveIndex)) {
      continue;
    }

    var aiCount = 0;
    var humanCount = 0;
    for (final index in line) {
      if (board[index] == aiPlayer) {
        aiCount++;
      } else if (board[index] == humanPlayer) {
        humanCount++;
      }
    }

    if (aiCount == 0 || humanCount == 0) {
      heat += 8;
    }
    if (aiCount > 0 && humanCount == 0) {
      heat += aiCount * 7;
    }
    if (humanCount > 0 && aiCount == 0) {
      heat += humanCount * 6;
    }
  }

  return heat;
}

List<int> rankedCandidateMoves({
  required List<String> board,
  required List<List<int>> winningLines,
  required String aiPlayer,
  required String humanPlayer,
  required int boardSize,
  required AIDifficulty difficulty,
}) {
  final empties = List.generate(board.length, (i) => i)
      .where((i) => board[i].isEmpty)
      .toList();
  final filledCount = board.length - empties.length;

  if (empties.length <= 7 || filledCount <= 1) {
    return empties;
  }

  final candidateLimit = switch (difficulty) {
    AIDifficulty.easy => boardSize >= 5
        ? 16
        : boardSize == 4
            ? 14
            : empties.length,
    AIDifficulty.medium => boardSize >= 5
        ? 14
        : boardSize == 4
            ? 12
            : empties.length,
    AIDifficulty.hard => boardSize >= 5
        ? 12
        : boardSize == 4
            ? 10
            : empties.length,
  };

  final heatedMoves = empties
      .map(
        (index) => MapEntry(
          index,
          candidateHeatForMove(
            board: board,
            winningLines: winningLines,
            moveIndex: index,
            aiPlayer: aiPlayer,
            humanPlayer: humanPlayer,
            boardSize: boardSize,
          ),
        ),
      )
      .toList()
    ..sort((left, right) => right.value.compareTo(left.value));

  return heatedMoves
      .take(min(candidateLimit, heatedMoves.length))
      .map((entry) => entry.key)
      .toList();
}

double evaluateHardLookahead({
  required List<String> board,
  required List<List<int>> winningLines,
  required int moveIndex,
  required String aiPlayer,
  required String humanPlayer,
  required int boardSize,
  required int winLength,
}) {
  board[moveIndex] = aiPlayer;

  final immediateHumanWin = findWinningMoveForBoard(
    board: board,
    winningLines: winningLines,
    player: humanPlayer,
    winLength: winLength,
  );
  if (immediateHumanWin != -1) {
    board[moveIndex] = '';
    return -260;
  }

  var adjustment = countOpenThreatsForPlayer(
        board: board,
        winningLines: winningLines,
        player: aiPlayer,
        winLength: winLength,
      ) *
      14.0;

  final replies = rankedCandidateMoves(
    board: board,
    winningLines: winningLines,
    aiPlayer: humanPlayer,
    humanPlayer: aiPlayer,
    boardSize: boardSize,
    difficulty: AIDifficulty.medium,
  );

  var worstReplyPressure = 0.0;
  final replyLimit = boardSize >= 5 ? 4 : 5;
  for (final reply in replies.take(replyLimit)) {
    board[reply] = humanPlayer;

    final humanThreats = countOpenThreatsForPlayer(
      board: board,
      winningLines: winningLines,
      player: humanPlayer,
      winLength: winLength,
    );
    final humanWinningReply = findWinningMoveForBoard(
      board: board,
      winningLines: winningLines,
      player: humanPlayer,
      winLength: winLength,
    );
    final aiCounterWin = findWinningMoveForBoard(
      board: board,
      winningLines: winningLines,
      player: aiPlayer,
      winLength: winLength,
    );

    var replyPressure = humanThreats * 52.0;
    if (humanWinningReply != -1) {
      replyPressure += 120.0;
    }
    if (aiCounterWin == -1 && humanThreats > 1) {
      replyPressure += 44.0;
    }

    worstReplyPressure = max(worstReplyPressure, replyPressure);
    board[reply] = '';
  }

  board[moveIndex] = '';
  adjustment -= worstReplyPressure;
  return adjustment;
}

double scoreStrategicMove({
  required List<String> board,
  required List<List<int>> winningLines,
  required int moveIndex,
  required String aiPlayer,
  required String humanPlayer,
  required int boardSize,
  required int winLength,
  required AIDifficulty difficulty,
}) {
  var score = 0.0;
  var openLineTouches = 0;
  final attackWeight = switch (difficulty) {
    AIDifficulty.easy => 5.5,
    AIDifficulty.medium => 7.0,
    AIDifficulty.hard => 8.5,
  };
  final defendWeight = switch (difficulty) {
    AIDifficulty.easy => 14.0,
    AIDifficulty.medium => 24.0,
    AIDifficulty.hard => 34.0,
  };

  for (final line in winningLines) {
    if (!line.contains(moveIndex)) {
      continue;
    }

    openLineTouches++;

    var projectedAiCount = 0;
    var projectedHumanCount = 0;
    var projectedEmptyCount = 0;
    var currentAiCount = 0;
    var currentHumanCount = 0;

    for (final index in line) {
      final projectedValue = index == moveIndex ? aiPlayer : board[index];
      if (projectedValue == aiPlayer) {
        projectedAiCount++;
      } else if (projectedValue == humanPlayer) {
        projectedHumanCount++;
      } else {
        projectedEmptyCount++;
      }

      final currentValue = board[index];
      if (currentValue == aiPlayer) {
        currentAiCount++;
      } else if (currentValue == humanPlayer) {
        currentHumanCount++;
      }
    }

    if (projectedHumanCount == 0) {
      score += projectedAiCount * projectedAiCount * attackWeight;
      if (currentAiCount > 0) {
        score += (currentAiCount + 1) * attackWeight;
      }
      if (projectedAiCount == winLength - 1 && projectedEmptyCount == 1) {
        score += switch (difficulty) {
          AIDifficulty.easy => 150,
          AIDifficulty.medium => 200,
          AIDifficulty.hard => 240,
        };
      } else if (projectedAiCount == winLength - 2 &&
          projectedEmptyCount == 2) {
        score += switch (difficulty) {
          AIDifficulty.easy => 34,
          AIDifficulty.medium => 60,
          AIDifficulty.hard => 84,
        };
      } else if (projectedAiCount == 1) {
        score += difficulty == AIDifficulty.easy ? 4 : 6;
      }
    }

    if (currentAiCount == 0 && currentHumanCount > 0) {
      score += currentHumanCount * defendWeight;
      if (currentHumanCount == winLength - 1) {
        score += switch (difficulty) {
          AIDifficulty.easy => 150,
          AIDifficulty.medium => 260,
          AIDifficulty.hard => 320,
        };
      } else if (currentHumanCount == winLength - 2) {
        score += switch (difficulty) {
          AIDifficulty.easy => 42,
          AIDifficulty.medium => 88,
          AIDifficulty.hard => 132,
        };
      }
    }
  }

  score += openLineTouches *
      switch (difficulty) {
        AIDifficulty.easy => 1.5,
        AIDifficulty.medium => 3.0,
        AIDifficulty.hard => 4.5,
      };

  if (preferredCenterIndices(boardSize).contains(moveIndex)) {
    score += boardSize.isOdd ? 22 : 18;
  }
  if (cornerIndices(boardSize).contains(moveIndex)) {
    score += difficulty == AIDifficulty.easy ? 8 : 10;
  }
  if (perimeterEdgeIndices(boardSize).contains(moveIndex)) {
    score += boardSize >= 4 ? 4 : 5;
  }

  score += boardControlScore(moveIndex: moveIndex, boardSize: boardSize);

  score += adjacentSupportCount(
        board: board,
        moveIndex: moveIndex,
        player: aiPlayer,
        boardSize: boardSize,
      ) *
      switch (difficulty) {
        AIDifficulty.easy => 3,
        AIDifficulty.medium => 5,
        AIDifficulty.hard => 7,
      };

  score += adjacentOccupiedCount(
        board: board,
        moveIndex: moveIndex,
        boardSize: boardSize,
      ) *
      switch (difficulty) {
        AIDifficulty.easy => 1.5,
        AIDifficulty.medium => 2.5,
        AIDifficulty.hard => 4.0,
      };

  board[moveIndex] = aiPlayer;
  final aiThreats = countOpenThreatsForPlayer(
    board: board,
    winningLines: winningLines,
    player: aiPlayer,
    winLength: winLength,
  );
  final humanThreats = countOpenThreatsForPlayer(
    board: board,
    winningLines: winningLines,
    player: humanPlayer,
    winLength: winLength,
  );

  score += aiThreats *
      switch (difficulty) {
        AIDifficulty.easy => 16,
        AIDifficulty.medium => 26,
        AIDifficulty.hard => 38,
      };
  score -= humanThreats *
      switch (difficulty) {
        AIDifficulty.easy => 10,
        AIDifficulty.medium => 26,
        AIDifficulty.hard => 40,
      };

  final opponentReply = findWinningMoveForBoard(
    board: board,
    winningLines: winningLines,
    player: humanPlayer,
    winLength: winLength,
  );
  board[moveIndex] = "";

  if (opponentReply != -1) {
    if (difficulty == AIDifficulty.hard) {
      score -= 210;
    } else if (difficulty == AIDifficulty.medium) {
      score -= 120;
    } else {
      score -= 50;
    }
  }

  return score;
}

int findWinningMoveForBoard({
  required List<String> board,
  required List<List<int>> winningLines,
  required String player,
  required int winLength,
}) {
  for (final line in winningLines) {
    var playerCount = 0;
    var emptyIndex = -1;
    var blocked = false;

    for (final index in line) {
      final value = board[index];
      if (value == player) {
        playerCount++;
      } else if (value.isEmpty) {
        emptyIndex = index;
      } else {
        blocked = true;
        break;
      }
    }

    if (!blocked && playerCount == winLength - 1 && emptyIndex != -1) {
      return emptyIndex;
    }
  }
  return -1;
}

// ── Fork detection helpers ────────────────────────────────────────────────────

/// All cell indices where [player] would immediately win on the next move.
List<int> findWinningMovesForPlayer(
  List<String> board,
  List<List<int>> lines,
  String player,
) {
  final moves = <int>[];
  for (final line in lines) {
    var playerCount = 0;
    var emptyIndex = -1;
    var blocked = false;
    for (final idx in line) {
      if (board[idx] == player) {
        playerCount++;
      } else if (board[idx].isEmpty) {
        if (emptyIndex == -1) {
          emptyIndex = idx;
        } else {
          blocked = true;
          break;
        }
      } else {
        blocked = true;
        break;
      }
    }
    if (!blocked && playerCount == line.length - 1 && emptyIndex != -1) {
      if (!moves.contains(emptyIndex)) moves.add(emptyIndex);
    }
  }
  return moves;
}

/// All cell indices where placing [player]'s piece creates 2+ simultaneous threats.
List<int> findForkMovesForPlayer(
  List<String> board,
  List<List<int>> lines,
  String player,
) {
  final forks = <int>[];
  for (var i = 0; i < board.length; i++) {
    if (board[i].isNotEmpty) continue;
    final trial = List<String>.from(board)..[i] = player;
    final threats = findWinningMovesForPlayer(trial, lines, player);
    if (threats.length >= 2) forks.add(i);
  }
  return forks;
}

/// Best anti-fork move for [aiPlayer] against [humanPlayer].
/// If the human has exactly one fork move: play that cell (block + threat).
/// If multiple fork moves: create a forcing threat that isn't itself a human fork.
/// Returns -1 if no anti-fork needed.
int findBestAntiForkMove(
  List<String> board,
  List<List<int>> lines,
  String aiPlayer,
  String humanPlayer,
) {
  final humanForks = findForkMovesForPlayer(board, lines, humanPlayer);
  if (humanForks.isEmpty) return -1;

  // One fork: block it directly.
  if (humanForks.length == 1) return humanForks.first;

  // Multiple forks: create a forcing threat from a cell that is not itself a fork
  // for the human (so blocking the threat doesn't create a new fork).
  for (var i = 0; i < board.length; i++) {
    if (board[i].isNotEmpty) continue;
    if (humanForks.contains(i)) continue;
    final trial = List<String>.from(board)..[i] = aiPlayer;
    final threats = findWinningMovesForPlayer(trial, lines, aiPlayer);
    if (threats.isNotEmpty) return i;
  }
  // Fallback: block the first fork.
  return humanForks.first;
}

// ── Minimax (3×3 only) ────────────────────────────────────────────────────────

bool _checkWinner(List<String> board, List<List<int>> lines, String player) {
  for (final line in lines) {
    if (line.every((i) => board[i] == player)) return true;
  }
  return false;
}

int _minimax(
  List<String> board,
  List<List<int>> lines,
  String maximizer,
  String minimizer,
  bool isMaximizing,
  int depth,
  int alpha,
  int beta,
) {
  if (_checkWinner(board, lines, maximizer)) return 10 - depth;
  if (_checkWinner(board, lines, minimizer)) return depth - 10;
  final empties = [for (var i = 0; i < board.length; i++) if (board[i].isEmpty) i];
  if (empties.isEmpty) return 0;

  if (isMaximizing) {
    var best = -100;
    for (final idx in empties) {
      board[idx] = maximizer;
      final score = _minimax(board, lines, maximizer, minimizer, false, depth + 1, alpha, beta);
      board[idx] = '';
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (beta <= alpha) break;
    }
    return best;
  } else {
    var best = 100;
    for (final idx in empties) {
      board[idx] = minimizer;
      final score = _minimax(board, lines, maximizer, minimizer, true, depth + 1, alpha, beta);
      board[idx] = '';
      if (score < best) best = score;
      if (best < beta) beta = best;
      if (beta <= alpha) break;
    }
    return best;
  }
}

/// Perfect play for standard 3×3 Tic Tac Toe.
/// Uses minimax with alpha-beta pruning — the AI never loses.
/// Only call this for boardSize == 3 && winLength == 3.
int pickPerfectMove3x3({
  required List<String> board,
  required List<List<int>> winningLines,
  required String aiPlayer,
  required String humanPlayer,
}) {
  final workingBoard = List<String>.from(board);
  var bestScore = -100;
  var bestMove = -1;
  for (var i = 0; i < workingBoard.length; i++) {
    if (workingBoard[i].isNotEmpty) continue;
    workingBoard[i] = aiPlayer;
    final score = _minimax(
      workingBoard, winningLines,
      aiPlayer, humanPlayer,
      false, 0, -100, 100,
    );
    workingBoard[i] = '';
    if (score > bestScore) {
      bestScore = score;
      bestMove = i;
    }
  }
  return bestMove;
}

// ── Strategic move picker ─────────────────────────────────────────────────────

int pickStrategicMove({
  required List<String> board,
  required List<List<int>> winningLines,
  required String aiPlayer,
  required String humanPlayer,
  required int boardSize,
  required int winLength,
  required AIDifficulty difficulty,
}) {
  final empties = List.generate(board.length, (i) => i)
      .where((i) => board[i].isEmpty)
      .toList();
  if (empties.isEmpty) return -1;

  final candidateMoves = rankedCandidateMoves(
    board: board,
    winningLines: winningLines,
    aiPlayer: aiPlayer,
    humanPlayer: humanPlayer,
    boardSize: boardSize,
    difficulty: difficulty,
  );

  final win = findWinningMoveForBoard(
    board: board,
    winningLines: winningLines,
    player: aiPlayer,
    winLength: winLength,
  );
  if (win != -1) return win;

  final block = findWinningMoveForBoard(
    board: board,
    winningLines: winningLines,
    player: humanPlayer,
    winLength: winLength,
  );

  switch (difficulty) {
    case AIDifficulty.easy:
      if (block != -1 && _rng.nextDouble() < 0.28) {
        return block;
      }
      if (_rng.nextDouble() < (boardSize >= 4 ? 0.62 : 0.52)) {
        return empties[_rng.nextInt(empties.length)];
      }
      break;
    case AIDifficulty.medium:
      if (block != -1) {
        return block;
      }
      break;
    case AIDifficulty.hard:
      if (block != -1) {
        return block;
      }
      // Perfect play for 3×3: minimax guarantees AI never loses.
      if (boardSize == 3 && winLength == 3) {
        return pickPerfectMove3x3(
          board: board,
          winningLines: winningLines,
          aiPlayer: aiPlayer,
          humanPlayer: humanPlayer,
        );
      }
      break;
  }

  final scoredMoves = candidateMoves
      .map(
        (index) => MapEntry(
          index,
          scoreStrategicMove(
            board: board,
            winningLines: winningLines,
            moveIndex: index,
            aiPlayer: aiPlayer,
            humanPlayer: humanPlayer,
            boardSize: boardSize,
            winLength: winLength,
            difficulty: difficulty,
          ),
        ),
      )
      .toList()
    ..sort((left, right) => right.value.compareTo(left.value));

  if (scoredMoves.isEmpty) {
    return empties[_rng.nextInt(empties.length)];
  }

  switch (difficulty) {
    case AIDifficulty.easy:
      final choices = scoredMoves.take(min(5, scoredMoves.length)).toList();
      return choices[_rng.nextInt(choices.length)].key;
    case AIDifficulty.medium:
      final choices = scoredMoves.take(min(4, scoredMoves.length)).toList();
      if (_rng.nextDouble() < 0.22) {
        return choices[_rng.nextInt(choices.length)].key;
      }
      return choices.first.key;
    case AIDifficulty.hard:
      final finalists = scoredMoves.take(min(4, scoredMoves.length)).map((entry) {
        final lookaheadScore = evaluateHardLookahead(
          board: board,
          winningLines: winningLines,
          moveIndex: entry.key,
          aiPlayer: aiPlayer,
          humanPlayer: humanPlayer,
          boardSize: boardSize,
          winLength: winLength,
        );
        return MapEntry(entry.key, entry.value + lookaheadScore);
      }).toList()
        ..sort((left, right) => right.value.compareTo(left.value));

      final bestScore = finalists.first.value;
      final stableChoices = finalists
          .where((entry) => entry.value >= bestScore - 3)
          .toList();
      return stableChoices.first.key;
  }
}
