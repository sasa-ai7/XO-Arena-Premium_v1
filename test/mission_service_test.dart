import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xo_arena_neon_clash/data/missions_catalog.dart';
import 'package:xo_arena_neon_clash/models/mission.dart';
import 'package:xo_arena_neon_clash/services/mission_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final svc = MissionService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    svc.resetForTest();
    await svc.init();
  });

  group('catalog integrity', () {
    test('exactly 7 daily and 12 weekly missions', () {
      expect(kDailyMissions.length, 7);
      expect(kWeeklyMissions.length, 12);
      for (final w in kWeeklyMissions) {
        expect(w.tiers.length, 3, reason: '${w.id} must have 3 tiers');
      }
    });

    test('daily total = 400, weekly total = 47,200', () {
      final daily = kDailyMissions.fold<int>(0, (s, m) => s + m.rewardCoins);
      final weekly = kWeeklyMissions.fold<int>(
          0, (s, m) => s + m.tiers.fold<int>(0, (t, x) => t + x.rewardCoins));
      expect(daily, 400);
      expect(weekly, 47200);
    });

    test('unique ids across daily + weekly', () {
      final ids = kAllMissions.map((m) => m.id).toSet();
      expect(ids.length, kAllMissions.length);
    });
  });

  group('daily_login arming', () {
    test('daily_login is completed-but-unclaimed after init (badge >= 1)', () {
      final login = svc.viewFor('daily_login')!;
      expect(login.dailyCompleted, isTrue);
      expect(login.dailyClaimed, isFalse);
      expect(login.dailyClaimable, isTrue);
      expect(svc.badgeCount.value, greaterThanOrEqualTo(1));
    });
  });

  group('trackEvent', () {
    test('any_match_completed increments daily_play3 and weekly_play', () async {
      await svc.trackEvent('any_match_completed');
      await svc.trackEvent('any_match_completed');
      await svc.trackEvent('any_match_completed');
      expect(svc.viewFor('daily_play3')!.progress, 3);
      expect(svc.viewFor('daily_play3')!.dailyClaimable, isTrue);
      expect(svc.viewFor('weekly_play')!.progress, 3);
      // weekly_play tier 1 target is 10 → not yet claimable
      expect(svc.viewFor('weekly_play')!.tierClaimable(0), isFalse);
    });

    test('ai_win_hard increments only hard daily/weekly, not easy/medium',
        () async {
      await svc.trackEvent('ai_win_hard');
      expect(svc.viewFor('daily_ai_hard')!.progress, 1);
      expect(svc.viewFor('daily_ai_easy')!.progress, 0);
      expect(svc.viewFor('daily_ai_medium')!.progress, 0);
      expect(svc.viewFor('weekly_ai_hard')!.progress, 1);
      expect(svc.viewFor('weekly_ai_easy')!.progress, 0);
    });

    test('progress caps at the top target', () async {
      for (var i = 0; i < 60; i++) {
        await svc.trackEvent('any_match_completed');
      }
      // daily target 3, weekly top tier 50
      expect(svc.viewFor('daily_play3')!.progress, 3);
      expect(svc.viewFor('weekly_play')!.progress, 50);
    });

    test('matchId dedupe prevents double count', () async {
      await svc.trackEvent('online_match_completed', matchId: 'room-1');
      await svc.trackEvent('online_match_completed', matchId: 'room-1');
      expect(svc.viewFor('weekly_online_complete')!.progress, 1);
      // a different match counts again
      await svc.trackEvent('online_match_completed', matchId: 'room-2');
      expect(svc.viewFor('weekly_online_complete')!.progress, 2);
    });
  });

  group('MissionView computed states', () {
    test('weekly tier claimable + fullyClaimed logic', () {
      final def = kWeeklyMissions.firstWhere((m) => m.id == 'weekly_ai_hard');
      // tiers: 1 / 3 / 6
      final v = MissionView(
        def: def,
        progress: 3,
        tierClaimed: const [true, false, false],
      );
      expect(v.tierReached(0), isTrue);
      expect(v.tierIsClaimed(0), isTrue);
      expect(v.tierClaimable(0), isFalse); // reached but already claimed
      expect(v.tierClaimable(1), isTrue); // reached (3>=3), unclaimed
      expect(v.tierClaimable(2), isFalse); // not reached (3<6)
      expect(v.claimableCount, 1);
      expect(v.weeklyAllClaimed, isFalse);

      final allDone = MissionView(
        def: def,
        progress: 6,
        tierClaimed: const [true, true, true],
      );
      expect(allDone.weeklyAllClaimed, isTrue);
      expect(allDone.fullyClaimed, isTrue);
      expect(allDone.claimableCount, 0);
    });
  });

  group('previewFor', () {
    test('surfaces a claimable mission first', () {
      // daily_login is claimable right after init
      final preview = svc.previewFor(MissionType.daily);
      expect(preview, isNotNull);
      expect(preview!.claimableCount, greaterThan(0));
    });
  });

  group('milestones', () {
    test('catalog: 6 one-time milestones, all included in kAllMissions', () {
      expect(kMilestoneMissions.length, 6);
      for (final m in kMilestoneMissions) {
        expect(m.type, MissionType.milestone);
        expect(kAllMissions.contains(m), isTrue);
      }
    });

    test('7-day login milestone grants the free Avatar__7 frame', () {
      final m =
          kMilestoneMissions.firstWhere((m) => m.id == 'milestone_login_7day');
      expect(m.target, 7);
      expect(m.rewardAvatarId, 7);
      expect(m.rewardCoins, 0); // avatar-only reward
    });

    test('login streak is armed to 1 on first launch', () {
      // _applyResets ran in init(): first-ever day → streak 1.
      expect(svc.viewFor('milestone_login_7day')!.progress, 1);
    });

    test('trackAmount accumulates coins_spent and caps at target', () async {
      await svc.trackAmount('coins_spent', 4000);
      expect(svc.viewFor('milestone_spend_coins')!.progress, 4000);
      await svc.trackAmount('coins_spent', 4000);
      expect(svc.viewFor('milestone_spend_coins')!.progress, 8000);
      // Overshoot caps at the 10,000 target.
      await svc.trackAmount('coins_spent', 9999);
      expect(svc.viewFor('milestone_spend_coins')!.progress, 10000);
      expect(svc.viewFor('milestone_spend_coins')!.dailyCompleted, isTrue);
    });

    test('trackAmount ignores non-positive amounts', () async {
      await svc.trackAmount('coins_spent', 0);
      await svc.trackAmount('coins_spent', -50);
      expect(svc.viewFor('milestone_spend_coins')!.progress, 0);
    });

    test('single-tick milestones complete on their event', () async {
      await svc.trackEvent('theme_bought');
      expect(svc.viewFor('milestone_buy_theme')!.dailyClaimable, isTrue);

      await svc.trackEvent('avatar_equipped');
      expect(svc.viewFor('milestone_equip_avatar')!.progress, 1);

      await svc.trackEvent('premium_avatar_bought');
      expect(svc.viewFor('milestone_buy_premium_avatar')!.progress, 1);

      await svc.trackEvent('friend_invited');
      expect(svc.viewFor('milestone_invite_friend')!.progress, 1);
    });

    test('milestone tick is capped (not exploitable by repeat events)',
        () async {
      for (var i = 0; i < 5; i++) {
        await svc.trackEvent('avatar_equipped');
      }
      expect(svc.viewFor('milestone_equip_avatar')!.progress, 1);
    });
  });
}
