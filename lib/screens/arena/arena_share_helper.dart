import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_l10n.dart';
import '../../models/arena/arena_room.dart';

/// Single entry-point for outbound plain-text shares from Arena.
///
/// Uses `Share.share(text)` only — never builds URLs, deep links, or app
/// links. If `share_plus` is unavailable on the platform, falls back to
/// copying the text to the clipboard.
class ArenaShareHelper {
  ArenaShareHelper._();

  static Future<bool> shareInvite({
    required AppL10n l10n,
    required String referralCode,
  }) async {
    final text = l10n.inviteShareMessage(referralCode);
    return _shareWithFallback(text);
  }

  static Future<bool> shareRoom({
    required AppL10n l10n,
    required ArenaRoom room,
  }) async {
    final text = l10n.roomShareMessage(
      roomCode: room.roomCode,
      roundCount: room.roundsCount,
      maps: room.roundMaps.join(' · '),
      betEnabled: room.betEnabled,
      betAmount: room.betAmount,
      prizePool: room.betEnabled ? (room.betAmount * 2) : 0,
    );
    return _shareWithFallback(text);
  }

  /// Returns true on successful share, false if it fell through to clipboard.
  static Future<bool> _shareWithFallback(String text) async {
    try {
      await Share.share(text);
      return true;
    } catch (_) {
      try {
        await Clipboard.setData(ClipboardData(text: text));
      } catch (_) {}
      return false;
    }
  }
}
