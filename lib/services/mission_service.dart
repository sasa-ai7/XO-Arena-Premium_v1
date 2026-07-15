import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/keys.dart';
import '../data/missions_catalog.dart';
import '../models/mission.dart';
import 'app_mode_service.dart';
import 'local_store.dart';
import 'wallet_ledger_types.dart';
import 'wallet_transaction_service.dart';

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

  // ── Online / offline mission namespace ───────────────────────────────────
  //
  // Offline and online mission progress are stored under separate keys so an
  // offline event never moves an online mission and vice-versa. Only ONE
  // namespace is loaded in memory at a time — the one matching the current
  // AppMode — so events naturally accrue to the right set. On a mode flip
  // (online↔offline) we reload from the other namespace.
  bool _loadedOffline = false;
  static bool get _offlineNs => AppModeService.current == AppMode.offline;

  String get _kProgress =>
      _offlineNs ? Keys.offlineMissionsProgress : Keys.missionsProgress;
  String get _kClaimed =>
      _offlineNs ? Keys.offlineMissionsClaimed : Keys.missionsClaimed;
  String get _kDedupe =>
      _offlineNs ? Keys.offlineMissionsDedupe : Keys.missionsDedupe;
  String get _kLastDaily =>
      _offlineNs ? Keys.offlineMissionsLastDaily : Keys.missionsLastDaily;
  String get _kWeekId =>
      _offlineNs ? Keys.offlineMissionsWeekId : Keys.missionsWeekId;
  String get _kLoginStreak =>
      _offlineNs ? Keys.offlineMissionsLoginStreak : Keys.missionsLoginStreak;
  String get _kLoginDay =>
      _offlineNs ? Keys.offlineMissionsLoginDay : Keys.missionsLoginDay;

  Map<String, int> _progress = {};
  Map<String, bool> _claimed = {}; // daily/milestone: id ; weekly: id#tierIndex
  Set<String> _dedupe = {}; // eventKey|matchId processed today
  String _lastDaily = '';
  String _weekId = '';
  int _loginStreak = 0; // consecutive-day login streak
  String _loginDay = ''; // last day the streak was counted (yyyy-MM-dd)

  final Set<String> _claiming = {}; // in-memory re-entry guard

  // ── Init + resets ──────────────────────────────────────────────────────
  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    _loadedOffline = _offlineNs;
    try {
      final p = await SharedPreferences.getInstance();
      await _loadFrom(p);
      await _applyResets(p);
    } catch (e) {
      if (kDebugMode) debugPrint('[MISSIONS] init failed: $e');
    }
    // Reload the correct namespace whenever the app flips online↔offline.
    AppModeService.modeNotifier.addListener(_onModeChanged);
    _recompute();
  }

  Future<void> _loadFrom(SharedPreferences p) async {
    _progress = _decodeIntMap(p.getString(_kProgress));
    _claimed = _decodeBoolMap(p.getString(_kClaimed));
    _dedupe = _decodeStringList(p.getString(_kDedupe)).toSet();
    _lastDaily = p.getString(_kLastDaily) ?? '';
    _weekId = p.getString(_kWeekId) ?? '';
    _loginStreak = p.getInt(_kLoginStreak) ?? 0;
    _loginDay = p.getString(_kLoginDay) ?? '';
    if (kDebugMode) {
      debugPrint('[MISSION] loaded namespace offline=$_offlineNs');
    }
  }

  void _onModeChanged() {
    final off = _offlineNs;
    if (off == _loadedOffline) return;
    _loadedOffline = off;
    unawaited(() async {
      final p = await SharedPreferences.getInstance();
      await _loadFrom(p);
      await _applyResets(p);
      _recompute();
    }());
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

    // Consecutive-day login streak (feeds the one-time login milestones). Counts
    // once per calendar day: +1 if yesterday was counted, otherwise resets to 1.
    // Milestone progress never resets, so once a target is reached it stays.
    if (_loginDay != today) {
      _loginStreak = (_loginDay == _yesterdayKey()) ? _loginStreak + 1 : 1;
      _loginDay = today;
      for (final m in kMilestoneMissions) {
        if (m.eventKey == 'login_streak') {
          final cur = _progress[m.id] ?? 0;
          _progress[m.id] = max(cur, min(m.topTarget, _loginStreak));
        }
      }
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

    if (_isOnlineMissionEvent(eventKey) && !_canTrackOnlineMissionEvent) {
      if (kDebugMode) {
        debugPrint(
            '[MISSIONS] blocked online event=$eventKey mode=${AppModeService.current}');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('[MISSION] ${_offlineNs ? 'offline' : 'online'} event '
          'accepted=$eventKey');
    }

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

  /// Adds [amount] to every mission listening on [eventKey] (capped at target).
  /// Used for cumulative goals like "spend 10,000 coins" where each event
  /// contributes a variable amount rather than a single tick. Never credits.
  Future<void> trackAmount(String eventKey, int amount) async {
    if (amount <= 0) return;
    if (!_inited) await init();
    final p = await SharedPreferences.getInstance();
    await _applyResets(p);

    var changed = false;
    for (final def in kAllMissions) {
      if (def.eventKey != eventKey) continue;
      final cur = _progress[def.id] ?? 0;
      final cap = def.topTarget;
      if (cur >= cap) continue;
      _progress[def.id] = min(cap, cur + amount);
      changed = true;
    }

    if (changed) {
      await _persist(p);
      _recompute();
    }
  }

  bool _isOnlineMissionEvent(String eventKey) {
    return eventKey == 'online_room_created' ||
        eventKey == 'online_room_joined_by_code' ||
        eventKey == 'online_match_completed' ||
        eventKey == 'online_match_won';
  }

  bool get _canTrackOnlineMissionEvent {
    if (!AppModeService.canUseOnlineServices) return false;
    if (Firebase.apps.isEmpty) return true;
    return FirebaseAuth.instance.currentUser != null;
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

      // Credit + ledger row are a single canonical transaction. If it did not
      // record (mode guard / no uid), keep the mission unclaimed so the reward
      // is never lost. Idempotent by transactionId — a retry can't double-pay.
      if (reward > 0) {
        final period =
            def.isMilestone ? 'once' : (def.isWeekly ? _weekId : _lastDaily);
        final txId = 'mission_${claimedKey.replaceAll('#', '_t')}_$period';
        final title = def.isWeekly
            ? '${def.titleEn} (T${tierIndex! + 1})'
            : def.titleEn;
        final result = await WalletTransactionService.instance.applyCredit(
          coins: reward,
          transactionId: txId,
          source: def.isWeekly
              ? LedgerType.weeklyReward
              : (def.isMilestone
                  ? LedgerType.missionReward
                  : LedgerType.dailyReward),
          title: title,
          message: title,
        );
        if (!result.success) {
          // Credit did not apply — keep unclaimed for retry.
          return ClaimResult.notAvailable;
        }
      }

      // Milestone avatar reward: grant ownership. Ownership is a set, and the
      // claimed flag below prevents re-entry, so it can never double-grant.
      if (def.rewardAvatarId != null) {
        await LocalStore.addOwnedAvatar(def.rewardAvatarId!);
      }

      // Persist the claim BEFORE logging so a rapid re-tap can't re-credit.
      _claimed[claimedKey] = true;
      await _persist();

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
  List<MissionView> milestoneViews() =>
      kMilestoneMissions.map(_viewOf).toList();

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
    for (final v in milestoneViews()) {
      badge += v.claimableCount;
    }
    badgeCount.value = badge;
    revision.value++;
  }

  Future<void> _persist([SharedPreferences? given]) async {
    final p = given ?? await SharedPreferences.getInstance();
    await p.setString(_kProgress, jsonEncode(_progress));
    await p.setString(_kClaimed, jsonEncode(_claimed));
    await p.setString(_kDedupe, jsonEncode(_dedupe.toList()));
    await p.setString(_kLastDaily, _lastDaily);
    await p.setString(_kWeekId, _weekId);
    await p.setInt(_kLoginStreak, _loginStreak);
    await p.setString(_kLoginDay, _loginDay);
  }

  static String todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Yesterday's date key (used to detect an unbroken login streak).
  static String _yesterdayKey() {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return '${y.year.toString().padLeft(4, '0')}-'
        '${y.month.toString().padLeft(2, '0')}-'
        '${y.day.toString().padLeft(2, '0')}';
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
    _loginStreak = 0;
    _loginDay = '';
    _claiming.clear();
    badgeCount.value = 0;
    revision.value = 0;
  }
}
