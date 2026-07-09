import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/keys.dart';
import '../data/missions_catalog.dart';
import '../models/mission.dart';
import 'app_mode_service.dart';
import 'local_store.dart';
import 'wallet_ledger_types.dart';

enum ClaimResult {
  success,
  alreadyClaimed,
  notReady,
  notAvailable, // wallet not creditable right now (transient mode) — retry later
  busy,
  error,
}

/// Central Missions/Quests tracker. Coins-only, local-only state.
///
/// - Progress accrues via [trackEvent] (never credits coins).
/// - Rewards are added ONLY via [claim] (manual). Double-credit is guarded by
///   the persisted claimed flag + a credit-then-verify order + ledger idempotency.
/// - Daily missions reset each new day; weekly missions reset each new week
///   (Monday 00:00) and do NOT reset on completion.
class MissionService {
  MissionService._();
  static final MissionService instance = MissionService._();

  /// Bumped on every state change so widgets can rebuild.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Number of completed-but-unclaimed rewards (daily + weekly tiers).
  final ValueNotifier<int> badgeCount = ValueNotifier<int>(0);

  bool _inited = false;
  bool get inited => _inited;

  Map<String, int> _progress = {};
  Map<String, bool> _claimed = {}; // daily: id ; weekly: id#tierIndex
  Set<String> _dedupe = {}; // eventKey|matchId processed today
  String _lastDaily = '';
  String _weekId = '';

  final Set<String> _claiming = {}; // in-memory re-entry guard

  // ── Init + resets ──────────────────────────────────────────────────────
  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      final p = await SharedPreferences.getInstance();
      _progress = _decodeIntMap(p.getString(Keys.missionsProgress));
      _claimed = _decodeBoolMap(p.getString(Keys.missionsClaimed));
      _dedupe = _decodeStringList(p.getString(Keys.missionsDedupe)).toSet();
      _lastDaily = p.getString(Keys.missionsLastDaily) ?? '';
      _weekId = p.getString(Keys.missionsWeekId) ?? '';
      await _applyResets(p);
    } catch (e) {
      if (kDebugMode) debugPrint('[MISSIONS] init failed: $e');
    }
    _recompute();
  }

  Future<void> _applyResets(SharedPreferences p) async {
    final today = todayKey();
    final week = weekKey();
    var changed = false;

    if (_lastDaily != today) {
      for (final d in kDailyMissions) {
        _progress.remove(d.id);
        _claimed.remove(d.id);
      }
      // Arm daily_login as completed-but-unclaimed (never auto-credit).
      _progress['daily_login'] = 1;
      _dedupe.clear();
      _lastDaily = today;
      changed = true;
    }

    if (_weekId != week) {
      for (final w in kWeeklyMissions) {
        _progress.remove(w.id);
        for (var i = 0; i < w.tiers.length; i++) {
          _claimed.remove('${w.id}#$i');
        }
      }
      _weekId = week;
      changed = true;
    }

    if (changed) await _persist(p);
  }

  // ── Event tracking (never credits) ─────────────────────────────────────
  Future<void> trackEvent(String eventKey, {String? matchId}) async {
    if (!_inited) await init();
    // Refresh resets in case the app stayed open across midnight / week roll.
    final p = await SharedPreferences.getInstance();
    await _applyResets(p);

    if (matchId != null && matchId.isNotEmpty) {
      final dk = '$eventKey|$matchId';
      if (_dedupe.contains(dk)) return; // already counted this match's event
      _dedupe.add(dk);
    }

    var changed = false;
    for (final def in kAllMissions) {
      if (def.eventKey != eventKey) continue;
      final cur = _progress[def.id] ?? 0;
      final cap = def.topTarget;
      if (cur >= cap) continue;
      _progress[def.id] = min(cap, cur + 1);
      changed = true;
    }

    if (changed || matchId != null) {
      await _persist(p);
      _recompute();
    }
  }

  // ── Claim (the ONLY coin-crediting path) ───────────────────────────────
  Future<ClaimResult> claim(String missionId, {int? tierIndex}) async {
    if (!_inited) await init();
    final def = _defById(missionId);
    if (def == null) return ClaimResult.error;

    final guardKey = tierIndex == null ? missionId : '$missionId#$tierIndex';
    if (_claiming.contains(guardKey)) return ClaimResult.busy;
    _claiming.add(guardKey);
    try {
      final progress = _progress[missionId] ?? 0;
      final int target;
      final int reward;
      final String claimedKey;
      if (def.isWeekly) {
        if (tierIndex == null ||
            tierIndex < 0 ||
            tierIndex >= def.tiers.length) {
          return ClaimResult.error;
        }
        target = def.tiers[tierIndex].target;
        reward = def.tiers[tierIndex].rewardCoins;
        claimedKey = '$missionId#$tierIndex';
      } else {
        target = def.target;
        reward = def.rewardCoins;
        claimedKey = missionId;
      }

      if (_claimed[claimedKey] == true) return ClaimResult.alreadyClaimed;
      if (progress < target) return ClaimResult.notReady;

      // Only credit when the wallet is actually writable, so a blocked credit
      // never marks the mission claimed (reward would be lost otherwise).
      final creditable = AppModeService.current == AppMode.offline ||
          AppModeService.canUseOnlineServices;
      if (!creditable) return ClaimResult.notAvailable;

      final before = LocalStore.coinsNotifier.value;
      await LocalStore.updateCoins(reward);
      final after = LocalStore.coinsNotifier.value;
      if (after <= before) {
        // Credit did not apply (mode guard) — keep unclaimed for retry.
        return ClaimResult.notAvailable;
      }

      // Persist the claim BEFORE logging so a rapid re-tap can't re-credit.
      _claimed[claimedKey] = true;
      await _persist();

      final period = def.isWeekly ? _weekId : _lastDaily;
      final txId = 'mission_${claimedKey.replaceAll('#', '_t')}_$period';
      await LocalStore.addTopupHistory(
        usd: 0.0,
        coins: reward,
        type: 'win', // marks a credit in the ledger
        source: LedgerType.missionReward,
        description:
            def.isWeekly ? '${def.titleEn} (T${tierIndex! + 1})' : def.titleEn,
        transactionId: txId,
        balanceBefore: before,
        balanceAfter: after,
      );

      _recompute();
      return ClaimResult.success;
    } catch (e) {
      if (kDebugMode) debugPrint('[MISSIONS] claim failed: $e');
      return ClaimResult.error;
    } finally {
      _claiming.remove(guardKey);
    }
  }

  // ── Views for UI ───────────────────────────────────────────────────────
  MissionView _viewOf(MissionDef def) {
    final progress = _progress[def.id] ?? 0;
    if (def.isWeekly) {
      final tc = [
        for (var i = 0; i < def.tiers.length; i++)
          _claimed['${def.id}#$i'] ?? false,
      ];
      return MissionView(def: def, progress: progress, tierClaimed: tc);
    }
    return MissionView(
      def: def,
      progress: progress,
      dailyClaimed: _claimed[def.id] ?? false,
    );
  }

  List<MissionView> dailyViews() => kDailyMissions.map(_viewOf).toList();
  List<MissionView> weeklyViews() => kWeeklyMissions.map(_viewOf).toList();

  MissionView? viewFor(String missionId) {
    final def = _defById(missionId);
    return def == null ? null : _viewOf(def);
  }

  /// The single mission to surface on the Home preview for [type]:
  /// first claimable → else nearest in-progress → else null (all done).
  MissionView? previewFor(MissionType type) {
    final views = type == MissionType.daily ? dailyViews() : weeklyViews();
    for (final v in views) {
      if (v.claimableCount > 0) return v;
    }
    MissionView? best;
    int? bestRemaining;
    for (final v in views) {
      if (v.fullyClaimed) continue;
      if (v.progress >= v.def.topTarget) continue;
      final nextTarget = type == MissionType.daily
          ? v.def.target
          : v.def.tiers[v.activeTierIndex].target;
      final remaining = nextTarget - v.progress;
      if (bestRemaining == null || remaining < bestRemaining) {
        bestRemaining = remaining;
        best = v;
      }
    }
    return best;
  }

  bool allDailyDone() => dailyViews().every((v) => v.progress >= v.def.target);
  bool allWeeklyDone() =>
      weeklyViews().every((v) => v.progress >= v.def.topTarget);

  /// Overall weekly progress as claimed-tiers / total-tiers (for the strip).
  double weeklyProgressFraction() {
    var reached = 0;
    var total = 0;
    for (final w in kWeeklyMissions) {
      final prog = _progress[w.id] ?? 0;
      for (final t in w.tiers) {
        total++;
        if (prog >= t.target) reached++;
      }
    }
    return total == 0 ? 0 : reached / total;
  }

  /// Time until the next weekly reset (next Monday 00:00).
  Duration untilWeeklyReset() {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final nextWeek = startOfWeek.add(const Duration(days: 7));
    return nextWeek.difference(now);
  }

  // ── Internals ──────────────────────────────────────────────────────────
  MissionDef? _defById(String id) {
    for (final d in kAllMissions) {
      if (d.id == id) return d;
    }
    return null;
  }

  void _recompute() {
    var badge = 0;
    for (final v in dailyViews()) {
      badge += v.claimableCount;
    }
    for (final v in weeklyViews()) {
      badge += v.claimableCount;
    }
    badgeCount.value = badge;
    revision.value++;
  }

  Future<void> _persist([SharedPreferences? given]) async {
    final p = given ?? await SharedPreferences.getInstance();
    await p.setString(Keys.missionsProgress, jsonEncode(_progress));
    await p.setString(Keys.missionsClaimed, jsonEncode(_claimed));
    await p.setString(Keys.missionsDedupe, jsonEncode(_dedupe.toList()));
    await p.setString(Keys.missionsLastDaily, _lastDaily);
    await p.setString(Keys.missionsWeekId, _weekId);
  }

  static String todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Monday-of-current-week date, used as the weekly bucket id.
  static String weekKey() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return '${monday.year.toString().padLeft(4, '0')}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }

  Map<String, int> _decodeIntMap(String? s) {
    if (s == null || s.isEmpty) return {};
    try {
      return (jsonDecode(s) as Map)
          .map((k, v) => MapEntry(k as String, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Map<String, bool> _decodeBoolMap(String? s) {
    if (s == null || s.isEmpty) return {};
    try {
      return (jsonDecode(s) as Map)
          .map((k, v) => MapEntry(k as String, v == true));
    } catch (_) {
      return {};
    }
  }

  List<String> _decodeStringList(String? s) {
    if (s == null || s.isEmpty) return [];
    try {
      return (jsonDecode(s) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Test-only reset of the in-memory singleton state.
  @visibleForTesting
  void resetForTest() {
    _inited = false;
    _progress = {};
    _claimed = {};
    _dedupe = {};
    _lastDaily = '';
    _weekId = '';
    _claiming.clear();
    badgeCount.value = 0;
    revision.value = 0;
  }
}
