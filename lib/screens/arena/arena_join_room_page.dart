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
                            enterEnabled:
                                _value.length == _length && !_busy,
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
