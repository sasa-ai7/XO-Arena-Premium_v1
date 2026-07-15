import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'widgets/digit_keypad.dart';

class ArenaJoinRoomPage extends StatefulWidget {
  const ArenaJoinRoomPage({super.key});

  @override
  State<ArenaJoinRoomPage> createState() => _ArenaJoinRoomPageState();
}

class _ArenaJoinRoomPageState extends State<ArenaJoinRoomPage> {
  String _value = '';
  bool _busy = false;

  static const int _length = 6;

  void _addDigit(String d) {
    if (_value.length >= _length || _busy) return;
    setState(() => _value = _value + d);
  }

  void _delete() {
    if (_value.isEmpty || _busy) return;
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  Future<void> _paste() async {
    if (_busy) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text ?? '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (!mounted) return;
    if (digits.length < _length) {
      if (mounted) {
        ArenaToast.error(context, AppL10n.of(context).clipboardNoValidRoomCode);
      }
      return;
    }
    setState(() => _value = digits.substring(0, _length));
  }

  Future<void> _submit() async {
    if (_value.length != _length || _busy) return;
    final l10n = AppL10n.of(context);
    setState(() => _busy = true);
    try {
      final p = await SharedPreferences.getInstance();
      final name = (p.getString(Keys.username) ?? 'PLAYER').toUpperCase();
      final photoUrl = p.getString(Keys.profilePhotoUrl);
      final guestProfile = await loadArenaPlayerCosmetics();
      if (!mounted) return;
      // Outer timeout guards against any future code path inside joinRoom
      // that forgets a per-call timeout. joinRoom itself already bounds each
      // Firestore/RTDB call individually.
      final res = await ArenaRepo.instance
          .joinRoom(
            code: _value,
            guestName: name,
            guestPhoto: photoUrl,
            joinerCoins: LocalStore.coinsNotifier.value,
            guestProfile: guestProfile,
          )
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.isSuccess) {
        // Missions: joined a room by code (auth-gated → guests excluded).
        MissionService.instance.trackEvent('online_room_joined_by_code',
            matchId: res.room!.matchId);
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ArenaLobbyPage(initialRoom: res.room!),
        ));
        return;
      }
      String msg;
      ArenaToastKind kind = ArenaToastKind.error;
      switch (res.error) {
        case ArenaJoinError.notFound:
          msg = l10n.roomNotFound;
          break;
        case ArenaJoinError.full:
          msg = l10n.roomIsFull;
          break;
        case ArenaJoinError.expired:
          msg = l10n.roomExpired;
          break;
        case ArenaJoinError.selfJoin:
          msg = l10n.cantJoinOwnRoom;
          break;
        case ArenaJoinError.alreadyInActiveRoom:
          msg = l10n.alreadyInActiveRoom;
          kind = ArenaToastKind.warning;
          break;
        case ArenaJoinError.notEnoughCoins:
          msg = l10n.notEnoughCoinsJoin;
          break;
        case ArenaJoinError.kickedCooldown:
          // Render a live-countdown dialog instead of a flat snackbar so the
          // user knows exactly when they can retry. The dialog blocks
          // additional submits until the cooldown expires.
          if (res.kickCooldownUntilMs != null) {
            await _showKickedCooldownDialog(res.kickCooldownUntilMs!);
            if (mounted) setState(() => _busy = false);
          } else if (mounted) {
            ArenaToast.show(
              context,
              'You were kicked. Please try again later.',
              kind: ArenaToastKind.warning,
            );
          }
          return;
        case ArenaJoinError.notWaiting:
          msg = l10n.roomNotFound;
          break;
        case ArenaJoinError.networkTimeout:
          // TODO: localize this string in AppL10n.
          msg = 'Connection problem. Please check internet and try again.';
          break;
        default:
          msg = l10n.roomNotFound;
      }
      if (!mounted) return;
      ArenaToast.show(context, msg, kind: kind);
    } on TimeoutException {
      if (mounted) {
        ArenaToast.error(
          context,
          'Connection problem. Please check internet and try again.',
        );
      }
    } catch (_) {
      if (mounted) ArenaToast.error(context, l10n.roomNotFound);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showKickedCooldownDialog(int untilMs) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => _KickedCooldownDialog(untilMs: untilMs),
    );
    if (!mounted) return;
    setState(() => _value = '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final padHorizontal = 16.0;
    final keypadMaxWidth = min<double>(360, screenWidth - padHorizontal * 2);
    final slotsMaxWidth = min<double>(340, screenWidth - padHorizontal * 2);

    return Scaffold(
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
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.joinRoom,
                      style: const TextStyle(
                        color: AppPalette.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padHorizontal),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.roomCode,
                        style: const TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: DigitSlotsDisplay(
                          value: _value,
                          length: _length,
                          maxWidth: slotsMaxWidth,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: _PasteButton(
                          onTap: _paste,
                          label: l10n.pasteCode,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: SizedBox(
                          width: keypadMaxWidth,
                          child: DigitKeypad(
                            onDigit: _addDigit,
                            onDelete: _delete,
                            onEnter: _submit,
                            enterEnabled: _value.length == _length && !_busy,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_busy)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KickedCooldownDialog extends StatefulWidget {
  final int untilMs;
  const _KickedCooldownDialog({required this.untilMs});

  @override
  State<_KickedCooldownDialog> createState() => _KickedCooldownDialogState();
}

class _KickedCooldownDialogState extends State<_KickedCooldownDialog> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = widget.untilMs - DateTime.now().millisecondsSinceEpoch;
      if (remaining <= 0) {
        Navigator.of(context).maybePop();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatRemaining() {
    final ms = widget.untilMs - DateTime.now().millisecondsSinceEpoch;
    if (ms <= 0) return '00:00';
    final s = (ms / 1000).ceil();
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: AppPalette.panel,
          border: Border.all(
            color: AppPalette.danger.withValues(alpha: 0.7),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: AppPalette.danger.withValues(alpha: 0.30),
              blurRadius: 30,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.block_rounded,
              color: AppPalette.danger,
              size: 44,
            ),
            const SizedBox(height: 10),
            const Text(
              'You were kicked',
              style: TextStyle(
                color: AppPalette.danger,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You can rejoin in ${_formatRemaining()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.danger.withValues(alpha: 0.18),
                  foregroundColor: AppPalette.danger,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side:
                        const BorderSide(color: AppPalette.danger, width: 1.2),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasteButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  const _PasteButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppPalette.primary.withValues(alpha: 0.6),
              width: 1.1,
            ),
            color: AppPalette.primary.withValues(alpha: 0.08),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.content_paste_rounded,
                  size: 16, color: AppPalette.primary),
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
