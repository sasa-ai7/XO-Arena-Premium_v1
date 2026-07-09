/// Missions / Quests domain model.
///
/// Rewards are COINS ONLY (no XP / gems / season). Definitions are static
/// (see `lib/data/missions_catalog.dart`); the mutable per-player progress and
/// claim state lives in `MissionService` (local SharedPreferences).
library;

enum MissionType { daily, weekly }

/// Where a mission's "اذهب" (go) button routes the player.
enum MissionRoute {
  none, // daily_login — claim only, opens nothing
  home,
  vsAi,
  vsFriend,
  levels,
  onlineCreate,
  onlineJoin,
  online,
}

/// A single weekly tier: reach [target] to claim [rewardCoins].
class MissionTier {
  final int target;
  final int rewardCoins;
  const MissionTier({required this.target, required this.rewardCoins});
}

/// Immutable catalog definition of one mission.
class MissionDef {
  final String id;
  final MissionType type;
  final String eventKey;
  final MissionRoute route;
  final String titleAr;
  final String titleEn;

  /// Daily only.
  final int target;
  final int rewardCoins;

  /// Weekly only (exactly 3 tiers).
  final List<MissionTier> tiers;

  const MissionDef({
    required this.id,
    required this.type,
    required this.eventKey,
    required this.route,
    required this.titleAr,
    required this.titleEn,
    this.target = 0,
    this.rewardCoins = 0,
    this.tiers = const [],
  });

  bool get isWeekly => type == MissionType.weekly;

  /// The maximum meaningful progress value (daily target or top weekly tier).
  int get topTarget => isWeekly ? tiers.last.target : target;

  String title(bool isAr) => isAr ? titleAr : titleEn;
}

/// A live view combining a [def] with the player's current progress/claim
/// state. Built by `MissionService`; consumed by the UI.
class MissionView {
  final MissionDef def;
  final int progress;

  /// Daily: single claimed flag. Weekly: one flag per tier.
  final bool dailyClaimed;
  final List<bool> tierClaimed;

  const MissionView({
    required this.def,
    required this.progress,
    this.dailyClaimed = false,
    this.tierClaimed = const [],
  });

  // ── Daily helpers ──────────────────────────────────────────────────────
  bool get dailyCompleted => !def.isWeekly && progress >= def.target;
  bool get dailyClaimable => dailyCompleted && !dailyClaimed;

  // ── Weekly helpers ─────────────────────────────────────────────────────
  bool tierReached(int i) => progress >= def.tiers[i].target;
  bool tierIsClaimed(int i) => i < tierClaimed.length && tierClaimed[i];
  bool tierClaimable(int i) => tierReached(i) && !tierIsClaimed(i);
  bool get weeklyAllClaimed =>
      def.isWeekly && tierClaimed.isNotEmpty && tierClaimed.every((c) => c);

  /// Index of the next tier the player is working toward (or last tier if all
  /// reached). Used for the progress bar denominator.
  int get activeTierIndex {
    for (var i = 0; i < def.tiers.length; i++) {
      if (!tierReached(i)) return i;
    }
    return def.tiers.length - 1;
  }

  /// Number of claimable-but-unclaimed rewards this mission contributes to the
  /// notification badge.
  int get claimableCount {
    if (!def.isWeekly) return dailyClaimable ? 1 : 0;
    var n = 0;
    for (var i = 0; i < def.tiers.length; i++) {
      if (tierClaimable(i)) n++;
    }
    return n;
  }

  /// True once every reward this mission can ever give has been claimed.
  bool get fullyClaimed => def.isWeekly ? weeklyAllClaimed : dailyClaimed;
}
