import 'package:flutter/material.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../models/mission.dart';
import '../../services/mission_service.dart';
import '../../widgets/app_ui.dart';
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
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      backgroundColor: AppPalette.homeBgBase,
      body: AppBackground(
        variant: AppBackgroundVariant.homeNeon,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, l10n),
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
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                      itemCount: views.length + (daily ? 0 : 1),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (!daily && i == views.length) {
                          return _buildWeeklyFooter(context, l10n);
                        }
                        final v = views[i];
                        return daily
                            ? MissionCard(view: v)
                            : WeeklyMissionCard(view: v);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppL10n l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            color: AppPalette.homeTitle,
            onPressed: () => Navigator.maybePop(context),
          ),
          Image.asset('assets/moh.png',
              width: 34,
              height: 34,
              cacheWidth: 96,
              errorBuilder: (_, __, ___) => Icon(Icons.assignment_rounded,
                  color: AppPalette.homeCyan, size: 28)),
          const SizedBox(width: 10),
          Text(l10n.missionsTitle,
              style: homeTitleFont(context, fontSize: 22)),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context, AppL10n l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: l10n.missionsDailyTab,
              selected: _tab == MissionType.daily,
              onTap: () => setState(() => _tab = MissionType.daily),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _TabButton(
              label: l10n.missionsWeeklyTab,
              selected: _tab == MissionType.weekly,
              onTap: () => setState(() => _tab = MissionType.weekly),
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
  final VoidCallback onTap;
  const _TabButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        ),
        child: Text(label,
            style: safeOrbitron(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: selected ? AppPalette.homeCyan : AppPalette.textMuted)),
      ),
    );
  }
}
