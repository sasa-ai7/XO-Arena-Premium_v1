import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_config.dart';
import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../models/arena/arena_room.dart';
import '../../services/arena/arena_repo.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/arena_toast.dart';
import 'arena_game_page.dart';
import 'arena_share_helper.dart';
import 'widgets/arena_leave_dialog.dart';
import 'widgets/arena_profile_circle.dart';
import 'widgets/arena_skin_preview.dart';
import 'widgets/ready_chip.dart';

class ArenaLobbyPage extends StatefulWidget {
  final ArenaRoom initialRoom;
  const ArenaLobbyPage({super.key, required this.initialRoom});

  @override
  State<ArenaLobbyPage> createState() => _ArenaLobbyPageState();
}

class _ArenaLobbyPageState extends State<ArenaLobbyPage> {
  late ArenaRoom _room;
  StreamSubscription<ArenaRoom?>? _sub;
  Timer? _ticker;
  bool _busy = false;
  bool _navigated = false;
  bool _isCancelling = false;
  bool _cancelledHandled = false;
  bool _hasExitedRoom = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool get _isHost => _uid != null && _uid == _room.hostUid;

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    _sub = ArenaRepo.instance.watchRoom(_room.roomCode).listen(_onRoomChange);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onRoomChange(ArenaRoom? room) {
    if (!mounted) return;
    // Once the exit flow has begun (button press or earlier listener tick),
    // silence the listener entirely so it cannot trigger a second navigate.
    if (_hasExitedRoom) return;
    if (room == null || room.status == 'cancelled') {
      if (kDebugMode) {
        debugPrint('[ARENA] room listener cancelled/null — navigating out '
            'room=${_room.roomCode}');
      }
      final iAmHost = _uid != null && _uid == _room.hostUid;
      if (!_cancelledHandled && room != null && !iAmHost) {
        _cancelledHandled = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room was cancelled by the host')),
        );
      }
      _exitRoomOnce();
      return;
    }
    setState(() => _room = room);
    // Hand off to gameplay when status flips.
    if (!_navigated &&
        (room.status == 'countdown' ||
            room.status == 'playing' ||
            room.status == 'ready')) {
      _navigated = true;
      Future.microtask(() {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ArenaGamePage(initialRoom: room),
        ));
      });
    }
  }

  /// Single exit funnel. Cancels the room subscription before navigating so
  /// no stale listener tick can re-enter this screen mid-pop. Idempotent —
  /// repeated calls are no-ops.
  Future<void> _exitRoomOnce() async {
    if (_hasExitedRoom) {
      if (kDebugMode) {
        debugPrint('[ARENA] exit ignored — already exited room=${_room.roomCode}');
      }
      return;
    }
    _hasExitedRoom = true;
    if (kDebugMode) {
      debugPrint('[ARENA] exit room once room=${_room.roomCode}');
    }
    await _sub?.cancel();
    _sub = null;
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _toggleReady() async {
    if (_uid == null) return;
    final newReady = _isHost ? !_room.hostReady : !_room.guestReady;
    await ArenaRepo.instance.setReady(
      code: _room.roomCode,
      isHost: _isHost,
      ready: newReady,
    );
  }

  // Host is always implicitly ready (created the room). Start only requires
  // a joined guest who has pressed Ready, and the room must still be waiting.
  bool get _canStart =>
      _isHost &&
      _room.guestReady &&
      _room.guestUid != null &&
      _room.guestUid!.isNotEmpty &&
      _room.status == 'waiting';

  Future<void> _start() async {
    if (!_canStart || _busy) return;
    setState(() => _busy = true);
    try {
      await ArenaRepo.instance.startCountdown(room: _room);
      // The status flip will navigate into the game page via _onRoomChange.
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    await ArenaShareHelper.shareRoom(l10n: AppL10n.of(context), room: _room);
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _room.roomCode));
    if (!mounted) return;
    ArenaToast.success(context, AppL10n.of(context).codeCopied);
  }

  Future<bool> _confirmLeave() async {
    final l10n = AppL10n.of(context);
    final isHost = _isHost;
    // Lobby is always pre-play. Coins are not yet locked here, so hasBet is
    // false for the dialog's body copy (the warning copy is only relevant
    // mid-match where the bet is at risk).
    return showArenaLeaveDialog(
      context,
      beforePlay: true,
      hasBet: false,
      overrideTitle: isHost ? l10n.cancelRoomTitle : l10n.leaveRoomTitle,
    );
  }

  Future<void> _leave() => _onCancelPressed();

  Future<void> _onCancelPressed() async {
    if (_uid == null) return;
    if (_isCancelling || _hasExitedRoom) {
      if (kDebugMode) {
        debugPrint('[ARENA] cancel ignored '
            'isCancelling=$_isCancelling hasExited=$_hasExitedRoom');
      }
      return;
    }
    final ok = await _confirmLeave();
    if (!ok) return;
    if (_hasExitedRoom) return;
    setState(() => _isCancelling = true);
    final code = _room.roomCode;
    final iAmHost = _isHost;
    if (kDebugMode) {
      debugPrint('[ARENA] cancel button pressed room=$code uid=$_uid isHost=$iAmHost');
    }
    try {
      if (iAmHost) {
        await ArenaRepo.instance
            .cancelRoomAsHost(code)
            .timeout(const Duration(seconds: 6));
      } else {
        await ArenaRepo.instance
            .leaveRoomAsGuest(code)
            .timeout(const Duration(seconds: 6));
      }
      if (kDebugMode) {
        debugPrint('[ARENA] cancel success, exiting room=$code');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ARENA] cancel failed but exiting locally: $e');
      }
    }
    if (mounted) setState(() => _isCancelling = false);
    if (!_cancelledHandled && mounted) {
      _cancelledHandled = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(iAmHost ? 'Room cancelled' : 'You left the room')),
      );
    }
    await _exitRoomOnce();
  }

  String _formatRemaining() {
    final ms = _room.expiresAt - DateTime.now().millisecondsSinceEpoch;
    if (ms <= 0) return '00:00';
    final s = (ms / 1000).round();
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final selfReady = _isHost ? _room.hostReady : _room.guestReady;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isCancelling || _hasExitedRoom) return;
        await _onCancelPressed();
      },
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        variant: AppBackgroundVariant.homeNeon,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: Icons.arrow_back,
                      onTap: _leave,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.roomCode,
                      style: const TextStyle(
                        color: AppPalette.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CodeBanner(
                        code: _room.roomCode,
                        onCopy: _copyCode,
                      ),
                      const SizedBox(height: 14),
                      _SettingsRow(
                        rounds: _room.roundsCount,
                        boardSize: _room.boardSize,
                        timeLeft: _formatRemaining(),
                      ),
                      if (_room.roundMaps.length > 1) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppPalette.panel,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppPalette.primary.withValues(alpha: 0.4),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.primary
                                    .withValues(alpha: 0.1),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.map_outlined,
                                  size: 16, color: AppPalette.primary),
                              const SizedBox(width: 10),
                              Text(
                                l10n.mapsLabel.toUpperCase(),
                                style: const TextStyle(
                                  color: AppPalette.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Text(
                                    _room.roundMaps.join(' · '),
                                    style: const TextStyle(
                                      color: AppPalette.text,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _PlayersRow(room: _room, selfUid: _uid),
                      const SizedBox(height: 22),
                      // Host: only Share Room (full width). No Ready button.
                      // Guest: Share + Ready side-by-side.
                      _isHost
                          ? _ActionButton(
                              icon: Icons.share_rounded,
                              label: l10n.shareRoom,
                              onTap: _share,
                              background: AppPalette.panel,
                              foreground: AppPalette.text,
                              outline: AppPalette.strokeStrong,
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _ActionButton(
                                    icon: Icons.share_rounded,
                                    label: l10n.shareRoom,
                                    onTap: _share,
                                    background: AppPalette.panel,
                                    foreground: AppPalette.text,
                                    outline: AppPalette.strokeStrong,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _ActionButton(
                                    icon: selfReady
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked,
                                    label: l10n.readyLabel,
                                    onTap: _toggleReady,
                                    background: selfReady
                                        ? AppPalette.success
                                            .withValues(alpha: 0.22)
                                        : AppPalette.panel,
                                    foreground: selfReady
                                        ? AppPalette.success
                                        : AppPalette.text,
                                    outline: selfReady
                                        ? AppPalette.success
                                        : AppPalette.strokeStrong,
                                  ),
                                ),
                              ],
                            ),
                      if (_isHost) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _canStart && !_busy ? _start : null,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(l10n.startRoom),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.primary,
                              foregroundColor: AppPalette.bgTop,
                              disabledBackgroundColor:
                                  AppPalette.panelDeep,
                              disabledForegroundColor:
                                  AppPalette.textSubtle,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _isCancelling ? null : _leave,
                        icon: _isCancelling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppPalette.danger),
                                ),
                              )
                            : const Icon(Icons.exit_to_app,
                                color: AppPalette.danger),
                        label: Text(
                          _isHost ? l10n.cancelRoom : l10n.leaveRoom,
                          style: const TextStyle(
                            color: AppPalette.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

// ── Private widgets ─────────────────────────────────────────────────────────

class _CodeBanner extends StatelessWidget {
  final String code;
  final VoidCallback onCopy;
  const _CodeBanner({required this.code, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.homePanelStrong, AppPalette.panelDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppPalette.primary.withValues(alpha: 0.7),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.28),
            blurRadius: 26,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            l10n.roomCode.toUpperCase(),
            style: const TextStyle(
              color: AppPalette.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              code,
              style: TextStyle(
                color: AppPalette.text,
                fontSize: 58,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                fontFamily: 'Orbitron',
                shadows: [
                  Shadow(
                    color: AppPalette.primary.withValues(alpha: 0.55),
                    blurRadius: 22,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Copy pill: cyan outline, compact.
          _CopyCodePill(onCopy: onCopy, label: l10n.copyCode),
        ],
      ),
    );
  }
}

class _CopyCodePill extends StatelessWidget {
  final VoidCallback onCopy;
  final String label;
  const _CopyCodePill({required this.onCopy, required this.label});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppPalette.primary.withValues(alpha: 0.7),
              width: 1.2,
            ),
            color: AppPalette.primary.withValues(alpha: 0.08),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.copy_rounded, size: 16, color: AppPalette.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppPalette.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final int rounds;
  final int boardSize;
  final String timeLeft;
  const _SettingsRow({
    required this.rounds,
    required this.boardSize,
    required this.timeLeft,
  });

  Widget _pill({
    required IconData icon,
    required String label,
    required String value,
    required Color tint,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: AppPalette.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: tint.withValues(alpha: 0.45),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: 0.12),
              blurRadius: 14,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: tint, size: 18),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  color: AppPalette.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Row(
      children: [
        _pill(
          icon: Icons.refresh_rounded,
          label: l10n.rounds,
          value: '$rounds',
          tint: AppPalette.primary,
        ),
        _pill(
          icon: Icons.grid_4x4_rounded,
          label: l10n.boardLabel,
          value: '${boardSize}x$boardSize',
          tint: AppPalette.primary,
        ),
        _pill(
          icon: Icons.timer_outlined,
          label: l10n.timeLeftLabel,
          value: timeLeft,
          tint: AppPalette.accentPurple,
        ),
      ],
    );
  }
}

class _PlayersRow extends StatelessWidget {
  final ArenaRoom room;
  final String? selfUid;
  const _PlayersRow({required this.room, required this.selfUid});

  /// Pull a player's cosmetics entry from `room.players[uid]` defensively.
  /// Only the X/O skin keys are read — the equipped `selectedAvatar` is
  /// intentionally ignored in the lobby because the lobby always identifies
  /// the *person* (profile photo only), not the cosmetic frame.
  static _PlayerCosmetics _cosmeticsFor(ArenaRoom room, String? uid) {
    if (uid == null || uid.isEmpty) return const _PlayerCosmetics();
    final entry = room.players[uid];
    if (entry is! Map) return const _PlayerCosmetics();
    final xSkin = entry['selectedXSkin'];
    final oSkin = entry['selectedOSkin'];
    return _PlayerCosmetics(
      xSkin: xSkin is String && xSkin.isNotEmpty ? xSkin : null,
      oSkin: oSkin is String && oSkin.isNotEmpty ? oSkin : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hostCos = _cosmeticsFor(room, room.hostUid);
    final guestCos = _cosmeticsFor(room, room.guestUid);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _PlayerCard(
              name: room.hostName,
              photoUrl: room.hostPhoto,
              symbol: room.symbolFor(room.hostUid),
              // Host is always implicitly ready (no Ready button shown).
              ready: true,
              isYou: room.hostUid == selfUid,
              emptyLabel: null,
              xSkin: hostCos.xSkin,
              oSkin: hostCos.oSkin,
            ),
          ),
          const _VsBadge(),
          Expanded(
            child: _PlayerCard(
              name: room.guestName,
              photoUrl: room.guestPhoto,
              symbol: room.guestUid == null
                  ? ''
                  : room.symbolFor(room.guestUid ?? ''),
              ready: room.guestReady,
              isYou: room.guestUid != null && room.guestUid == selfUid,
              emptyLabel: room.guestUid == null
                  ? AppL10n.of(context).waitingForFriend
                  : null,
              xSkin: guestCos.xSkin,
              oSkin: guestCos.oSkin,
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class _PlayerCosmetics {
  final String? xSkin;
  final String? oSkin;
  const _PlayerCosmetics({this.xSkin, this.oSkin});
}

class _VsBadge extends StatelessWidget {
  const _VsBadge();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Center(
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppPalette.primary, AppPalette.accentPurple],
            ),
            boxShadow: [
              BoxShadow(
                color: AppPalette.primary.withValues(alpha: 0.45),
                blurRadius: 22,
              ),
            ],
            border: Border.all(
              color: AppPalette.text.withValues(alpha: 0.85),
              width: 1.4,
            ),
          ),
          child: const Text(
            'VS',
            style: TextStyle(
              color: AppPalette.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final String? name;
  final String? photoUrl;
  final String symbol;
  final bool ready;
  final bool isYou;
  final String? emptyLabel;
  final String? xSkin;
  final String? oSkin;

  const _PlayerCard({
    required this.name,
    required this.photoUrl,
    required this.symbol,
    required this.ready,
    required this.isYou,
    required this.emptyLabel,
    this.xSkin,
    this.oSkin,
  });

  @override
  Widget build(BuildContext context) {
    final empty = emptyLabel != null;
    final accent = isYou ? AppPalette.success : AppPalette.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.panel, AppPalette.panelDeep],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: empty
              ? AppPalette.strokeSoft
              : accent.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: empty ? 0.05 : 0.18),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ArenaProfileCircle(
            name: empty ? '' : (name ?? ''),
            photoUrl: empty ? null : photoUrl,
            size: 72,
            ringColors: isYou
                ? const <Color>[AppPalette.success, AppPalette.primary]
                : const <Color>[AppPalette.primary, AppPalette.accentPurple],
          ),
          const SizedBox(height: 10),
          Text(
            empty ? emptyLabel! : (name?.trim().isNotEmpty == true ? name! : '—'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: empty ? AppPalette.textSubtle : AppPalette.text,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          if (isYou && !empty) ...[
            const SizedBox(height: 4),
            const _YouTag(),
          ],
          const SizedBox(height: 10),
          ArenaSkinPreview(
            symbol: empty ? '' : symbol,
            xSkin: xSkin,
            oSkin: oSkin,
            size: 54,
          ),
          const SizedBox(height: 10),
          if (!empty) ReadyChip(ready: ready),
        ],
      ),
    );
  }
}

class _YouTag extends StatelessWidget {
  const _YouTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppPalette.success.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppPalette.success.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Text(
        AppL10n.of(context).youTag,
        style: const TextStyle(
          color: AppPalette.success,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final Color outline;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.background,
    required this.foreground,
    required this.outline,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: outline.withValues(alpha: 0.7),
              width: 1.2,
            ),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 0.4,
          ),
          shadowColor: outline.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

