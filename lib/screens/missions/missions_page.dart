import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../models/mission.dart';
import '../../services/mission_service.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/arena_neon_widgets.dart';
import '../referral/enter_invite_code_page.dart';
import '../store/store_page.dart';
import 'mission_widgets.dart';

/// Full Missions screen — يومية (7) / أسبوعية (12) tabs. Same XO Arena style.
class MissionsPage extends StatefulWidget {
  const MissionsPage({super.key});

  @override
  State<MissionsPage> createState() => _MissionsPageState();
}

class _MissionsPageState extends State<MissionsPage> {
  MissionType _tab = MissionType.daily;

  @override
  void initState() {
    super.initState();
    final openedAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ms = DateTime.now().difference(openedAt).inMilliseconds;
      debugPrint('[PERF] missions_page_open_ms=$ms');
    });
  }

  Future<void> _openCoinsStore() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StorePage(initialTab: 2)),
    );
  }

  void _openInviteCode() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EnterInviteCodePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      backgroundColor: AppPalette.homeBgBase,
      body: AppBackground(
        variant: AppBackgroundVariant.homeNeon,
        child: SafeArea(
          child: Directionality(
            textDirection: l10n.isAr ? TextDirection.rtl : TextDirection.ltr,
            child: Column(
              children: [
                XoArenaScreenHeader(
                  onBack: () => Navigator.maybePop(context),
                  onCoinsTap: _openCoinsStore,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.missionsTitle,
                        style: homeTitleFont(context, fontSize: 25),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        l10n.missionsSubtitle,
                        style: homeBodyFont(
                          context,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.homeBody,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildTabs(context, l10n),
                const SizedBox(height: 8),
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: MissionService.instance.revision,
                    builder: (context, _, __) {
                      final daily = _tab == MissionType.daily;
                      final views = daily
                          ? MissionService.instance.dailyViews()
                          : MissionService.instance.weeklyViews();
                      final items = <Widget>[
                        // Invite section pinned to the top of the list so it is
                        // obvious the moment Missions opens — no long scroll.
                        if (AppConfig.kEnableReferralRewards)
                          InviteCodePanel(
                            onEnterCode: _openInviteCode,
                            missionsVariant: true,
                          ),
                        for (final v in views)
                          daily
                              ? MissionCard(view: v)
                              : WeeklyMissionCard(view: v),
                        // One-time achievements/milestones live under the daily
                        // tab so they are visible without an extra tab.
                        if (daily) ...[
                          _buildSectionHeader(
                            context,
                            l10n.milestonesTitle,
                            l10n.milestonesSubtitle,
                          ),
                          for (final v in MissionService.instance
                              .milestoneViews())
                            MissionCard(view: v),
                        ],
                        if (!daily) _buildWeeklyFooter(context, l10n),
                      ];
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => items[i],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs(BuildContext context, AppL10n l10n) {
    return ValueListenableBuilder<int>(
      valueListenable: MissionService.instance.revision,
      builder: (context, _, __) {
        final dailyBadge = MissionService.instance
                .dailyViews()
                .fold<int>(0, (sum, v) => sum + v.claimableCount) +
            MissionService.instance
                .milestoneViews()
                .fold<int>(0, (sum, v) => sum + v.claimableCount);
        final weeklyBadge = MissionService.instance
            .weeklyViews()
            .fold<int>(0, (sum, v) => sum + v.claimableCount);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _TabButton(
                  label: l10n.missionsDailyTab,
                  selected: _tab == MissionType.daily,
                  badgeCount: dailyBadge,
                  onTap: () => setState(() => _tab = MissionType.daily),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TabButton(
                  label: l10n.missionsWeeklyTab,
                  selected: _tab == MissionType.weekly,
                  badgeCount: weeklyBadge,
                  onTap: () => setState(() => _tab = MissionType.weekly),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        children: [
          Icon(Icons.military_tech_rounded,
              size: 18, color: AppPalette.goldHighlight),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: safeOrbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    color: AppPalette.goldHighlight,
                  ),
                ),
                Text(
                  subtitle,
                  style: safeInter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyFooter(BuildContext context, AppL10n l10n) {
    final d = MissionService.instance.untilWeeklyReset();
    final days = d.inDays;
    final hours = d.inHours % 24;
    final allDone = MissionService.instance.allWeeklyDone();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          if (allDone) ...[
            Text(l10n.missionsWeekDone,
                style: safeOrbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.success)),
            const SizedBox(height: 4),
          ],
          Text(l10n.missionRenewsIn(days, hours),
              style: safeInter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.textMuted)),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;
  const _TabButton(
      {required this.label,
      required this.selected,
      required this.badgeCount,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(colors: [
                      AppPalette.homeCyan.withValues(alpha: 0.22),
                      AppPalette.homeBlue.withValues(alpha: 0.12),
                    ])
                  : null,
              color: selected ? null : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppPalette.homeCyan.withValues(alpha: 0.55)
                    : AppPalette.strokeSoft,
                width: selected ? 1.4 : 1.0,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppPalette.homeCyan.withValues(alpha: 0.18),
                        blurRadius: 18,
                        spreadRadius: -7,
                      ),
                    ]
                  : null,
            ),
            child: Text(label,
                style: safeOrbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color:
                        selected ? AppPalette.homeCyan : AppPalette.textMuted)),
          ),
          if (badgeCount > 0)
            PositionedDirectional(
              top: -7,
              end: 10,
              child: MissionBadge(count: badgeCount),
            ),
        ],
      ),
    );
  }
}
