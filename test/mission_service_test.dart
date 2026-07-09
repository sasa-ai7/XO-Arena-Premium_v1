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
}
