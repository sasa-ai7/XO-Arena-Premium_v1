import 'package:flutter/foundation.dart';

import '../game_emoji.dart';

/// The two lightweight signal types supported by Arena quick chat.
enum ArenaChatSignalType { message, emoji }

/// Latest quick-chat message or emoji reaction published by one room player.
///
/// Arena stores one signal per uid at `rooms/{code}/chatSignals/{uid}`. A new
/// signal overwrites that player's previous one, preventing unbounded room
/// growth while still supporting transient bubbles in lobby and gameplay.
@immutable
class ArenaChatSignal {
  static const int maxMessageLength = 120;

  final ArenaChatSignalType type;
  final String senderUid;
  final String senderName;
  final String payload;

  /// Server-resolved timestamp when available, otherwise [clientSentAtMs].
  final int sentAtMs;

  /// Client timestamp retained as a deterministic fallback while the RTDB
  /// server timestamp is resolving.
  final int clientSentAtMs;

  /// Changes for every send, even if a player sends the same payload twice.
  final String nonce;

  const ArenaChatSignal({
    required this.type,
    required this.senderUid,
    required this.senderName,
    required this.payload,
    required this.sentAtMs,
    required this.clientSentAtMs,
    required this.nonce,
  });

  bool get isMessage => type == ArenaChatSignalType.message;
  bool get isEmoji => type == ArenaChatSignalType.emoji;
  String? get text => isMessage ? payload : null;
  String? get emoji => isEmoji ? payload : null;

  /// Timestamp used for display-age calculations.
  int get effectiveSentAtMs => sentAtMs > 0 ? sentAtMs : clientSentAtMs;

  /// Stable identity for animation/timer deduplication.
  String get identity => '$senderUid:$nonce';

  bool isFresh({
    Duration visibleFor = const Duration(seconds: 5),
    int? nowMs,
  }) {
    final stamp = effectiveSentAtMs;
    if (stamp <= 0) return false;
    final age = (nowMs ?? DateTime.now().millisecondsSinceEpoch) - stamp;
    // A small negative age can occur when device and server clocks differ.
    return age < visibleFor.inMilliseconds && age > -60 * 1000;
  }

  /// Parses an untrusted RTDB value. Invalid or legacy-shaped entries are
  /// ignored rather than throwing and terminating the room's watch stream.
  static ArenaChatSignal? tryParse(
    Object? raw, {
    String? expectedUid,
  }) {
    if (raw is! Map) return null;

    final typeRaw = raw['type']?.toString();
    final type = switch (typeRaw) {
      'message' => ArenaChatSignalType.message,
      'emoji' => ArenaChatSignalType.emoji,
      _ => null,
    };
    if (type == null) return null;

    final senderUid = (raw['senderUid'] ?? '').toString().trim();
    if (senderUid.isEmpty ||
        (expectedUid != null && senderUid != expectedUid)) {
      return null;
    }

    var senderName = (raw['senderName'] ?? '').toString().trim();
    if (senderName.isEmpty) senderName = 'PLAYER';
    if (senderName.length > 40) senderName = senderName.substring(0, 40);

    final payload = (raw['payload'] ?? '').toString().trim();
    if (payload.isEmpty || payload.length > maxMessageLength) return null;
    // Emoji reactions carry a catalog id (e.g. "arena1"); reject anything not
    // in the current emoji catalog so stale/unknown ids never render.
    if (type == ArenaChatSignalType.emoji &&
        !EmojiCatalog.isValidId(payload)) {
      return null;
    }

    final clientSentAtMs = _asInt(raw['clientSentAtMs']);
    final sentAtMs = _asInt(raw['sentAtMs']);
    if (sentAtMs <= 0 && clientSentAtMs <= 0) return null;

    final nonce = (raw['nonce'] ?? '').toString();
    if (nonce.isEmpty || nonce.length > 40) return null;

    return ArenaChatSignal(
      type: type,
      senderUid: senderUid,
      senderName: senderName,
      payload: payload,
      sentAtMs: sentAtMs,
      clientSentAtMs: clientSentAtMs,
      nonce: nonce,
    );
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  String toString() =>
      'ArenaChatSignal(type: ${type.name}, senderUid: $senderUid, '
      'payload: $payload, sentAtMs: $effectiveSentAtMs)';
}
