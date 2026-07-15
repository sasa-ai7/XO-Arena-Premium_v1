import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../core/coin_format.dart';
import '../../models/game_avatar.dart';
import '../../models/mission.dart';
import '../../services/mission_service.dart';
import '../../utils/navigation_utils.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/full_avatar_display.dart';
import '../arena/arena_create_room_page.dart';
import '../arena/arena_join_room_page.dart';
import '../arena/arena_page.dart';
import '../games/friend_setup_page.dart';
import '../games/level_game_setup_page.dart';
import '../games/setup_page.dart';
import '../store/store_page.dart';

bool missionIsGuest() => FirebaseAuth.instance.currentUser == null;

bool _missionRewardPopupShowing = false;

/// Coin icon used across mission cards.
Widget missionCoin(double size) => Image.asset(
      'assets/coin/COIN.webp',
      width: size,
      height: size,
      cacheWidth: (size * 3).round(),
      errorBuilder: (_, __, ___) =>
          Icon(Icons.monetization_on, size: size, color: AppPalette.gold),
    );

IconData missionIconFor(MissionDef def) {
  switch (def.eventKey) {
    case 'daily_login':
      return Icons.auto_awesome_rounded;
    case 'any_match_completed':
      return Icons.sports_esports_rounded;
    case 'any_match_won':
      return Icons.workspace_premium_rounded;
    case 'friend_match_completed':
      return Icons.group_rounded;
    case 'ai_match_completed':
      return Icons.memory_rounded;
    case 'ai_win_easy':
      return Icons.smart_toy_rounded;
    case 'ai_win_medium':
      return Icons.psychology_alt_rounded;
    case 'ai_win_hard':
      return Icons.blur_on_rounded;
    case 'online_room_created':
      return Icons.add_home_work_rounded;
    case 'online_room_joined_by_code':
      return Icons.key_rounded;
    case 'online_match_completed':
      return Icons.hub_rounded;
    case 'online_match_won':
      return Icons.public_rounded;
    case 'level_completed':
      return Icons.emoji_events_rounded;
    case 'login_streak':
      return Icons.calendar_month_rounded;
    case 'coins_spent':
      return Icons.savings_rounded;
    case 'theme_bought':
      return Icons.palette_rounded;
    case 'premium_avatar_bought':
      return Icons.workspace_premium_rounded;
    case 'avatar_equipped':
      return Icons.face_retouching_natural_rounded;
    case 'friend_invited':
      return Icons.person_add_alt_1_rounded;
  }
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
    case MissionRoute.store:
      return Icons.storefront_rounded;
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
    case MissionRoute.store:
      return AppPalette.homeGold;
    case MissionRoute.none:
      return AppPalette.goldHighlight;
  }
}

String missionDescriptionFor(MissionDef def, bool isAr) {
  if (!isAr) {
    switch (def.eventKey) {
      case 'daily_login':
        return 'Open the game and claim your daily reward.';
      case 'any_match_completed':
        return 'Complete matches in any mode.';
      case 'any_match_won':
        return 'Win rounds and grow your streak.';
      case 'friend_match_completed':
        return 'Play against a friend on one device.';
      case 'ai_match_completed':
      case 'ai_win_easy':
      case 'ai_win_medium':
      case 'ai_win_hard':
        return 'Train, challenge, and beat the AI.';
      case 'online_room_created':
        return 'Create a private room for your friends.';
      case 'online_room_joined_by_code':
        return 'Enter a room code and join instantly.';
      case 'online_match_completed':
      case 'online_match_won':
        return 'Play online private-room matches.';
      case 'level_completed':
        return 'Clear stages and unlock more rewards.';
      case 'login_streak':
        return 'Open the game 7 days to unlock a free avatar.';
      case 'coins_spent':
        return 'Spend coins in the store on anything.';
      case 'theme_bought':
        return 'Buy any X or O color or theme.';
      case 'premium_avatar_bought':
        return 'Unlock a premium avatar frame.';
      case 'avatar_equipped':
        return 'Equip any avatar frame on your profile.';
      case 'friend_invited':
        return 'Invite a friend with your referral code.';
    }
    return 'Complete the objective and claim coins.';
  }
  switch (def.eventKey) {
    case 'daily_login':
      return 'افتح اللعبة واحصل على مكافأتك اليومية';
    case 'any_match_completed':
      return 'أكمل مبارياتك في أي وضع';
    case 'any_match_won':
      return 'اكسب جولات وارفَع تقدمك';
    case 'friend_match_completed':
      return 'العب ضد صديق على نفس الجهاز';
    case 'ai_match_completed':
    case 'ai_win_easy':
    case 'ai_win_medium':
    case 'ai_win_hard':
      return 'تدرّب وتحدَّ الذكاء الاصطناعي';
    case 'online_room_created':
      return 'أنشئ غرفة خاصة لأصدقائك';
    case 'online_room_joined_by_code':
      return 'ادخل كود غرفة وانضم فورًا';
    case 'online_match_completed':
    case 'online_match_won':
      return 'العب مباريات أونلاين في غرف خاصة';
    case 'level_completed':
      return 'تخطَّ المراحل وافتح مكافآت أكثر';
    case 'login_streak':
      return 'افتح اللعبة 7 أيام لتفتح أفاتار مجاني';
    case 'coins_spent':
      return 'أنفق الكوينز في المتجر على أي شيء';
    case 'theme_bought':
      return 'اشترِ أي لون أو ثيم X أو O';
    case 'premium_avatar_bought':
      return 'افتح إطار أفاتار مميز';
    case 'avatar_equipped':
      return 'جهّز أي إطار أفاتار على ملفك';
    case 'friend_invited':
      return 'ادعُ صديقاً برمز الإحالة الخاص بك';
  }
  return 'أنجز الهدف واحصل على كوينز';
}

/// Navigate to the screen a mission's "اذهب" button targets. Online routes are
/// gated for guests with the shared sign-in dialog (never start online blindly).
void navigateMissionRoute(BuildContext context, MissionRoute route) {
  Widget? page;
  var onlineGated = false;
  switch (route) {
    case MissionRoute.none:
      return; // nothing to open
    case MissionRoute.home:
      page = const SetupPage();
      break;
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
    case MissionRoute.store:
      page = const StorePage();
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
  HapticFeedback.mediumImpact();
  final claimStart = DateTime.now();
  final l10n = AppL10n.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final reward = _missionRewardFor(missionId, tierIndex: tierIndex);
  final rewardAvatarId =
      MissionService.instance.viewFor(missionId)?.def.rewardAvatarId;
  final res =
      await MissionService.instance.claim(missionId, tierIndex: tierIndex);
  if (kDebugMode) {
    final ms = DateTime.now().difference(claimStart).inMilliseconds;
    debugPrint('[PERF] mission_claim_ms=$ms result=$res');
  }
  if (!context.mounted) return;
  String? msg;
  switch (res) {
    case ClaimResult.success:
      await showMissionRewardPopup(context,
          rewardCoins: reward, rewardAvatarId: rewardAvatarId);
      return;
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
  messenger.showSnackBar(
    SnackBar(
      content: Text(msg, textAlign: TextAlign.center),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppPalette.homePanelStrong,
    ),
  );
}

int _missionRewardFor(String missionId, {int? tierIndex}) {
  final view = MissionService.instance.viewFor(missionId);
  final def = view?.def;
  if (def == null) return 0;
  if (!def.isWeekly) return def.rewardCoins;
  final i = tierIndex ?? view?.activeTierIndex ?? 0;
  if (i < 0 || i >= def.tiers.length) return 0;
  return def.tiers[i].rewardCoins;
}

Future<void> showMissionRewardPopup(
  BuildContext context, {
  required int rewardCoins,
  int? rewardAvatarId,
}) async {
  if (_missionRewardPopupShowing) return;
  _missionRewardPopupShowing = true;
  final l10n = AppL10n.of(context);
  final rewardAvatar =
      rewardAvatarId == null ? null : gameAvatarByIdOrNull(rewardAvatarId);
  var dialogOpen = true;
  try {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n.close,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (ctx, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
      pageBuilder: (dialogContext, _, __) {
        final navigator = Navigator.of(dialogContext);
        Future<void>.delayed(const Duration(milliseconds: 1200), () {
          if (dialogOpen && navigator.canPop()) {
            navigator.pop();
          }
        });
        return Center(
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () => Navigator.of(dialogContext).maybePop(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: AppGlassCard(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                    radius: 28,
                    borderColor:
                        AppPalette.goldHighlight.withValues(alpha: 0.62),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppPalette.homePanelStrong.withValues(alpha: 0.98),
                        Color.lerp(
                          AppPalette.homePanelDeep,
                          AppPalette.goldDeep,
                          0.12,
                        )!,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.gold.withValues(alpha: 0.30),
                        blurRadius: 42,
                        spreadRadius: -8,
                      ),
                      BoxShadow(
                        color: AppPalette.homeCyan.withValues(alpha: 0.16),
                        blurRadius: 34,
                        spreadRadius: -12,
                      ),
                    ],
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 118,
                              height: 118,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppPalette.gold.withValues(alpha: 0.30),
                                    AppPalette.homeCyan.withValues(alpha: 0.10),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            if (rewardAvatar != null)
                              // Free avatar reward — show the frame over the
                              // player's own photo, exactly as it will appear.
                              FullAvatarDisplay(
                                size: 104,
                                avatar: rewardAvatar,
                                showFrame: true,
                              )
                            else
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      AppPalette.bgDepth.withValues(alpha: 0.74),
                                  border: Border.all(
                                    color: AppPalette.goldHighlight
                                        .withValues(alpha: 0.78),
                                    width: 1.4,
                                  ),
                                ),
                                child: Center(child: missionCoin(46)),
                              ),
                            if (rewardAvatar == null)
                              Positioned(
                                right: 10,
                                bottom: 12,
                                child: Container(
                                  width: 25,
                                  height: 25,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppPalette.success,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppPalette.success
                                            .withValues(alpha: 0.48),
                                        blurRadius: 14,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.missionCompletedTitle,
                          textAlign: TextAlign.center,
                          style: homeTitleFont(context, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          rewardAvatar != null
                              ? l10n.missionAvatarRewardEarned(rewardAvatar.name)
                              : l10n.missionRewardEarned(rewardCoins),
                          textAlign: TextAlign.center,
                          style: safeOrbitron(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: AppPalette.goldHighlight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  } finally {
    dialogOpen = false;
    _missionRewardPopupShowing = false;
  }
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
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
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
  const MissionProgressBar(
      {super.key, required this.value, required this.color});

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minWidth: 72, minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              fill,
              Color.lerp(fill, textColor, 0.24)!,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: textColor.withValues(alpha: 0.45)),
          boxShadow: [
            if (kind != _ActionKind.done)
              BoxShadow(
                color: textColor.withValues(alpha: 0.20),
                blurRadius: 16,
                spreadRadius: -6,
                offset: const Offset(0, 8),
              ),
          ],
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
    final claimable = view.dailyClaimable;
    final claimed = view.dailyClaimed;
    final progressColor = claimable || claimed ? AppPalette.success : accent;
    final _ActionKind kind = view.dailyClaimed
        ? _ActionKind.done
        : (view.dailyClaimable ? _ActionKind.claim : _ActionKind.go);
    return AppGlassCard(
      padding: const EdgeInsets.all(13),
      radius: 22,
      borderColor: progressColor.withValues(alpha: 0.36),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            _IconBox(
                icon: missionIconFor(def), accent: progressColor, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Directionality(
                textDirection:
                    l10n.isAr ? TextDirection.rtl : TextDirection.ltr,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.title(l10n.isAr),
                      style: safeInter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.homeTitle,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      missionDescriptionFor(def, l10n.isAr),
                      style: safeInter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    MissionProgressBar(
                      value: def.target == 0 ? 0 : view.progress / def.target,
                      color: progressColor,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          claimed
                              ? l10n.missionClaimedDone
                              : (claimable
                                  ? l10n.missionCompleted
                                  : '${view.progress}/${def.target}'),
                          style: safeInter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: claimable || claimed
                                ? AppPalette.success
                                : AppPalette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (def.rewardAvatarId != null)
                  // Avatar reward (e.g. the 7-day login frame): show the frame
                  // composited over the player's photo as the reward preview.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (gameAvatarByIdOrNull(def.rewardAvatarId!) != null)
                        FullAvatarDisplay(
                          size: 40,
                          avatar: gameAvatarByIdOrNull(def.rewardAvatarId!),
                          showFrame: true,
                        ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.missionFreeAvatar,
                        style: safeOrbitron(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: AppPalette.goldHighlight,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      missionCoin(16),
                      const SizedBox(width: 4),
                      Text(
                        '+${formatCoins(def.rewardCoins)}',
                        style: safeOrbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppPalette.gold,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 9),
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
          ],
        ),
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
    final hasClaimable = view.claimableCount > 0;
    final progressColor =
        hasClaimable || view.weeklyAllClaimed ? AppPalette.success : accent;
    return AppGlassCard(
      padding: const EdgeInsets.all(14),
      radius: 22,
      borderColor: progressColor.withValues(alpha: 0.32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                _IconBox(
                    icon: missionIconFor(def), accent: progressColor, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Directionality(
                    textDirection:
                        l10n.isAr ? TextDirection.rtl : TextDirection.ltr,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          def.title(l10n.isAr),
                          style: safeInter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.homeTitle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          missionDescriptionFor(def, l10n.isAr),
                          style: safeInter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                if (view.weeklyAllClaimed || hasClaimable)
                  Text(
                    view.weeklyAllClaimed
                        ? l10n.missionClaimedDone
                        : l10n.missionCompleted,
                    style: safeOrbitron(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.success),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          MissionProgressBar(
              value: topTarget == 0 ? 0 : view.progress / topTarget,
              color: progressColor),
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
                    accent: progressColor,
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
      border = AppPalette.success.withValues(alpha: 0.72);
      bg = AppPalette.success.withValues(alpha: 0.16);
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
                    color:
                        reached ? AppPalette.homeTitle : AppPalette.textMuted)),
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
                      color: AppPalette.success))
            else
              Icon(Icons.lock_outline,
                  size: 13,
                  color: AppPalette.textSubtle.withValues(alpha: 0.7)),
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
        borderRadius: BorderRadius.circular(size * 0.34),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.28),
            AppPalette.homePanelDeep.withValues(alpha: 0.86),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.48)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: size * 0.42,
            spreadRadius: -size * 0.16,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: size * 0.16,
            left: size * 0.18,
            child: Container(
              width: size * 0.34,
              height: size * 0.08,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          Container(
            width: size * 0.66,
            height: size * 0.66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.20)),
            ),
            child: Icon(icon, color: accent, size: size * 0.42),
          ),
        ],
      ),
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
        // Whole panel opens the full Missions page. Inner controls (daily/weekly
        // mini tabs, View All) are their own gesture detectors and win the arena
        // for their own area, so they keep working.
        return GestureDetector(
          onTap: widget.onViewAll,
          behavior: HitTestBehavior.opaque,
          child: AppGlassCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          radius: 24,
          borderColor: AppPalette.homeCyan.withValues(alpha: 0.34),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppPalette.homePanelStrong.withValues(alpha: 0.96),
              AppPalette.homePanelDeep.withValues(alpha: 0.97),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppPalette.homeCyan.withValues(alpha: 0.18),
                          AppPalette.homePurple.withValues(alpha: 0.10),
                          AppPalette.homePanelDeep.withValues(alpha: 0.76),
                        ],
                      ),
                      border: Border.all(
                        color: AppPalette.homeCyan.withValues(alpha: 0.42),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.homeCyan.withValues(alpha: 0.24),
                          blurRadius: 16,
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/moh.png',
                      width: 46,
                      height: 46,
                      fit: BoxFit.contain,
                      cacheWidth: 184,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.assignment_turned_in_rounded,
                        size: 26,
                        color: AppPalette.homeCyan,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l10n.missionsTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: homeLabelFont(context,
                            fontSize: 13.5, color: AppPalette.homeCyan)),
                  ),
                  const SizedBox(width: 8),
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
              const SizedBox(height: 14),
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
              const SizedBox(height: 9),
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
        _IconBox(icon: missionIconFor(def), accent: accent, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(def.title(l10n.isAr),
                  style: safeInter(
                      fontSize: 13.5,
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
                  missionCoin(16),
                  const SizedBox(width: 4),
                  Text('+${formatCoins(reward)}',
                      style: safeOrbitron(
                          fontSize: 11.5,
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
