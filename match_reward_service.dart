import 'package:flutter/foundation.dart';

import '../main.dart' show LocalStore;

/// Result from match reward calculation.
class MatchRewardResult {
  final bool ok;
  final int coinsAwarded;
  final int? newBalance;
  final String? error;

  const MatchRewardResult({
    required this.ok,
    required this.coinsAwarded,
    this.newBalance,
    this.error,
  });

  factory MatchRewardResult.failure(String error) => MatchRewardResult(
        ok: false,
        coinsAwarded: 0,
        error: error,
      );
}

/// Reward tables — matches the original server-side formulas exactly.
const _aiFreeRewards = <String, int>{
  'easy': 0,
  'medium': 10,
  'hard': 15,
};

int _levelCampaignReward(int level) {
  if (level == 20) return 500;
  if (level == 10) return 100;
  if (level >= 11 && level <= 19) return 15;
  if (level >= 1 && level <= 9) return 10;
  return 0;
}

/// Service for reporting match results and granting coin rewards.
///
/// Rewards are calculated **locally** and written directly to Firestore
/// via [LocalStore.updateCoins] (no Cloud Function middleman).
/// IAP purchases remain server-verified for security.
class MatchRewardService {
  static final MatchRewardService _instance = MatchRewardService._();
  factory MatchRewardService() => _instance;
  MatchRewardService._();

  /// Report a match result and grant the appropriate coin reward.
  ///
  /// [matchType]: 'coin_match' | 'ai_free' | 'level_campaign'
  /// [result]: 'win' | 'draw' | 'loss'
  /// [entryFee]: Required for coin_match (the fee the player staked)
  /// [difficulty]: Required for ai_free ('easy' / 'medium' / 'hard')
  /// [level]: Required for level_campaign (1-20)
  Future<MatchRewardResult> reportMatchResult({
    required String matchType,
    required String result,
    int? entryFee,
    String? difficulty,
    int? level,
  }) async {
    // 1. Calculate reward locally
    final reward = _calculateReward(
      matchType: matchType,
      result: result,
      entryFee: entryFee,
      difficulty: difficulty,
      level: level,
    );

    if (kDebugMode) {
      debugPrint('[MatchReward] $matchType/$result → reward=$reward');
    }

    // 2. Update coins: local + Firestore in one call (handles guest/offline)
    if (reward > 0) {
      final balanceBefore = await LocalStore.coins();
      await LocalStore.updateCoins(reward);
      final balanceAfter = balanceBefore + reward;

      // Determine description based on match type
      String desc;
      if (matchType == 'coin_match') {
        desc = result == 'draw' ? 'Game Draw Refund' : 'Game Win';
      } else if (matchType == 'ai_free') {
        desc = 'AI Match Win';
      } else if (matchType == 'level_campaign') {
        desc = 'Level Game Win';
      } else {
        desc = 'Game Win';
      }

      await LocalStore.addTopupHistory(
        usd: 0.0,
        coins: reward,
        type: 'win',
        description: desc,
        balanceBefore: balanceBefore,
        balanceAfter: balanceAfter,
      );
    }

    final balance = await LocalStore.coins();
    return MatchRewardResult(
      ok: true,
      coinsAwarded: reward,
      newBalance: balance,
    );
  }

  /// Pure function: compute reward from match parameters.
  int _calculateReward({
    required String matchType,
    required String result,
    int? entryFee,
    String? difficulty,
    int? level,
  }) {
    if (matchType == 'coin_match') {
      final fee = entryFee ?? 0;
      if (fee <= 0 || fee > 10000) return 0;
      if (result == 'win') return fee * 2;
      if (result == 'draw') return fee; // refund
      return 0; // loss
    }

    if (matchType == 'ai_free') {
      if (result != 'win') return 0;
      return _aiFreeRewards[difficulty] ?? 0;
    }

    if (matchType == 'level_campaign') {
      if (result != 'win') return 0;
      return _levelCampaignReward(level ?? 0);
    }

    return 0;
  }
}
