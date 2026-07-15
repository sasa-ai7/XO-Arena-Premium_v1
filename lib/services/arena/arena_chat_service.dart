import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import '../../models/arena/arena_chat_signal.dart';
import '../../models/game_emoji.dart';
import '../app_mode_service.dart';
import '../connectivity_service.dart';
import 'arena_repo.dart';

enum ArenaChatFailure {
  disposed,
  invalidMessage,
  unsupportedEmoji,
  cooldown,
  roomUnavailable,
  notRoomMember,
  roomClosed,
  network,
}

class ArenaChatException implements Exception {
  final ArenaChatFailure failure;
  final String message;

  const ArenaChatException(this.failure, this.message);

  @override
  String toString() => 'ArenaChatException(${failure.name}): $message';
}

/// Realtime quick-chat transport for one signed-in player in one Arena room.
///
/// The service owns no stream subscriptions: callers subscribe through
/// [watchSignals] or [watchSignal] and cancel those subscriptions in their
/// page's `dispose`. Calling [dispose] prevents future writes. Signals live at
/// `rooms/{roomCode}/chatSignals/{uid}` and overwrite per player, so room data
/// cannot grow without bound.
class ArenaChatService {
  ArenaChatService({
    required String roomCode,
    required String selfUid,
    required String selfName,
  })  : roomCode = roomCode.trim(),
        selfUid = selfUid.trim(),
        selfName = _normalizeName(selfName) {
    if (!RegExp(r'^\d{6}$').hasMatch(this.roomCode)) {
      throw ArgumentError.value(roomCode, 'roomCode', 'Must be 6 digits.');
    }
    if (!_isSafeFirebaseKey(this.selfUid)) {
      throw ArgumentError.value(selfUid, 'selfUid', 'Invalid Firebase uid.');
    }
    _roomRef = ArenaRepo.instance.roomRef(this.roomCode);
    _signalsRef = _roomRef.child('chatSignals');
  }

  static const Duration _membershipTimeout = Duration(seconds: 6);
  static const Set<String> _writableStatuses = <String>{
    'waiting',
    'ready',
    'countdown',
    'playing',
    'round_end',
  };

  final String roomCode;
  final String selfUid;
  final String selfName;

  late final DatabaseReference _roomRef;
  late final DatabaseReference _signalsRef;

  bool _disposed = false;
  bool _membershipVerified = false;
  Future<void>? _membershipCheck;

  /// All currently stored player signals keyed by sender uid.
  ///
  /// Malformed entries are skipped defensively. RTDB errors remain stream
  /// errors so the owning page can surface its normal connection UI.
  Stream<Map<String, ArenaChatSignal>> watchSignals() {
    _ensureNotDisposed();
    return _signalsRef.onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return const <String, ArenaChatSignal>{};

      final parsed = <String, ArenaChatSignal>{};
      for (final entry in raw.entries) {
        final uid = entry.key.toString();
        if (!_isSafeFirebaseKey(uid)) continue;
        final signal = ArenaChatSignal.tryParse(
          entry.value,
          expectedUid: uid,
        );
        if (signal != null) parsed[uid] = signal;
      }
      return Map<String, ArenaChatSignal>.unmodifiable(parsed);
    });
  }

  /// Watches one player's latest signal. Useful when each player card owns
  /// its own small subscription rather than the page keeping a signal map.
  Stream<ArenaChatSignal?> watchSignal(String playerUid) {
    _ensureNotDisposed();
    final uid = playerUid.trim();
    if (!_isSafeFirebaseKey(uid)) {
      throw ArgumentError.value(
          playerUid, 'playerUid', 'Invalid Firebase uid.');
    }
    return _signalsRef.child(uid).onValue.map(
          (event) => ArenaChatSignal.tryParse(
            event.snapshot.value,
            expectedUid: uid,
          ),
        );
  }

  /// Sends a trimmed, non-empty message of at most 120 UTF-16 code units.
  Future<ArenaChatSignal> sendMessage(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty ||
        normalized.length > ArenaChatSignal.maxMessageLength) {
      throw const ArenaChatException(
        ArenaChatFailure.invalidMessage,
        'Message must contain 1 to 120 characters.',
      );
    }
    return _publish(ArenaChatSignalType.message, normalized);
  }

  /// Minimum gap between two emoji sends from this client (anti-spam). Short
  /// enough that a player can re-send the same reaction almost immediately —
  /// the replay is intentional — while still preventing hold-to-spam.
  static const Duration _emojiCooldown = Duration(seconds: 3);
  int _lastEmojiSentMs = 0;

  Future<ArenaChatSignal> sendEmoji(String emoji) async {
    final normalized = emoji.trim();
    if (!EmojiCatalog.isValidId(normalized)) {
      throw const ArenaChatException(
        ArenaChatFailure.unsupportedEmoji,
        'Unsupported quick reaction.',
      );
    }
    // Lightweight cooldown so rapid taps cannot spam the room.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastEmojiSentMs < _emojiCooldown.inMilliseconds) {
      throw const ArenaChatException(
        ArenaChatFailure.cooldown,
        'Reaction cooldown active.',
      );
    }
    _lastEmojiSentMs = now;
    try {
      return await _publish(ArenaChatSignalType.emoji, normalized);
    } catch (_) {
      if (_lastEmojiSentMs == now) _lastEmojiSentMs = 0;
      rethrow;
    }
  }

  /// Semantic alias used by reaction-oriented UI call sites.
  Future<ArenaChatSignal> sendReaction(String emoji) => sendEmoji(emoji);

  Future<ArenaChatSignal> _publish(
    ArenaChatSignalType type,
    String payload,
  ) async {
    _ensureNotDisposed();
    if (!AppModeService.canUseOnlineServices ||
        !ConnectivityService().isOnline.value) {
      throw const ArenaChatException(
        ArenaChatFailure.network,
        'You are offline. Reconnect and try again.',
      );
    }
    await _ensureMembership();
    _ensureNotDisposed();

    final now = DateTime.now().millisecondsSinceEpoch;
    final nonce = DateTime.now().microsecondsSinceEpoch.toString();
    final signal = ArenaChatSignal(
      type: type,
      senderUid: selfUid,
      senderName: selfName,
      payload: payload,
      sentAtMs: now,
      clientSentAtMs: now,
      nonce: nonce,
    );

    await _signalsRef.child(selfUid).set(<String, Object?>{
      'type': type.name,
      'senderUid': selfUid,
      'senderName': selfName,
      'payload': payload,
      'sentAtMs': ServerValue.timestamp,
      'clientSentAtMs': now,
      'nonce': nonce,
    });
    return signal;
  }

  /// Best-effort explicit cleanup. Normal screen disposal should leave the
  /// signal in place; [PlayerReactionBubble] hides it by age and room deletion
  /// removes the subtree atomically with the rest of the room.
  Future<void> clearOwnSignal() async {
    _ensureNotDisposed();
    await _signalsRef.child(selfUid).remove();
  }

  /// Reads the room once before this service's first write. Subsequent writes
  /// rely on the live RTDB validation rule, which re-checks membership and room
  /// status on every update and therefore still blocks a kicked player.
  Future<void> _ensureMembership() async {
    if (_membershipVerified) return;
    final inFlight = _membershipCheck;
    if (inFlight != null) return inFlight;

    final check = _readAndValidateMembership();
    _membershipCheck = check;
    try {
      await check;
      _membershipVerified = true;
    } finally {
      if (identical(_membershipCheck, check)) _membershipCheck = null;
    }
  }

  Future<void> _readAndValidateMembership() async {
    DataSnapshot snapshot;
    try {
      snapshot = await _roomRef.get().timeout(_membershipTimeout);
    } on TimeoutException {
      throw const ArenaChatException(
        ArenaChatFailure.network,
        'Timed out while validating room membership.',
      );
    }

    final raw = snapshot.value;
    if (!snapshot.exists || raw is! Map) {
      throw const ArenaChatException(
        ArenaChatFailure.roomUnavailable,
        'The room is no longer available.',
      );
    }
    final hostUid = (raw['hostUid'] ?? '').toString();
    final guestUid = (raw['guestUid'] ?? '').toString();
    if (selfUid != hostUid && selfUid != guestUid) {
      throw const ArenaChatException(
        ArenaChatFailure.notRoomMember,
        'Only room players may send chat signals.',
      );
    }
    final status = (raw['status'] ?? '').toString();
    if (!_writableStatuses.contains(status)) {
      throw const ArenaChatException(
        ArenaChatFailure.roomClosed,
        'Quick chat is unavailable after the room closes.',
      );
    }
  }

  void dispose() {
    _disposed = true;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const ArenaChatException(
        ArenaChatFailure.disposed,
        'ArenaChatService has been disposed.',
      );
    }
  }

  static String _normalizeName(String value) {
    var normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) normalized = 'PLAYER';
    if (normalized.length > 40) normalized = normalized.substring(0, 40);
    return normalized;
  }

  static bool _isSafeFirebaseKey(String value) {
    if (value.isEmpty || value.length > 128) return false;
    return !RegExp(r'[.#$\[\]/]').hasMatch(value);
  }
}
