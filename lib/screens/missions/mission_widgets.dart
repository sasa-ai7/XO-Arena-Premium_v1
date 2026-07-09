import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../core/coin_format.dart';
import '../../models/mission.dart';
import '../../services/mission_service.dart';
import '../../utils/navigation_utils.dart';
import '../../widgets/app_ui.dart';
import '../arena/arena_create_room_page.dart';
import '../arena/arena_join_room_page.dart';
import '../arena/arena_page.dart';
import '../games/friend_setup_page.dart';
import '../games/level_game_setup_page.dart';
import '../games/setup_page.dart';

bool missionIsGuest() => FirebaseAuth.instance.currentUser == null;

/// Coin icon used across mission cards.
Widget missionCoin(double size) => Image.asset(
      'assets/coin/COIN.png',
      width: size,
      height: size,
      cacheWidth: (size * 3).round(),
      errorBuilder: (_, __, ___) =>
          Icon(Icons.monetization_on, size: size, color: AppPalette.gold),
    );

IconData missionIconFor(MissionDef def) {
  switch (def.route) {
    case MissionRoute.vsAi:
      return Icons.smart_toy_rounded;
    case MissionRoute.vsFriend:
      return Icons.handshake_rounded;
    case MissionRoute.levels:
      return Icons.emoji_events_rounded;
    case MissionRoute.onlineCreate:
      return Icons.add_circle_outline_rounded;
    case MissionRoute.onlineJoin:
      return Icons.vpn_key_rounded;
    case MissionRoute.online:
      return Icons.public_rounded;
    case MissionRoute.home:
      return Icons.sports_esports_rounded;
    case MissionRoute.none:
      return Icons.wb_sunny_rounded;
  }
}

Color missionAccentFor(MissionDef def) {
  switch (def.route) {
    case MissionRoute.vsAi:
      return AppPalette.homeCyan;
    case MissionRoute.vsFriend:
      return AppPalette.homePurple;
    case MissionRoute.levels:
      return AppPalette.homeSky;
    case MissionRoute.onlineCreate:
    case MissionRoute.onlineJoin:
    case MissionRoute.online:
      return AppPalette.homeGold;
    case MissionRoute.home:
      return AppPalette.homeBlue;
    case MissionRoute.none:
      return AppPalette.goldHighlight;
  }
}

/// Navigate to the screen a mission's "اذهب" button targets. Online routes are
/// gated for guests with the shared sign-in dialog (never start online blindly).
void navigateMissionRoute(BuildContext context, MissionRoute route) {
  Widget? page;
  var onlineGated = false;
  switch (route) {
    case MissionRoute.none:
    case MissionRoute.home:
      return; // nothing to open
    case MissionRoute.vsAi:
      page = const SetupPage();
      break;
    case MissionRoute.vsFriend:
      page = const FriendSetupPage();
      break;
    case MissionRoute.levels:
      page = const LevelGameSetupPage();
      break;
    case MissionRoute.onlineCreate:
      page = const ArenaCreateRoomPage();
      onlineGated = true;
      break;
    case MissionRoute.onlineJoin:
      page = const ArenaJoinRoomPage();
      onlineGated = true;
      break;
    case MissionRoute.online:
      page = const ArenaPage();
      onlineGated = true;
      break;
  }
  if (onlineGated && missionIsGuest()) {
    showSignInRequiredDialog(context);
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page!));
}

/// Claim a mission (or weekly tier) and surface the result as a SnackBar.
Future<void> handleMissionClaim(BuildContext context, String missionId,
    {int? tierIndex}) async {
  final l10n = AppL10n.of(context);
  final res =
      await MissionService.instance.claim(missionId, tierIndex: tierIndex);
  if (!context.mounted) return;
  String? msg;
  switch (res) {
    case ClaimResult.success:
      msg = l10n.missionRewardClaimed;
      break;
    case ClaimResult.alreadyClaimed:
      msg = l10n.missionAlreadyClaimed;
      break;
    case ClaimResult.notAvailable:
      msg = l10n.missionClaimRetry;
      break;
    case ClaimResult.notReady:
    case ClaimResult.busy:
    case ClaimResult.error:
      msg = null;
      break;
  }
  if (msg == null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, textAlign: TextAlign.center),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppPalette.homePanelStrong,
    ),
  );
}

/// Red notification badge showing claimable-reward count; hidden when 0.
class MissionBadge extends StatelessWidget {
  final int count;
  const MissionBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: AppPalette.danger,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppPalette.danger.withValues(alpha: 0.55),
            blurRadius: 8,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: safeOrbitron(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Slim neon progress bar.
class MissionProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  const MissionProgressBar({super.key, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          Container(height: 7, color: AppPalette.panelDeep),
          FractionallySizedBox(
            widthFactor: v == 0 ? 0.001 : v,
            child: Container(
              height: 7,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.65), color],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ActionKind { go, claim, done }

class _MissionActionButton extends StatelessWidget {
  final _ActionKind kind;
  final VoidCallback? onTap;
  const _MissionActionButton({required this.kind, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    late final String label;
    late final Color fill;
    late final Color textColor;
    switch (kind) {
      case _ActionKind.go:
        label = l10n.missionGo;
        fill = AppPalette.homeCyan.withValues(alpha: 0.16);
        textColor = AppPalette.homeCyan;
        break;
      case _ActionKind.claim:
        label = l10n.missionClaim;
        fill = AppPalette.success.withValues(alpha: 0.22);
        textColor = AppPalette.success;
        break;
      case _ActionKind.done:
        label = l10n.missionClaimedDone;
        fill = Colors.white.withValues(alpha: 0.05);
        textColor = AppPalette.textSubtle;
        break;
    }
    return GestureDetector(
      onTap: kind == _ActionKind.done ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 66),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: textColor.withValues(alpha: 0.45)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: safeOrbitron(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

/// Daily mission row card.
class MissionCard extends StatelessWidget {
  final MissionView view;
  const MissionCard({super.key, required this.view});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final def = view.def;
    final accent = missionAccentFor(def);
    final _ActionKind kind = view.dailyClaimed
        ? _ActionKind.done
        : (view.dailyClaimable ? _ActionKind.claim : _ActionKind.go);
    return AppGlassCard(
      padding: const EdgeInsets.all(12),
      radius: 22,
      borderColor: accent.withValues(alpha: 0.32),
      child: Row(
        children: [
          _IconBox(icon: missionIconFor(def), accent: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.title(l10n.isAr),
                  style: safeInter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.homeTitle),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 7),
                MissionProgressBar(
                    value: def.target == 0 ? 0 : view.progress / def.target,
                    color: accent),
                const SizedBox(height: 6),
                Row(
                  children: [
                    missionCoin(15),
                    const SizedBox(width: 4),
                    Text('+${formatCoins(def.rewardCoins)}',
                        style: safeOrbitron(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.gold)),
                    const Spacer(),
                    Text('${view.progress}/${def.target}',
                        style: safeInter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _MissionActionButton(
            kind: kind,
            onTap: () {
              if (kind == _ActionKind.claim) {
                handleMissionClaim(context, def.id);
              } else if (kind == _ActionKind.go) {
                navigateMissionRoute(context, def.route);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Weekly mission card with 3 tier chips.
class WeeklyMissionCard extends StatelessWidget {
  final MissionView view;
  const WeeklyMissionCard({super.key, required this.view});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final def = view.def;
    final accent = missionAccentFor(def);
    final topTarget = def.topTarget;
    return AppGlassCard(
      padding: const EdgeInsets.all(14),
      radius: 22,
      borderColor: accent.withValues(alpha: 0.32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBox(icon: missionIconFor(def), accent: accent, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  def.title(l10n.isAr),
                  style: safeInter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.homeTitle),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (view.weeklyAllClaimed)
                Text(l10n.missionCompleted,
                    style: safeOrbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.success)),
            ],
          ),
          const SizedBox(height: 10),
          MissionProgressBar(
              value: topTarget == 0 ? 0 : view.progress / topTarget,
              color: accent),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text('${view.progress}/$topTarget',
                style: safeInter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textMuted)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < def.tiers.length; i++) ...[
                Expanded(
                  child: _TierChip(
                    tier: def.tiers[i],
                    reached: view.tierReached(i),
                    claimed: view.tierIsClaimed(i),
                    claimable: view.tierClaimable(i),
                    accent: accent,
                    onClaim: () =>
                        handleMissionClaim(context, def.id, tierIndex: i),
                  ),
                ),
                if (i < def.tiers.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  final MissionTier tier;
  final bool reached;
  final bool claimed;
  final bool claimable;
  final Color accent;
  final VoidCallback onClaim;
  const _TierChip({
    required this.tier,
    required this.reached,
    required this.claimed,
    required this.claimable,
    required this.accent,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final Color border;
    final Color bg;
    if (claimed) {
      border = AppPalette.success.withValues(alpha: 0.5);
      bg = AppPalette.success.withValues(alpha: 0.10);
    } else if (claimable) {
      border = AppPalette.gold.withValues(alpha: 0.8);
      bg = AppPalette.gold.withValues(alpha: 0.14);
    } else {
      border = AppPalette.strokeSoft;
      bg = AppPalette.panelDeep.withValues(alpha: 0.5);
    }
    return GestureDetector(
      onTap: claimable ? onClaim : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${tier.target}',
                style: safeOrbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: reached ? AppPalette.homeTitle : AppPalette.textMuted)),
            const SizedBox(height: 3),
            FittedBox(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  missionCoin(11),
                  const SizedBox(width: 2),
                  Text('${tier.rewardCoins}',
                      style: safeInter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.gold)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            if (claimed)
              Icon(Icons.check_circle, size: 15, color: AppPalette.success)
            else if (claimable)
              Text(l10n.missionClaim,
                  style: safeOrbitron(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: AppPalette.gold))
            else
              Icon(Icons.lock_outline,
                  size: 13, color: AppPalette.textSubtle.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final double size;
  const _IconBox({required this.icon, required this.accent, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Icon(icon, color: accent, size: size * 0.5),
    );
  }
}

/// Compact Home preview: one mission for the selected daily/weekly tab.
class MissionPreviewPanel extends StatefulWidget {
  final VoidCallback onViewAll;
  const MissionPreviewPanel({super.key, required this.onViewAll});

  @override
  State<MissionPreviewPanel> createState() => _MissionPreviewPanelState();
}

class _MissionPreviewPanelState extends State<MissionPreviewPanel> {
  MissionType _tab = MissionType.daily;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: MissionService.instance.revision,
      builder: (context, _, __) {
        final preview = MissionService.instance.previewFor(_tab);
        return AppGlassCard(
          padding: const EdgeInsets.all(14),
          radius: 24,
          borderColor: AppPalette.homeStroke,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.assignment_turned_in_rounded,
                      size: 18, color: AppPalette.homeCyan),
                  const SizedBox(width: 8),
                  Text(l10n.missionsTitle,
                      style: homeLabelFont(context,
                          fontSize: 12, color: AppPalette.homeCyan)),
                  const Spacer(),
                  _MiniTab(
                    label: l10n.missionsDailyTab,
                    selected: _tab == MissionType.daily,
                    onTap: () => setState(() => _tab = MissionType.daily),
                  ),
                  const SizedBox(width: 6),
                  _MiniTab(
                    label: l10n.missionsWeeklyTab,
                    selected: _tab == MissionType.weekly,
                    onTap: () => setState(() => _tab = MissionType.weekly),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (preview == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.celebration_rounded,
                          color: AppPalette.success, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _tab == MissionType.daily
                            ? l10n.missionsDayDone
                            : l10n.missionsWeekDone,
                        style: safeInter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.success),
                      ),
                    ],
                  ),
                )
              else
                _PreviewRow(view: preview),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: GestureDetector(
                  onTap: widget.onViewAll,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.missionViewAll,
                          style: safeOrbitron(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: AppPalette.homeCyan)),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_left_rounded,
                          size: 18, color: AppPalette.homeCyan),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final MissionView view;
  const _PreviewRow({required this.view});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final def = view.def;
    final accent = missionAccentFor(def);

    // Determine current target + reward + action for whichever scope.
    final bool claimable;
    final bool claimed;
    final int target;
    final int reward;
    final int? tierIndex;
    if (def.isWeekly) {
      final i = view.activeTierIndex;
      // Prefer the lowest claimable tier if any.
      var idx = i;
      for (var t = 0; t < def.tiers.length; t++) {
        if (view.tierClaimable(t)) {
          idx = t;
          break;
        }
      }
      tierIndex = idx;
      target = def.tiers[idx].target;
      reward = def.tiers[idx].rewardCoins;
      claimable = view.tierClaimable(idx);
      claimed = view.tierIsClaimed(idx);
    } else {
      tierIndex = null;
      target = def.target;
      reward = def.rewardCoins;
      claimable = view.dailyClaimable;
      claimed = view.dailyClaimed;
    }
    final kind = claimed
        ? _ActionKind.done
        : (claimable ? _ActionKind.claim : _ActionKind.go);

    return Row(
      children: [
        _IconBox(icon: missionIconFor(def), accent: accent, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(def.title(l10n.isAr),
                  style: safeInter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.homeTitle),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              MissionProgressBar(
                  value: target == 0 ? 0 : view.progress / target,
                  color: accent),
              const SizedBox(height: 5),
              Row(
                children: [
                  missionCoin(14),
                  const SizedBox(width: 4),
                  Text('+${formatCoins(reward)}',
                      style: safeOrbitron(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.gold)),
                  const Spacer(),
                  Text('${view.progress}/$target',
                      style: safeInter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.textMuted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _MissionActionButton(
          kind: kind,
          onTap: () {
            if (kind == _ActionKind.claim) {
              handleMissionClaim(context, def.id, tierIndex: tierIndex);
            } else if (kind == _ActionKind.go) {
              navigateMissionRoute(context, def.route);
            }
          },
        ),
      ],
    );
  }
}

class _MiniTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MiniTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppPalette.homeCyan.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected
                  ? AppPalette.homeCyan.withValues(alpha: 0.5)
                  : AppPalette.strokeSoft),
        ),
        child: Text(label,
            style: safeOrbitron(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: selected ? AppPalette.homeCyan : AppPalette.textMuted)),
      ),
    );
  }
}
