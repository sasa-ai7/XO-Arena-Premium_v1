import 'package:flutter_test/flutter_test.dart';

import 'package:xo_arena_neon_clash/utils/ai_engine.dart';
import 'package:xo_arena_neon_clash/utils/board_utils.dart';

// Standard 3×3 winning lines
final _lines3 = generateWinningLines(boardSize: 3, winLength: 3);

List<String> _board(String s) {
  // s is a 9-char string: '.' = empty, 'X' = X, 'O' = O
  return s.split('').map((c) => c == '.' ? '' : c).toList();
}

void main() {
  const ai = 'X';
  const human = 'O';

  group('findWinningMovesForPlayer', () {
    test('finds a single winning move', () {
      final b = _board('XX.......');
      final moves = findWinningMovesForPlayer(b, _lines3, ai);
      expect(moves, contains(2));
    });

    test('returns empty when no winning move', () {
      final b = _board('.........');
      final moves = findWinningMovesForPlayer(b, _lines3, ai);
      expect(moves, isEmpty);
    });
  });

  group('findForkMovesForPlayer', () {
    test('detects fork position (center allows two threats)', () {
      // X at 0 and 3 — placing at 6 completes col-0 threat and row-2 threat.
      final b2 = _board('X..X.....');
      final forks = findForkMovesForPlayer(b2, _lines3, ai);
      // X at 0,3: placing at 6 completes col-0 threat and row-2 threat
      expect(forks, isNotEmpty);
    });

    test('no fork on empty board', () {
      final b = _board('.........');
      final forks = findForkMovesForPlayer(b, _lines3, ai);
      expect(forks, isEmpty);
    });
  });

  group('pickPerfectMove3x3 — immediate win', () {
    test('AI picks winning move when available', () {
      // X X . / . . . / . . .  → AI should play 2
      final b = _board('XX.......');
      final move = pickPerfectMove3x3(
        board: b,
        winningLines: _lines3,
        aiPlayer: ai,
        humanPlayer: human,
      );
      expect(move, equals(2));
    });
  });

  group('pickPerfectMove3x3 — block', () {
    test('AI blocks opponent immediate win', () {
      // . O O / . . . / . . .  → AI should play 0 to block
      final b = _board('.OO......');
      final move = pickPerfectMove3x3(
        board: b,
        winningLines: _lines3,
        aiPlayer: ai,
        humanPlayer: human,
      );
      expect(move, equals(0));
    });
  });

  group('pickPerfectMove3x3 — opposite corner trap', () {
    test('AI plays a side (not corner) when human takes two opposite corners', () {
      // Human at 0 and 8 (opposite corners) — AI must avoid corner moves
      // Optimal AI response: a side cell (1, 3, 5, or 7)
      final sides = {1, 3, 5, 7};
      final b = _board('O...X...O'); // AI at 4 already (center), human at 0 and 8
      // Next move: AI to play
      final move = pickPerfectMove3x3(
        board: b,
        winningLines: _lines3,
        aiPlayer: ai,
        humanPlayer: human,
      );
      expect(sides.contains(move), isTrue,
          reason: 'AI should play a side to counter opposite-corner fork, got $move');
    });
  });

  group('pickPerfectMove3x3 — unbeatable (never loses)', () {
    test('AI never loses in 100 random games (AI goes first)', () {
      for (var game = 0; game < 100; game++) {
        final board = List<String>.filled(9, '');
        String? winner;
        var moveCount = 0;

        while (true) {
          // AI move
          final aiMove = pickPerfectMove3x3(
            board: board,
            winningLines: _lines3,
            aiPlayer: ai,
            humanPlayer: human,
          );
          if (aiMove == -1) break;
          board[aiMove] = ai;
          moveCount++;
          if (_hasWon(board, _lines3, ai)) {
            winner = ai;
            break;
          }
          if (moveCount == 9) break;

          // Random human move
          final empties = [for (var i = 0; i < 9; i++) if (board[i].isEmpty) i];
          if (empties.isEmpty) break;
          empties.shuffle();
          board[empties.first] = human;
          moveCount++;
          if (_hasWon(board, _lines3, human)) {
            winner = human;
            break;
          }
        }

        expect(winner, isNot(equals(human)),
            reason: 'AI lost in game $game: ${board.join(',')}');
      }
    });

    test('AI never loses in 100 random games (Human goes first)', () {
      final random = _Rng(seed: 42);
      for (var game = 0; game < 100; game++) {
        final board = List<String>.filled(9, '');
        String? winner;
        var moveCount = 0;

        // Human first move (random)
        final firstEmpties = [for (var i = 0; i < 9; i++) if (board[i].isEmpty) i];
        board[firstEmpties[random.nextInt(firstEmpties.length)]] = human;
        moveCount++;

        while (true) {
          // AI move
          final aiMove = pickPerfectMove3x3(
            board: board,
            winningLines: _lines3,
            aiPlayer: ai,
            humanPlayer: human,
          );
          if (aiMove == -1) break;
          board[aiMove] = ai;
          moveCount++;
          if (_hasWon(board, _lines3, ai)) {
            winner = ai;
            break;
          }
          if (moveCount == 9) break;

          // Random human move
          final empties = [for (var i = 0; i < 9; i++) if (board[i].isEmpty) i];
          if (empties.isEmpty) break;
          board[empties[random.nextInt(empties.length)]] = human;
          moveCount++;
          if (_hasWon(board, _lines3, human)) {
            winner = human;
            break;
          }
        }

        expect(winner, isNot(equals(human)),
            reason: 'AI lost in game $game (human-first): ${board.join(',')}');
      }
    });
  });

  group('pickStrategicMove — hard 3x3 delegates to minimax', () {
    test('returns a valid move index', () {
      final b = _board('.........');
      final move = pickStrategicMove(
        board: b,
        winningLines: _lines3,
        aiPlayer: ai,
        humanPlayer: human,
        boardSize: 3,
        winLength: 3,
        difficulty: AIDifficulty.hard,
      );
      expect(move, greaterThanOrEqualTo(0));
      expect(move, lessThan(9));
    });
  });
}

bool _hasWon(List<String> board, List<List<int>> lines, String player) {
  for (final line in lines) {
    if (line.every((i) => board[i] == player)) return true;
  }
  return false;
}

// Minimal deterministic RNG for test reproducibility.
class _Rng {
  int _state;
  _Rng({required int seed}) : _state = seed;
  int nextInt(int max) {
    _state = (_state * 1664525 + 1013904223) & 0xFFFFFFFF;
    return _state % max;
  }
}
