import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../core/keys.dart';
import '../../services/arena/arena_cosmetics_loader.dart';
import '../../services/arena/arena_repo.dart';
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
        ArenaToast.error(
            context, l10n.isAr ? 'الحد الأدنى للرهان 50' : 'Minimum bet is 50 coins');
        return;
      }
      if (_betAmount > kArenaMaxBet) {
        ArenaToast.error(context,
            l10n.isAr ? 'الحد الأقصى للرهان 10000' : 'Maximum bet is 10,000 coins');
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
    } catch (e) {
      if (!mounted) return;
      ArenaToast.error(context, e.toString());
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(l10n),
                const SizedBox(height: 10),
                _SectionShell(
                  title: l10n.rounds,
                  child: SizedBox(height: 42, child: _roundsRow()),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _SectionShell(
                    title: l10n.perRoundMaps,
                    expandChild: true,
                    child: _mapsGrid(l10n),
                  ),
                ),
                const SizedBox(height: 10),
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
                    onAmountChanged: (v) => setState(() => _betAmount = v),
                    onInsufficientForToggle: () => ArenaToast.error(
                      context,
                      l10n.notEnoughCoinsCreate,
                    ),
                    onTapDisabledPreset: () => ArenaToast.show(
                      context,
                      l10n.isAr ? 'لا توجد عملات كافية' : 'Not enough coins',
                      kind: ArenaToastKind.warning,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<int>(
                  valueListenable: LocalStore.coinsNotifier,
                  builder: (context, balance, _) {
                    final insufficient = _betEnabled &&
                        (balance < _betAmount ||
                            _betAmount < kArenaMinBet ||
                            _betAmount > kArenaMaxBet);
                    return SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: (_busy || insufficient) ? null : _create,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppPalette.primary,
                          foregroundColor: AppPalette.bgTop,
                          disabledBackgroundColor: AppPalette.panelDeep,
                          disabledForegroundColor: AppPalette.textSubtle,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4),
                              )
                            : Text(
                                l10n.createRoom,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.7,
                                ),
                              ),
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
      children: [
        AppIconButton(
          icon: Icons.arrow_back,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            l10n.createRoom,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppPalette.text,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _roundsRow() {
    return Row(
      children: [
        for (final round in _roundOptions)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _choiceButton(
                selected: _rounds == round,
                label: '$round',
                onTap: () => _setRounds(round),
                radius: 14,
              ),
            ),
          ),
      ],
    );
  }

  Widget _mapsGrid(AppL10n l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 390 ? 2 : 3;
        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _rounds,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: crossAxisCount == 2 ? 2.05 : 1.75,
          ),
          itemBuilder: (context, index) => _roundMapCard(l10n, index),
        );
      },
    );
  }

  Widget _roundMapCard(AppL10n l10n, int index) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppPalette.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.strokeSoft, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${l10n.currentRoundLabel} ${index + 1}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
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
                        radius: 11,
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
      color: selected ? AppPalette.primary.withValues(alpha: 0.22) : AppPalette.panelDeep,
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
                      color: AppPalette.primary.withValues(alpha: 0.22),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppPalette.primary : AppPalette.text,
              fontSize: small ? 12 : 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

}

class _SectionShell extends StatelessWidget {
  final String title;
  final Widget child;
  final bool expandChild;
  const _SectionShell({
    required this.title,
    required this.child,
    this.expandChild = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppPalette.homePanel.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.strokeSoft, width: 1),
      ),
      child: Column(
        mainAxisSize: expandChild ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppPalette.text,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.35,
            ),
          ),
          const SizedBox(height: 8),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }
}
