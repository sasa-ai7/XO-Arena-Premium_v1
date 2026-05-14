import '../utils/board_utils.dart';

/// Central source of truth for match reward amounts.
///
/// Every game page MUST compute its reward via this service — no hardcoded
/// `15` or `100` constants anywhere else. This prevents the historic +15
/// ghost reward and keeps the AI/Level/Coin Match reward rules visible in
/// one place.
class GameRewardService {
  GameRewardService._();

  /// AI game reward.
  /// - friend mode: 0
  /// - loss/draw: 0
  /// - easy win: 0
  /// - medium win: 10
  /// - hard win: 15
  static int rewardForAi({
    required AIDifficulty difficulty,
    required String result,
    required bool isFriendMode,
  }) {
    if (isFriendMode) return 0;
    if (result != 'win') return 0;
    if (difficulty == AIDifficulty.medium) return 10;
    if (difficulty == AIDifficulty.hard) return 15;
    return 0; // easy / unknown
  }

  /// Level game reward (campaign).
  /// - loss/draw: 0
  /// - 1..9 win: 10
  /// - 10 win:   100
  /// - 11..19 win: 15
  /// - 20 win:   500
  static int rewardForLevel({required int level, required String result}) {
    if (result != 'win') return 0;
    if (level == 20) return 500;
    if (level >= 11 && level <= 19) return 15;
    if (level == 10) return 100;
    if (level >= 1 && level <= 9) return 10;
    return 0;
  }

  /// Coin Match reward.
  /// - win: stake * 2 (entry fee already deducted, so net = +stake)
  /// - draw: stake (refund)
  /// - loss: 0
  static int rewardForCoinMatch({required int stake, required String result}) {
    if (result == 'win') return stake * 2;
    if (result == 'draw') return stake;
    return 0;
  }
}
