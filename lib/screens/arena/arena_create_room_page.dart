import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../core/keys.dart';
import '../../services/app_mode_service.dart';
import '../../services/arena/arena_cosmetics_loader.dart';
import '../../services/arena/arena_repo.dart';
import '../../services/connectivity_service.dart';
import '../../services/local_store.dart';
import '../../services/mission_service.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/arena_toast.dart';
import 'arena_lobby_page.dart';
import 'widgets/arena_bet_selector.dart';

class ArenaCreateRoomPage extends StatefulWidget {
  const ArenaCreateRoomPage({super.key});

  @override
  State<ArenaCreateRoomPage> createState() => _ArenaCreateRoomPageState();
}

class _ArenaCreateRoomPageState extends State<ArenaCreateRoomPage> {
  int _rounds = 1;
  List<String> _maps = const ['3x3'];
  bool _busy = false;
  bool _betEnabled = false;
  int _betAmount = kArenaMinBet;

  static const List<int> _roundOptions = [1, 2, 3, 4, 5, 6, 7, 8];
  static const List<String> _boardOptions = ['3x3', '4x4', '5x5'];

  void _setRounds(int rounds) {
    setState(() {
      _rounds = rounds;
      final next = List<String>.from(_maps);
      if (next.length < rounds) {
        next.addAll(List<String>.filled(rounds - next.length, '3x3'));
      } else if (next.length > rounds) {
        next.removeRange(rounds, next.length);
      }
      _maps = next;
    });
  }

  void _setMap(int index, String map) {
    if (index < 0 || index >= _maps.length) return;
    setState(() {
      final next = List<String>.from(_maps);
      next[index] = map;
      _maps = next;
    });
  }

  Future<void> _create() async {
    if (_busy) return;
    final l10n = AppL10n.of(context);
    if (!AppModeService.canUseOnlineServices ||
        !ConnectivityService().isOnline.value) {
      ArenaToast.warning(context, l10n.arenaOnlineOnly);
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      ArenaToast.error(context, l10n.signInRequiredTitle);
      return;
    }

    // Host-side balance check for betting rooms — refuse to create a room
    // the host can't afford to enter. The guest is already gated symmetrically
    // in ArenaRepo.joinRoom.
    if (_betEnabled) {
      if (_betAmount < kArenaMinBet) {
        ArenaToast.error(context, l10n.minimumBetMessage);
        return;
      }
      if (_betAmount > kArenaMaxBet) {
        ArenaToast.error(context, l10n.maximumBetMessage);
        return;
      }
      if (LocalStore.coinsNotifier.value < _betAmount) {
        ArenaToast.error(context, l10n.notEnoughCoinsCreate);
        return;
      }
    }

    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = (prefs.getString(Keys.username) ?? 'PLAYER').toUpperCase();
      final photoUrl = prefs.getString(Keys.profilePhotoUrl);
      final hostProfile = await loadArenaPlayerCosmetics();

      final room = await ArenaRepo.instance.createRoom(
        hostName: name,
        hostPhoto: photoUrl,
        roundsCount: _rounds,
        roundMaps: List<String>.from(_maps),
        bettingEnabled: _betEnabled,
        betAmount: _betEnabled ? _betAmount : 0,
        hostProfile: hostProfile,
      );
      // Missions: online room successfully created (auth-gated → guests excluded).
      MissionService.instance
          .trackEvent('online_room_created', matchId: room.matchId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ArenaLobbyPage(initialRoom: room),
      ));
    } on ArenaOfflineException {
      if (!mounted) return;
      ArenaToast.warning(context, l10n.arenaOnlineOnly);
      setState(() => _busy = false);
    } catch (_) {
      if (!mounted) return;
      ArenaToast.error(context, l10n.somethingWentWrong);
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        variant: AppBackgroundVariant.homeNeon,
        child: SafeArea(
          child: Directionality(
            textDirection: l10n.isAr ? TextDirection.rtl : TextDirection.ltr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: _header(l10n),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionShell(
                          title: l10n.rounds.toUpperCase(),
                          icon: Icons.replay_rounded,
                          child: Column(
                            children: [
                              SizedBox(height: 56, child: _roundsRow()),
                              const SizedBox(height: 10),
                              Text(
                                l10n.roundsWinnerDescription(_rounds),
                                textAlign: TextAlign.center,
                                style: safeInter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppPalette.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SectionShell(
                          title: l10n.perRoundMaps.toUpperCase(),
                          icon: Icons.grid_view_rounded,
                          child: _mapsGrid(l10n),
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<int>(
                          valueListenable: LocalStore.coinsNotifier,
                          builder: (context, balance, _) => ArenaBetSelector(
                            enabled: _betEnabled,
                            amount: _betAmount,
                            balance: balance,
                            onToggle: (v) => setState(() {
                              _betEnabled = v;
                              if (v && _betAmount < kArenaMinBet) {
                                _betAmount = kArenaMinBet;
                              }
                            }),
                            onAmountChanged: (v) =>
                                setState(() => _betAmount = v),
                            onInsufficientForToggle: () => ArenaToast.error(
                              context,
                              l10n.notEnoughCoinsCreate,
                            ),
                            onTapDisabledPreset: () => ArenaToast.show(
                              context,
                              l10n.notEnoughCoinsShort,
                              kind: ArenaToastKind.warning,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _QuickChatPill(label: l10n.quickChatAndEmojis),
                      ],
                    ),
                  ),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: LocalStore.coinsNotifier,
                  builder: (context, balance, _) {
                    final insufficient = _betEnabled &&
                        (balance < _betAmount ||
                            _betAmount < kArenaMinBet ||
                            _betAmount > kArenaMaxBet);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                      child: _CreateRoomButton(
                        label: l10n.createRoom,
                        busy: _busy,
                        onTap: (_busy || insufficient) ? null : _create,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AppL10n l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppIconButton(
          icon: Icons.arrow_back,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.createRoom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: homeTitleFont(context, fontSize: 27),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.createRoomPageSubtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: safeInter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roundsRow() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemCount: _roundOptions.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, index) {
        final round = _roundOptions[index];
        return SizedBox(
          width: 50,
          child: _choiceButton(
            selected: _rounds == round,
            label: '$round',
            onTap: () => _setRounds(round),
            radius: 15,
          ),
        );
      },
    );
  }

  Widget _mapsGrid(AppL10n l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 420;
        final cardWidth =
            twoColumns ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var index = 0; index < _rounds; index++)
              SizedBox(
                width: cardWidth,
                child: _roundMapCard(l10n, index),
              ),
          ],
        );
      },
    );
  }

  Widget _roundMapCard(AppL10n l10n, int index) {
    return Container(
      height: 102,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppPalette.homePanelStrong.withValues(alpha: 0.88),
            AppPalette.panelDeep.withValues(alpha: 0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppPalette.homeCyan.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 23,
                height: 23,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppPalette.homePurple.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppPalette.homePurple.withValues(alpha: 0.65),
                  ),
                ),
                child: Text(
                  '${index + 1}',
                  style: safeOrbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppPalette.homeCyan,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${l10n.currentRoundLabel} ${index + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: safeInter(
                    color: AppPalette.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Expanded(
            child: Row(
              children: [
                for (final map in _boardOptions)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _choiceButton(
                        selected: _maps[index] == map,
                        label: map,
                        onTap: () => _setMap(index, map),
                        radius: 10,
                        small: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _choiceButton({
    required bool selected,
    required String label,
    required VoidCallback onTap,
    required double radius,
    bool small = false,
  }) {
    return Material(
      color: selected
          ? AppPalette.primary.withValues(alpha: 0.20)
          : AppPalette.panelDeep,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? AppPalette.primary : AppPalette.strokeSoft,
              width: selected ? 1.6 : 1.0,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppPalette.primary.withValues(alpha: 0.34),
                      blurRadius: 16,
                      spreadRadius: -3,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppPalette.primary : AppPalette.text,
              fontSize: small ? 11.5 : 16,
              fontWeight: FontWeight.w900,
              fontFamily: small ? 'Inter' : 'Orbitron',
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionShell({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppPalette.homePanel.withValues(alpha: 0.72),
            AppPalette.panelDeep.withValues(alpha: 0.74),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppPalette.homeCyan.withValues(alpha: 0.30),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.homeCyan.withValues(alpha: 0.08),
            blurRadius: 22,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppPalette.homeCyan),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: safeOrbitron(
                    color: AppPalette.homeCyan,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _QuickChatPill extends StatelessWidget {
  final String label;

  const _QuickChatPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppPalette.homeBlue.withValues(alpha: 0.14),
            AppPalette.homePurple.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppPalette.homePurple.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.homePurple.withValues(alpha: 0.12),
            blurRadius: 18,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_rounded,
              color: AppPalette.homeCyan, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: safeInter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppPalette.text,
              ),
            ),
          ),
          const SizedBox(width: 11),
          const Icon(Icons.sentiment_satisfied_alt_rounded,
              color: AppPalette.homePurple, size: 22),
        ],
      ),
    );
  }
}

class _CreateRoomButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  const _CreateRoomButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: onTap == null ? 0.52 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Ink(
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppPalette.homeBlue, AppPalette.homeCyan],
              ),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.46),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.homeCyan.withValues(alpha: 0.38),
                  blurRadius: 24,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppPalette.bgTop,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded,
                            color: AppPalette.bgTop, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: safeInter(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppPalette.bgTop,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
