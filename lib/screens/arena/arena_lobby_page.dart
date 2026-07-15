import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../models/arena/arena_chat_signal.dart';
import '../../models/arena/arena_room.dart';
import '../../models/game_avatar.dart';
import '../../services/arena/arena_chat_service.dart';
import '../../services/arena/arena_presence_service.dart';
import '../../services/arena/arena_repo.dart';
import '../../services/local_store.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/arena_toast.dart';
import '../../widgets/full_avatar_display.dart';
import 'arena_game_page.dart';
import 'arena_share_helper.dart';
import 'widgets/arena_chat_widgets.dart';
import 'widgets/arena_leave_dialog.dart';
import 'widgets/arena_profile_circle.dart';
import 'widgets/arena_skin_preview.dart';
import 'widgets/arena_vs_badge.dart';
import 'widgets/ready_chip.dart';

class ArenaLobbyPage extends StatefulWidget {
  final ArenaRoom initialRoom;
  const ArenaLobbyPage({super.key, required this.initialRoom});

  @override
  State<ArenaLobbyPage> createState() => _ArenaLobbyPageState();
}

class _LobbyDisconnectOverlay extends StatelessWidget {
  final int? deadlineAtMs;
  const _LobbyDisconnectOverlay({required this.deadlineAtMs});

  @override
  Widget build(BuildContext context) {
    final remaining =
        ((deadlineAtMs ?? 0) - DateTime.now().millisecondsSinceEpoch)
            .clamp(0, 120000);
    final totalSeconds = (remaining / 1000).ceil();
    final clock = '${(totalSeconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(totalSeconds % 60).toString().padLeft(2, '0')}';
    return AbsorbPointer(
      absorbing: true,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.42),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            decoration: BoxDecoration(
              color: AppPalette.panel.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppPalette.gold),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppPalette.gold.withValues(alpha: 0.25),
                  blurRadius: 28,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CircularProgressIndicator(color: AppPalette.gold),
                const SizedBox(height: 14),
                const Text(
                  'Waiting for opponent',
                  style: TextStyle(
                    color: AppPalette.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Reconnecting…',
                    style: TextStyle(color: AppPalette.textMuted)),
                const SizedBox(height: 12),
                Text(
                  clock,
                  style: const TextStyle(
                    color: AppPalette.gold,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
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

class _ArenaLobbyPageState extends State<ArenaLobbyPage>
    with WidgetsBindingObserver {
  late ArenaRoom _room;
  StreamSubscription<ArenaRoom?>? _sub;
  Timer? _ticker;
  bool _busy = false;
  bool _navigated = false;
  bool _isCancelling = false;
  bool _cancelledHandled = false;
  bool _hasExitedRoom = false;
  bool _kickedHandled = false;
  ArenaPresenceService? _presence;
  ArenaChatService? _chatService;
  StreamSubscription<Map<String, ArenaChatSignal>>? _chatSub;
  Map<String, ArenaChatSignal> _chatSignals = const <String, ArenaChatSignal>{};
  bool _showQuickEmojis = true;
  List<String> _equippedEmojis = const <String>[];
  bool _disconnectMutationPending = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool get _isHost => _uid != null && _uid == _room.hostUid;

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    _loadEquippedEmojis();
    _sub = ArenaRepo.instance.watchRoom(_room.roomCode).listen(_onRoomChange);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
        _syncDisconnectState();
      }
    });
    WidgetsBinding.instance.addObserver(this);
    final uid = _uid;
    if (uid != null && uid.isNotEmpty) {
      _presence = ArenaPresenceService(code: _room.roomCode, selfUid: uid);
      _presence!.start();
      _startChat(uid);
    }
  }

  void _startChat(String uid) {
    final selfName = uid == _room.hostUid
        ? _room.hostName
        : (_room.guestName?.trim().isNotEmpty == true
            ? _room.guestName!
            : 'PLAYER');
    try {
      final service = ArenaChatService(
        roomCode: _room.roomCode,
        selfUid: uid,
        selfName: selfName,
      );
      _chatService = service;
      _chatSub = service.watchSignals().listen(
        (signals) {
          if (mounted) setState(() => _chatSignals = signals);
        },
        onError: (_) {},
      );
    } catch (_) {
      _chatService = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Part 1: presence-only on background — no auto-leave/cancel.
    // The presence service handles online→offline state automatically.
    if (state == AppLifecycleState.resumed) _presence?.markOnlineNow();
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
        ArenaToast.warning(context, AppL10n.of(context).roomCancelledToast);
      }
      _exitRoomOnce();
      return;
    }
    // Kick detection: was guest, now host removed me + a kickedUsers entry
    // exists for my uid. The host's atomic kick write nulls guestUid and
    // stamps kickedUsers[<self>] in one transaction, so this branch is the
    // canonical signal that I was kicked.
    final selfUid = _uid;
    if (!_kickedHandled &&
        selfUid != null &&
        _room.guestUid == selfUid &&
        room.guestUid != selfUid &&
        room.kickedUsers[selfUid] != null) {
      _kickedHandled = true;
      if (kDebugMode) {
        debugPrint('[ARENA_KICK] guest_detected_kicked uid=$selfUid '
            'room=${room.roomCode}');
      }
      // The host cannot clear our active-room mirror under the Firestore rules,
      // so the kicked guest's own client must clear it here — otherwise a later
      // "Create Room" tap would resume this dead room.
      ArenaRepo.instance.clearActiveRoomMirror(selfUid);
      if (kDebugMode) {
        debugPrint('[ARENA_KICK] guest_exit_after_kick uid=$selfUid '
            'room=${room.roomCode}');
      }
      ArenaToast.error(context, AppL10n.of(context).removedFromRoomToast);
      _exitRoomOnce();
      return;
    }
    setState(() => _room = room);
    _syncDisconnectState();
    // Hand off to gameplay when status flips.
    if (!_navigated &&
        (room.status == 'countdown' ||
            room.status == 'playing' ||
            room.status == 'ready' ||
            (room.status == 'finished' &&
                room.result == 'disconnect_forfeit'))) {
      _navigated = true;
      Future.microtask(() {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ArenaGamePage(initialRoom: room),
        ));
      });
    }
  }

  Future<void> _syncDisconnectState() async {
    if (!mounted || _disconnectMutationPending) return;
    final selfUid = _uid;
    if (selfUid == null || _room.status == 'finished') return;
    final opponentUid = _room.opponentOf(selfUid);
    if (opponentUid.isEmpty) return;
    final state = _presence?.derive(_room, opponentUid);
    _disconnectMutationPending = true;
    try {
      if (state == PresenceState.offline) {
        if (_room.disconnectUid == null || _room.disconnectUid!.isEmpty) {
          await ArenaRepo.instance.startDisconnectGrace(
            code: _room.roomCode,
            disconnectedUid: opponentUid,
          );
        } else if (_room.disconnectUid == opponentUid &&
            DateTime.now().millisecondsSinceEpoch >=
                (_room.disconnectDeadlineAt ?? 1 << 62)) {
          await ArenaRepo.instance.finishRoomByDisconnectForfeit(
            code: _room.roomCode,
            disconnectedUid: opponentUid,
            winnerUid: selfUid,
          );
        }
      } else if (state == PresenceState.online &&
          _room.disconnectUid == opponentUid) {
        await ArenaRepo.instance.clearDisconnectGrace(
          code: _room.roomCode,
          reconnectedUid: opponentUid,
        );
      }
    } finally {
      _disconnectMutationPending = false;
    }
  }

  /// Single exit funnel. Cancels the room subscription before navigating so
  /// no stale listener tick can re-enter this screen mid-pop. Idempotent —
  /// repeated calls are no-ops.
  Future<void> _exitRoomOnce() async {
    if (_hasExitedRoom) {
      if (kDebugMode) {
        debugPrint(
            '[ARENA] exit ignored — already exited room=${_room.roomCode}');
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
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _chatSub?.cancel();
    _chatService?.dispose();
    _ticker?.cancel();
    // A lobby -> game replacement is not a disconnect. Avoid stamping an
    // offline presence after the game page has already marked this uid online.
    _presence?.stop(markOffline: !_navigated);
    super.dispose();
  }

  Future<void> _onKickGuestPressed() async {
    if (!_isHost) return;
    final guestUid = _room.guestUid;
    if (guestUid == null || guestUid.isEmpty) return;
    final ok = await _confirmKickDialog();
    if (ok != true) return;
    final result = await ArenaRepo.instance.kickGuest(code: _room.roomCode);
    if (!mounted) return;
    if (result.success) return;
    final l10n = AppL10n.of(context);
    switch (result.failure) {
      case ArenaKickFailure.noGuest:
        ArenaToast.warning(context, l10n.noPlayerToRemove);
        break;
      case ArenaKickFailure.badStatus:
        ArenaToast.warning(context, l10n.removePlayerLobbyOnly);
        break;
      case ArenaKickFailure.permissionDenied:
        ArenaToast.error(context, l10n.permissionDeniedRetry);
        break;
      case ArenaKickFailure.network:
        ArenaToast.error(context, l10n.networkIssueRetry);
        break;
      case ArenaKickFailure.notHost:
      case ArenaKickFailure.unknown:
      case null:
        ArenaToast.error(context, l10n.couldNotKickPlayer);
        break;
    }
  }

  Future<bool?> _confirmKickDialog() async {
    final l10n = AppL10n.of(context);
    final guestName =
        _room.guestName?.trim().isNotEmpty == true ? _room.guestName! : '—';
    final guestPhoto = _room.guestPhoto;
    final guestEntry = _room.players[_room.guestUid];
    final guestAvatar = guestEntry is Map
        ? gameAvatarFromStoredValue(guestEntry['selectedAvatar'])
        : null;
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
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
              ArenaProfileAvatar(
                profileImageUrl: guestPhoto,
                equippedAvatarFrameAsset: guestAvatar?.assetPath,
                equippedAvatar: guestAvatar,
                size: 60,
                fallbackInitials: guestName,
                optionalGlow: [
                  BoxShadow(
                    color: AppPalette.danger.withValues(alpha: 0.30),
                    blurRadius: 16,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.kickPlayerTitle,
                style: const TextStyle(
                  color: AppPalette.danger,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.kickPlayerBody(guestName),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.text,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(
                        l10n.cancelBtn,
                        style: const TextStyle(
                          color: AppPalette.textMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            AppPalette.danger.withValues(alpha: 0.18),
                        foregroundColor: AppPalette.danger,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                              color: AppPalette.danger, width: 1.2),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          l10n.kickLabel,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

  Future<void> _sendMessage(String text) async {
    final service = _chatService;
    if (service == null) return;
    final signal = await service.sendMessage(text);
    if (!mounted) return;
    setState(() {
      _chatSignals = <String, ArenaChatSignal>{
        ..._chatSignals,
        signal.senderUid: signal,
      };
    });
  }

  Future<void> _sendEmoji(String emoji) async {
    final service = _chatService;
    if (service == null) return;
    await service.sendEmoji(emoji);
  }

  Future<void> _loadEquippedEmojis() async {
    try {
      final emojis = await LocalStore.equippedEmojis();
      if (mounted) setState(() => _equippedEmojis = emojis);
    } catch (_) {}
  }

  void _onChatError(Object error) {
    if (!mounted) return;
    // Cooldown / unsupported reactions are expected — do not alarm the player.
    if (error is ArenaChatException &&
        (error.failure == ArenaChatFailure.cooldown ||
            error.failure == ArenaChatFailure.unsupportedEmoji)) {
      return;
    }
    ArenaToast.error(context, AppL10n.of(context).networkIssueRetry);
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
      debugPrint(
          '[ARENA] cancel button pressed room=$code uid=$_uid isHost=$iAmHost');
    }
    try {
      // Single safe leave funnel. The lobby is pre-play with no committed bet,
      // so this resolves to a clean cancel (host) / seat-clear (guest); if a
      // bet were ever locked here it would forfeit fairly instead.
      await ArenaRepo.instance.resolvePlayerLeaveRoom(
        roomCode: code,
        leaverUid: _uid!,
        reason: 'explicit_leave',
      );
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
      ArenaToast.info(
          context,
          iAmHost
              ? AppL10n.of(context).roomCancelledToast
              : AppL10n.of(context).leftRoomToast);
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
            child: Stack(
              children: <Widget>[
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AppIconButton(
                            icon: Icons.arrow_back,
                            onTap: _leave,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.roomLobbyTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: homeTitleFont(context, fontSize: 25),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.roomLobbySubtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: safeInter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.textMuted,
                                  ),
                                ),
                              ],
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
                              // Once a guest has joined the 10-minute creation TTL no
                              // longer applies (occupied rooms use the 20-minute
                              // inactivity rule), so show a neutral "Room Active"
                              // status instead of a misleading countdown.
                              occupied: _room.guestUid != null &&
                                  _room.guestUid!.isNotEmpty,
                            ),
                            const SizedBox(height: 10),
                            _BetPanel(room: _room),
                            if (_room.roundMaps.length > 1) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppPalette.panel,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppPalette.primary
                                        .withValues(alpha: 0.4),
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
                                        physics: const BouncingScrollPhysics(),
                                        child: Row(
                                          children: [
                                            for (var i = 0;
                                                i < _room.roundMaps.length;
                                                i++) ...[
                                              _MapChip(
                                                round: i + 1,
                                                map: _room.roundMaps[i],
                                              ),
                                              if (i !=
                                                  _room.roundMaps.length - 1)
                                                const SizedBox(width: 7),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            _PlayersRow(
                              room: _room,
                              selfUid: _uid,
                              hostPresence:
                                  _presence?.derive(_room, _room.hostUid),
                              guestPresence: _room.guestUid == null
                                  ? null
                                  : _presence?.derive(_room, _room.guestUid!),
                              onKickGuest: _isHost &&
                                      _room.guestUid != null &&
                                      (_room.status == 'waiting' ||
                                          _room.status == 'ready' ||
                                          _room.status == 'countdown')
                                  ? _onKickGuestPressed
                                  : null,
                            ),
                            _LobbyReactionRow(
                              hostSignal: _chatSignals[_room.hostUid],
                              guestSignal: _room.guestUid == null
                                  ? null
                                  : _chatSignals[_room.guestUid!],
                            ),
                            const SizedBox(height: 14),
                            OnlineChatBar(
                              enabled: _chatService != null,
                              onSend: _sendMessage,
                              onEmojiPressed: () => setState(
                                () => _showQuickEmojis = !_showQuickEmojis,
                              ),
                              onError: _onChatError,
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: _showQuickEmojis
                                  ? Padding(
                                      key: const ValueKey<String>(
                                          'quick-emojis'),
                                      padding: const EdgeInsets.only(top: 8),
                                      child: QuickEmojiBar(
                                        emojis: _equippedEmojis,
                                        enabled: _chatService != null,
                                        showLabel: false,
                                        onSelected: _sendEmoji,
                                        onError: _onChatError,
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey<String>(
                                          'quick-emojis-hidden'),
                                    ),
                            ),
                            const SizedBox(height: 14),
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
                                  onPressed:
                                      _canStart && !_busy ? _start : null,
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
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
                if (_room.disconnectUid != null &&
                    _room.disconnectUid!.isNotEmpty &&
                    _room.disconnectUid != _uid)
                  Positioned.fill(
                    child: _LobbyDisconnectOverlay(
                      deadlineAtMs: _room.disconnectDeadlineAt,
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

class _LobbyReactionRow extends StatelessWidget {
  final ArenaChatSignal? hostSignal;
  final ArenaChatSignal? guestSignal;

  const _LobbyReactionRow({
    required this.hostSignal,
    required this.guestSignal,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PlayerReactionBubble(
            signal: hostSignal,
            maxWidth: 150,
            accent: AppPalette.primary,
          ),
        ),
        const SizedBox(width: 46),
        Expanded(
          child: PlayerReactionBubble(
            signal: guestSignal,
            maxWidth: 150,
            accent: AppPalette.accentPurple,
          ),
        ),
      ],
    );
  }
}

/// Lobby bet/prize panel. Shows the coin stake + prize pool for betting rooms,
/// or a "Friendly Match · No Bet" line otherwise.
class _BetPanel extends StatelessWidget {
  final ArenaRoom room;
  const _BetPanel({required this.room});

  @override
  Widget build(BuildContext context) {
    final betEnabled = room.betEnabled && room.betAmount > 0;
    if (kDebugMode) {
      debugPrint('[ARENA_BET_UI] lobby betEnabled=$betEnabled '
          'bet=${room.betAmount} prize=${room.prizePool}');
    }
    if (!betEnabled) {
      final l10n = AppL10n.of(context);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppPalette.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppPalette.strokeSoft, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.handshake_rounded,
                color: AppPalette.textMuted, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.friendlyMatchNoBet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppPalette.gold.withValues(alpha: 0.12),
            AppPalette.panel,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppPalette.gold.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.gold.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _BetStat(
            label: AppL10n.of(context).betLabel.toUpperCase(),
            value: room.betAmount,
            color: AppPalette.gold,
          ),
          Container(width: 1, height: 34, color: AppPalette.strokeSoft),
          _BetStat(
            label: AppL10n.of(context).prizePoolLabel.toUpperCase(),
            value: room.prizePool,
            color: AppPalette.goldHighlight,
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _BetStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final bool highlight;
  const _BetStat({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = highlight ? 20.0 : 18.0;
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/coin/COIN.webp',
                width: iconSize,
                height: iconSize,
                cacheWidth: (iconSize * 3).round(),
                errorBuilder: (_, __, ___) => Icon(
                  Icons.monetization_on_rounded,
                  color: AppPalette.gold,
                  size: iconSize,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$value',
                style: TextStyle(
                  color: color,
                  fontSize: highlight ? 19 : 17,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Orbitron',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CodeBanner extends StatelessWidget {
  final String code;
  final VoidCallback onCopy;
  const _CodeBanner({required this.code, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
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
                fontSize: 48,
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
              const Icon(Icons.copy_rounded,
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

class _MapChip extends StatelessWidget {
  final int round;
  final String map;

  const _MapChip({required this.round, required this.map});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppPalette.primary.withValues(alpha: 0.36),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$round',
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            map,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: AppPalette.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final int rounds;
  final int boardSize;
  final String timeLeft;
  final bool occupied;
  const _SettingsRow({
    required this.rounds,
    required this.boardSize,
    required this.timeLeft,
    this.occupied = false,
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
        occupied
            ? _pill(
                icon: Icons.bolt_rounded,
                label: l10n.statusLabel,
                value: l10n.activeLabel,
                tint: AppPalette.success,
              )
            : _pill(
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
  final PresenceState? hostPresence;
  final PresenceState? guestPresence;
  final VoidCallback? onKickGuest;
  const _PlayersRow({
    required this.room,
    required this.selfUid,
    required this.hostPresence,
    required this.guestPresence,
    required this.onKickGuest,
  });

  /// Pull a player's cosmetics entry from `room.players[uid]` defensively —
  /// X/O skins plus the equipped `selectedAvatar` (so the lobby shows the
  /// same selected avatar as Home/Settings instead of initials only).
  static _PlayerCosmetics _cosmeticsFor(ArenaRoom room, String? uid) {
    if (uid == null || uid.isEmpty) return const _PlayerCosmetics();
    final entry = room.players[uid];
    if (entry is! Map) return const _PlayerCosmetics();
    final xSkin = entry['selectedXSkin'];
    final oSkin = entry['selectedOSkin'];
    return _PlayerCosmetics(
      xSkin: xSkin is String && xSkin.isNotEmpty ? xSkin : null,
      oSkin: oSkin is String && oSkin.isNotEmpty ? oSkin : null,
      avatar: gameAvatarFromStoredValue(entry['selectedAvatar']),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hostCos = _cosmeticsFor(room, room.hostUid);
    final guestCos = _cosmeticsFor(room, room.guestUid);
    final l10n = AppL10n.of(context);
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
              roleLabel: l10n.hostLabel.toUpperCase(),
              xSkin: hostCos.xSkin,
              oSkin: hostCos.oSkin,
              avatar: hostCos.avatar,
              presence: hostPresence,
              onKick: null,
            ),
          ),
          const Center(child: ArenaVsBadge()),
          Expanded(
            child: _PlayerCard(
              name: room.guestName,
              photoUrl: room.guestPhoto,
              symbol: room.guestUid == null
                  ? ''
                  : room.symbolFor(room.guestUid ?? ''),
              ready: room.guestReady,
              isYou: room.guestUid != null && room.guestUid == selfUid,
              emptyLabel: room.guestUid == null ? l10n.waitingForFriend : null,
              roleLabel:
                  room.guestUid == null ? null : l10n.guestLabel.toUpperCase(),
              xSkin: guestCos.xSkin,
              oSkin: guestCos.oSkin,
              avatar: guestCos.avatar,
              presence: room.guestUid == null ? null : guestPresence,
              // Only show the kick button when the guest seat is filled and
              // the host invoked this row with a callback (host-only).
              onKick: room.guestUid != null ? onKickGuest : null,
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
  final GameAvatar? avatar;
  const _PlayerCosmetics({this.xSkin, this.oSkin, this.avatar});
}

class _PlayerCard extends StatelessWidget {
  final String? name;
  final String? photoUrl;
  final String symbol;
  final bool ready;
  final bool isYou;
  final String? emptyLabel;
  final String? roleLabel;
  final String? xSkin;
  final String? oSkin;
  final GameAvatar? avatar;
  final PresenceState? presence;
  final VoidCallback? onKick;

  const _PlayerCard({
    required this.name,
    required this.photoUrl,
    required this.symbol,
    required this.ready,
    required this.isYou,
    required this.emptyLabel,
    this.roleLabel,
    this.xSkin,
    this.oSkin,
    this.avatar,
    this.presence,
    this.onKick,
  });

  @override
  Widget build(BuildContext context) {
    final empty = emptyLabel != null;
    final accent = isYou ? AppPalette.success : AppPalette.primary;
    // Responsive sizing from the screen width (not LayoutBuilder, which would
    // conflict with the parent IntrinsicHeight). Clamped so the layout stays
    // compact on small phones and never overflows.
    final screenW = MediaQuery.sizeOf(context).width;
    final avatarSize = (screenW * 0.17).clamp(52.0, 66.0);
    final markSize = (screenW * 0.13).clamp(42.0, 50.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.panel, AppPalette.panelDeep],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: empty ? AppPalette.strokeSoft : accent.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: empty ? 0.05 : 0.18),
            blurRadius: 16,
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAvatarCircle(size: avatarSize, empty: empty),
              const SizedBox(height: 6),
              Text(
                empty
                    ? emptyLabel!
                    : (name?.trim().isNotEmpty == true ? name! : '—'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: empty ? AppPalette.textSubtle : AppPalette.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              // Compact role + YOU chips on one line (only takes the space it
              // needs — no large gaps).
              if (!empty &&
                  (isYou || (roleLabel != null && roleLabel!.isNotEmpty))) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isYou) const _YouTag(),
                    if (isYou && roleLabel != null && roleLabel!.isNotEmpty)
                      const SizedBox(width: 5),
                    if (roleLabel != null && roleLabel!.isNotEmpty)
                      _RoleTag(label: roleLabel!),
                  ],
                ),
              ],
              if (!empty && presence != null) ...[
                const SizedBox(height: 3),
                _LobbyPresenceLabel(state: presence!),
              ],
              const SizedBox(height: 8),
              ArenaSkinPreview(
                symbol: empty ? '' : symbol,
                xSkin: xSkin,
                oSkin: oSkin,
                size: markSize,
              ),
              const SizedBox(height: 8),
              if (!empty) ReadyChip(ready: ready),
            ],
          ),
          if (!empty && onKick != null)
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: AppPalette.danger.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onKick,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppPalette.danger.withValues(alpha: 0.65),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_remove_alt_1_rounded,
                      size: 15,
                      color: AppPalette.danger,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Selected in-game avatar first, then profile photo / initials — same
  /// priority and shared avatar widgets used on Home/Settings/match cards.
  Widget _buildAvatarCircle({required double size, required bool empty}) {
    final ringColors = isYou
        ? const <Color>[AppPalette.success, AppPalette.primary]
        : const <Color>[AppPalette.primary, AppPalette.accentPurple];
    if (empty) {
      return ArenaProfileCircle(
        name: '',
        photoUrl: null,
        size: size,
        ringColors: ringColors,
      );
    }
    final presenceColor = switch (presence) {
      PresenceState.online => AppPalette.success,
      PresenceState.weak => AppPalette.warning,
      PresenceState.offline => AppPalette.danger,
      null => AppPalette.success,
    };
    if (isYou) {
      return ArenaProfileAvatar.current(
        size: size,
        fallbackInitials: name ?? '',
        showOnlineStatus: presence != null,
        statusColor: presenceColor,
      );
    }
    return ArenaProfileAvatar(
      profileImageUrl: photoUrl,
      equippedAvatarFrameAsset: avatar?.assetPath,
      equippedAvatar: avatar,
      size: size,
      fallbackInitials: name ?? '',
      showOnlineStatus: presence != null,
      statusColor: presenceColor,
    );
  }
}

/// Compact HOST/GUEST role chip shown under the player name.
class _RoleTag extends StatelessWidget {
  final String label;
  const _RoleTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppPalette.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppPalette.primary.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppPalette.primary,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _LobbyPresenceLabel extends StatelessWidget {
  final PresenceState state;
  const _LobbyPresenceLabel({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final color = switch (state) {
      PresenceState.online => AppPalette.success,
      PresenceState.weak => AppPalette.warning,
      PresenceState.offline => AppPalette.danger,
    };
    final label = switch (state) {
      PresenceState.online => l10n.onlineLabel,
      PresenceState.weak => l10n.weakConnectionLabel,
      PresenceState.offline => l10n.connectionLostLabel,
    };
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
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
