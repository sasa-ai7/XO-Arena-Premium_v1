import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../services/app_mode_service.dart';
import '../../services/arena/arena_repo.dart';
import '../../services/arena/arena_resume_flow.dart';
import '../../services/connectivity_service.dart';
import '../../services/referral/referral_service.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/arena_neon_widgets.dart';
import '../../widgets/arena_toast.dart';
import '../referral/enter_invite_code_page.dart';
import '../store/store_page.dart';
import 'arena_create_room_page.dart';
import 'arena_join_room_page.dart';
import 'widgets/active_room_resume_dialog.dart';

/// Root widget for the Arena bottom-nav tab.
class ArenaPage extends StatefulWidget {
  final bool embedded;
  const ArenaPage({super.key, this.embedded = false});

  @override
  State<ArenaPage> createState() => _ArenaPageState();
}

class _ArenaPageState extends State<ArenaPage> {
  @override
  void initState() {
    super.initState();
    final openedAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kDebugMode) return;
      final ms = DateTime.now().difference(openedAt).inMilliseconds;
      debugPrint('[PERF] online_page_open_ms=$ms');
    });
    _reconcile();
  }

  Future<void> _reconcile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await ArenaRepo.instance.reconcileActiveRoomMirror(uid);
    // Ensure user has a referral code.
    if (AppConfig.kEnableReferralRewards) {
      ReferralService.instance.ensureCode(uid);
    }
    // Offer to resume a still-valid active room (styled modal, not a silent
    // auto-navigate).
    await _maybeShowResumePrompt(uid);
  }

  Future<bool> _requireOnline() async {
    if (AppModeService.canUseOnlineServices &&
        ConnectivityService().isOnline.value &&
        FirebaseAuth.instance.currentUser != null) {
      return true;
    }
    if (mounted) {
      ArenaToast.warning(context, AppL10n.of(context).arenaOnlineOnly);
    }
    return false;
  }

  /// On Arena/Online tab open: settle a room that ended/expired while away,
  /// then surface the styled "Active Room Found" modal when the saved pointer
  /// is still valid and the user has not back-dismissed it this session.
  Future<void> _maybeShowResumePrompt(String uid) async {
    if (!AppModeService.canUseOnlineServices) return;
    // Mutually exclude with the Home startup resume check.
    if (ArenaRepo.instance.resumeFlowBusy) return;
    ArenaRepo.instance.resumeFlowBusy = true;
    try {
      final outcome = await ArenaResumeFlow.settlePendingActiveRoom(uid);
      if (!mounted) return;
      if (outcome.kind != PendingRoomKind.none) {
        await ArenaResumeFlow.showSettlementNotice(context, outcome,
            isAr: AppL10n.of(context).isAr);
        return;
      }
      final check = await ArenaRepo.instance.validateActiveRoom(uid);
      if (!check.isValid) return;
      final code = check.code!;
      if (ArenaRepo.instance.resumeDismissedThisSession.contains(code)) return;
      if (!mounted) return;
      if (kDebugMode) {
        debugPrint('[ARENA_ACTIVE_ROOM] prompt_shown uid=$uid room=$code '
            'status=${check.room!.status}');
      }
      final choice = await showActiveRoomResumeDialog(
        context,
        roomCode: code,
        statusLabel: ArenaResumeFlow.statusLabel(check.room!.status),
      );
      if (!mounted) return;
      if (choice == ActiveRoomResumeChoice.returnToRoom) {
        await _returnToRoom(uid);
        return;
      }
      if (choice == ActiveRoomResumeChoice.leaveAndPlay) {
        if (kDebugMode) {
          debugPrint('[ARENA_ACTIVE_ROOM] leave_and_play uid=$uid room=$code');
        }
        await ArenaRepo.instance.resolvePlayerLeaveRoom(
          roomCode: code,
          leaverUid: uid,
          reason: 'resume_prompt_leave',
        );
        return;
      }
      // Back-dismissed: keep the room but suppress the prompt for this session.
      ArenaRepo.instance.resumeDismissedThisSession.add(code);
    } finally {
      ArenaRepo.instance.resumeFlowBusy = false;
    }
  }

  /// Re-validate (the room may have changed while the prompt was open) and
  /// navigate to the lobby or game by the room's current state.
  Future<void> _returnToRoom(String uid) async {
    final check = await ArenaRepo.instance.validateActiveRoom(uid);
    if (!mounted) return;
    if (!check.isValid) {
      if (check.validity == ActiveRoomValidity.kicked) {
        ArenaToast.error(
            context, 'You were removed from this room by the host.');
      }
      return;
    }
    if (kDebugMode) {
      debugPrint('[ARENA_ACTIVE_ROOM] return_to_room uid=$uid '
          'room=${check.code} target=${check.target}');
    }
    await ArenaResumeFlow.navigateToRoom(context, check.room!);
  }

  Future<void> _onCreate() async {
    if (!await _requireOnline()) return;
    if (!mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      if (kDebugMode) debugPrint('[CREATE_ROOM_GUARD] start uid=$uid');
      // 1) Settle any room that ended/expired while away (clears the pointer).
      final outcome = await ArenaResumeFlow.settlePendingActiveRoom(uid);
      if (!mounted) return;
      if (outcome.kind != PendingRoomKind.none) {
        await ArenaResumeFlow.showSettlementNotice(context, outcome,
            isAr: AppL10n.of(context).isAr);
        if (!mounted) return;
        if (kDebugMode) {
          final res = outcome.kind == PendingRoomKind.wonNotice
              ? 'finished'
              : outcome.closedReason;
          debugPrint('[CREATE_ROOM_GUARD] active_room_result=$res');
          debugPrint('[CREATE_ROOM_GUARD] stale_cleared uid=$uid '
              'room=${outcome.roomCode}');
        }
        // Pointer cleared → fall through to create.
      } else {
        // 2) Still-live room → force a Return/Leave choice (never auto-enter).
        final check = await ArenaRepo.instance.validateActiveRoom(uid);
        if (!mounted) return;
        if (check.isValid) {
          final code = check.code!;
          if (kDebugMode) {
            debugPrint('[CREATE_ROOM_GUARD] active_room_result=valid');
            debugPrint('[CREATE_ROOM_GUARD] show_resume_prompt room=$code');
          }
          final choice = await showActiveRoomResumeDialog(
            context,
            roomCode: code,
            statusLabel: ArenaResumeFlow.statusLabel(check.room!.status),
          );
          if (!mounted) return;
          if (choice == ActiveRoomResumeChoice.returnToRoom) {
            await _returnToRoom(uid);
            return; // Do NOT create a new room.
          }
          if (choice == ActiveRoomResumeChoice.leaveAndPlay) {
            await ArenaRepo.instance.resolvePlayerLeaveRoom(
              roomCode: code,
              leaverUid: uid,
              reason: 'explicit_leave',
            );
            if (!mounted) return;
            // Room resolved + pointer cleared → fall through to create.
          } else {
            // Back-dismissed: abort the create action, keep the room.
            return;
          }
        } else if (kDebugMode) {
          debugPrint(
              '[CREATE_ROOM_GUARD] active_room_result=${check.validity.name}');
          if (check.validity != ActiveRoomValidity.none) {
            debugPrint('[CREATE_ROOM_GUARD] stale_cleared uid=$uid '
                'room=${check.code}');
          }
        }
      }
      if (kDebugMode) {
        debugPrint('[CREATE_ROOM_GUARD] create_new_room_allowed uid=$uid');
      }
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ArenaCreateRoomPage(),
    ));
  }

  Future<void> _onJoin() async {
    if (!await _requireOnline()) return;
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ArenaJoinRoomPage(),
    ));
  }

  Future<void> _onEnterCode() async {
    if (!AppConfig.kEnableReferralRewards) return;
    if (!await _requireOnline()) return;
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const EnterInviteCodePage(),
    ));
  }

  Future<void> _openCoinsStore() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StorePage(initialTab: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showBackButton = !widget.embedded;
    final l10n = AppL10n.of(context);

    final body = SafeArea(
      child: Directionality(
        textDirection: l10n.isAr ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          children: [
            XoArenaScreenHeader(
              showBack: showBackButton,
              onBack: () => Navigator.of(context).maybePop(),
              onCoinsTap: _openCoinsStore,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.arenaTab,
                    style: homeTitleFont(context, fontSize: 28),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    l10n.arenaScreenSubtitle,
                    style: homeBodyFont(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.homeBody,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                physics: const BouncingScrollPhysics(),
                children: [
                  NeonArenaActionCard(
                    assetPath: kArenaCreateRoomAsset,
                    title: l10n.createRoom,
                    subtitleLines: [
                      l10n.createRoomSubtitle1,
                      l10n.createRoomSubtitle2,
                    ],
                    buttonLabel: l10n.startBtn,
                    accent: AppPalette.homeCyan,
                    accentSecondary: AppPalette.homeBlue,
                    onPressed: _onCreate,
                  ),
                  const SizedBox(height: 14),
                  NeonArenaActionCard(
                    assetPath: kArenaJoinRoomAsset,
                    title: l10n.joinRoom,
                    subtitleLines: [
                      l10n.joinRoomSubtitle1,
                      l10n.joinRoomSubtitle2,
                    ],
                    buttonLabel: l10n.joinBtn,
                    accent: AppPalette.homePurple,
                    accentSecondary: AppPalette.homeCyan,
                    onPressed: _onJoin,
                  ),
                  if (AppConfig.kEnableReferralRewards) ...[
                    const SizedBox(height: 14),
                    InviteCodePanel(
                      onEnterCode: _onEnterCode,
                      compact: false,
                    ),
                  ],
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return body;
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        variant: AppBackgroundVariant.homeNeon,
        child: body,
      ),
    );
  }
}
