import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../services/app_mode_service.dart';
import '../../services/arena/arena_repo.dart';
import '../../services/referral/referral_service.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/arena_toast.dart';
import '../referral/enter_invite_code_page.dart';
import '../referral/invite_friends_page.dart';
import 'arena_create_room_page.dart';
import 'arena_join_room_page.dart';
import 'arena_lobby_page.dart';
import 'widgets/arena_card.dart';

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
  }

  Future<bool> _requireOnline() async {
    if (AppModeService.canUseOnlineServices) return true;
    if (mounted) {
      ArenaToast.warning(context, AppL10n.of(context).arenaOnlineOnly);
    }
    return false;
  }

  Future<void> _resumeActiveRoom() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final code = await ArenaRepo.instance.getActiveRoomCode(uid);
    if (code == null) return;
    final room = await ArenaRepo.instance.readRoom(code);
    if (room == null) {
      await ArenaRepo.instance.clearActiveRoomMirror(uid);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ArenaLobbyPage(initialRoom: room),
    ));
  }

  Future<void> _onCreate() async {
    if (!await _requireOnline()) return;
    if (!mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final existing = await ArenaRepo.instance.getActiveRoomCode(uid);
      if (existing != null) {
        if (!mounted) return;
        ArenaToast.warning(context, AppL10n.of(context).alreadyInActiveRoom);
        await _resumeActiveRoom();
        return;
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

  Future<void> _onInvite() async {
    if (!AppConfig.kEnableReferralRewards) return;
    if (!await _requireOnline()) return;
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const InviteFriendsPage(),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final showBackButton = !widget.embedded;

    final body = SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showBackButton) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ] else
              const SizedBox(height: 4),
            Text(
              l10n.arenaTab,
              style: const TextStyle(
                color: AppPalette.text,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontFamily: 'Orbitron',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.playWithFriend,
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            if (AppConfig.kEnableReferralRewards) ...[
              ArenaCard(
                icon: Icons.card_giftcard_rounded,
                title: l10n.inviteFriendsTitle,
                subtitle: l10n.inviteFriendsBody,
                accent: AppPalette.gold,
                onTap: _onInvite,
              ),
              const SizedBox(height: 12),
            ],
            ArenaCard(
              icon: Icons.add_circle_outline_rounded,
              title: l10n.createRoom,
              subtitle: l10n.playWithFriend,
              accent: AppPalette.primary,
              onTap: _onCreate,
            ),
            const SizedBox(height: 12),
            ArenaCard(
              icon: Icons.login_rounded,
              title: l10n.joinRoom,
              accent: AppPalette.accentPurple,
              onTap: _onJoin,
            ),
            if (AppConfig.kEnableReferralRewards) ...[
              const SizedBox(height: 12),
              ArenaCard(
                icon: Icons.confirmation_number_outlined,
                title: l10n.enterInviteCode,
                accent: AppPalette.success,
                onTap: _onEnterCode,
              ),
            ],
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
