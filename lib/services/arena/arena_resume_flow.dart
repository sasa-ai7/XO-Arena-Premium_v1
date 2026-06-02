import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/arena/arena_room.dart';
import '../../screens/arena/arena_game_page.dart';
import '../../screens/arena/arena_lobby_page.dart';
import '../../screens/arena/widgets/active_room_resume_dialog.dart';
import 'arena_bet_service.dart';
import 'arena_match_summary.dart';
import 'arena_repo.dart';

/// What a startup/settlement pass found for the user's saved active room.
enum PendingRoomKind {
  /// Nothing to settle — either no pointer, or it points at a still-live,
  /// resumable room (the caller should offer the resume prompt).
  none,

  /// The room finished while the user was away AND the user is the winner.
  /// Any locked prize has been credited (idempotently). Show a win notice.
  wonNotice,

  /// The room is gone / expired / cancelled / abandoned / stale. Any locked
  /// bet has been refunded (idempotently). Show a "room closed" notice.
  closedNotice,
}

/// Result of settling a user's pending active room on app open.
class PendingRoomOutcome {
  final PendingRoomKind kind;
  final String? roomCode;
  final int coinsWon;
  final bool opponentLeft;

  /// For [PendingRoomKind.closedNotice]: 'expired' | 'cancelled' | 'closed'.
  final String closedReason;

  const PendingRoomOutcome(
    this.kind, {
    this.roomCode,
    this.coinsWon = 0,
    this.opponentLeft = false,
    this.closedReason = 'closed',
  });

  static const PendingRoomOutcome none = PendingRoomOutcome(PendingRoomKind.none);
}

/// Shared "active room" resume logic used by both the Home startup flow and the
/// Arena tab / create-room guard, so there is exactly one implementation of:
///   • settling a room that ended / expired while the user was away
///     (offline-winner payout, both-inactive refund, expiry notice), and
///   • navigating back into a live room (lobby vs game).
///
/// Logging vocabulary differs per call site (`[ACTIVE_ROOM_GLOBAL]` vs
/// `[CREATE_ROOM_GUARD]`), so the call sites emit their own log lines; this
/// helper does the heavy lifting and emits the lifecycle/`[ROOM_TIMEOUT]` logs.
class ArenaResumeFlow {
  ArenaResumeFlow._();

  /// Settle any terminal/stale active room for [uid] BEFORE a resume prompt is
  /// considered. Returns [PendingRoomKind.none] when the pointer is absent or
  /// references a still-live, resumable room.
  ///
  /// Coin settlement is fully idempotent — it routes through the existing
  /// [ArenaBetService.creditPrize] / [ArenaBetService.refundOwnBet] guards, so
  /// it can never double-pay or double-refund even if the game page already
  /// settled the same match.
  static Future<PendingRoomOutcome> settlePendingActiveRoom(String uid) async {
    final repo = ArenaRepo.instance;
    final code = await repo.getActiveRoomCode(uid);
    if (kDebugMode) {
      debugPrint('[ROOM_TIMEOUT] check uid=$uid room=$code');
    }
    if (code == null) return PendingRoomOutcome.none;

    final room = await repo.readRoom(code);
    if (room == null) {
      // Node gone (host removed it / janitor cleaned it). Nothing to settle.
      await repo.clearActiveRoomMirror(uid);
      if (kDebugMode) {
        debugPrint('[ACTIVE_ROOM_GLOBAL] cleared uid=$uid room=$code '
            'reason=missing');
      }
      return PendingRoomOutcome.none;
    }

    final isMember = uid == room.hostUid || uid == room.guestUid;
    if (!isMember) {
      // Kicked / no longer a member — drop the stale pointer silently.
      await repo.clearActiveRoomMirror(uid);
      if (kDebugMode) {
        debugPrint('[ACTIVE_ROOM_GLOBAL] cleared uid=$uid room=$code '
            'reason=not_member');
      }
      return PendingRoomOutcome.none;
    }

    final betLocked =
        room.betEnabled && room.coinsLocked && room.betAmount > 0;

    // ── Finished while we were away ──────────────────────────────────────────
    if (room.status == 'finished') {
      final isWinner =
          room.roomWinnerUid != null && room.roomWinnerUid == uid;
      int coinsWon = 0;
      if (isWinner && betLocked) {
        final credited =
            await ArenaBetService.creditPrize(room: room, selfUid: uid);
        if (credited) coinsWon = room.prizePool;
      }
      // Best-effort history completeness (idempotent set+merge by matchId).
      await ArenaMatchSummary.writeForRoom(room: room, coinsWon: coinsWon);
      await repo.clearActiveRoomMirror(uid);
      if (kDebugMode) {
        debugPrint('[ACTIVE_ROOM_GLOBAL] cleared uid=$uid room=$code '
            'reason=finished');
      }
      if (isWinner) {
        return PendingRoomOutcome(
          PendingRoomKind.wonNotice,
          roomCode: code,
          coinsWon: coinsWon,
          opponentLeft: room.result == 'forfeit',
        );
      }
      // Loser: entry already debited; they generally already saw the result.
      return PendingRoomOutcome.none;
    }

    // ── Terminal-but-not-finished, or stale-by-inactivity → "closed" ─────────
    final terminalClosed = room.status == 'expired' ||
        room.status == 'cancelled' ||
        room.status == 'abandoned';
    final stale = repo.isRoomStaleByInactivity(room);
    final now = DateTime.now().millisecondsSinceEpoch;
    final emptyWaitingTtl = !room.isFull &&
        room.status == 'waiting' &&
        room.expiresAt > 0 &&
        now > room.expiresAt;

    if (terminalClosed || stale || emptyWaitingTtl) {
      // Refund our own locked entry first (idempotent), while the node still
      // holds the bet metadata.
      if (betLocked) {
        await ArenaBetService.refundOwnBet(room: room, selfUid: uid);
      }
      // Expire the room. For occupied/stale rooms keep the node alive for a
      // grace window so the OTHER player can also observe + refund; betting
      // rooms get a long (24h) claim window so an offline opponent never loses
      // their locked entry. Empty waiting rooms have nothing to refund, so they
      // are removed outright.
      if (stale) {
        await repo.markRoomExpired(
          code,
          grace: betLocked
              ? const Duration(hours: 24)
              : const Duration(minutes: 2),
        );
      } else if (emptyWaitingTtl) {
        await repo.expireRoom(code);
      }
      // (already cancelled/expired/abandoned: leave as-is; node will be
      //  removed by the host cleanup timer or the CF janitor.)
      await repo.clearActiveRoomMirror(uid);
      if (kDebugMode) {
        debugPrint('[ROOM_TIMEOUT] cleanup_active_room uid=$uid room=$code');
        debugPrint('[ROOM_TIMEOUT] user_notified uid=$uid room=$code');
        debugPrint('[ACTIVE_ROOM_GLOBAL] cleared uid=$uid room=$code '
            'reason=closed');
      }
      final reason = (stale || emptyWaitingTtl || room.status == 'expired')
          ? 'expired'
          : (room.status == 'cancelled' ? 'cancelled' : 'closed');
      return PendingRoomOutcome(
        PendingRoomKind.closedNotice,
        roomCode: code,
        closedReason: reason,
      );
    }

    // Live, resumable room → caller offers the resume prompt.
    return PendingRoomOutcome.none;
  }

  /// Show the styled XO notice for a settled (won/closed) pending room. Safe to
  /// call only with [PendingRoomKind.wonNotice] / [PendingRoomKind.closedNotice].
  static Future<void> showSettlementNotice(
    BuildContext context,
    PendingRoomOutcome outcome, {
    required bool isAr,
  }) async {
    if (outcome.kind == PendingRoomKind.wonNotice) {
      final title = isAr ? 'لقد فزت!' : 'You Won!';
      final base = outcome.opponentLeft
          ? (isAr ? 'غادر خصمك المباراة.' : 'Your opponent left the match.')
          : (isAr ? 'انتهت مباراتك السابقة.' : 'Your previous match finished.');
      final prize = outcome.coinsWon > 0
          ? (isAr
              ? ' تم إضافة ${outcome.coinsWon} عملة.'
              : ' ${outcome.coinsWon} coins added.')
          : '';
      await showRoomClosedDialog(
        context,
        title: title,
        message: '$base$prize',
        icon: Icons.emoji_events_rounded,
        accent: AppPalette.success,
      );
      return;
    }
    // closedNotice
    final expired = outcome.closedReason == 'expired';
    final title = expired
        ? (isAr ? 'انتهت صلاحية الغرفة' : 'Room Closed')
        : (isAr ? 'أُغلقت الغرفة' : 'Room Closed');
    final message = expired
        ? (isAr
            ? 'تم إغلاق غرفتك السابقة لانتهاء صلاحيتها.'
            : 'Your previous room was closed because it expired.')
        : (isAr
            ? 'تم إغلاق غرفتك السابقة.'
            : 'Your previous room was closed.');
    await showRoomClosedDialog(
      context,
      title: title,
      message: message,
      icon: Icons.meeting_room_rounded,
      accent: AppPalette.accentPurple,
      roomCode: outcome.roomCode,
    );
  }

  /// Push the correct screen for a still-valid room: the game for live play
  /// states, the lobby otherwise.
  static Future<void> navigateToRoom(BuildContext context, ArenaRoom room) {
    final s = room.status;
    final isGame =
        s == 'playing' || s == 'round_end' || s == 'round_draw' || s == 'countdown';
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          isGame ? ArenaGamePage(initialRoom: room) : ArenaLobbyPage(initialRoom: room),
    ));
  }

  /// Short human label for a room status (used as the dialog status chip).
  static String statusLabel(String status) {
    switch (status) {
      case 'waiting':
        return 'WAITING';
      case 'ready':
        return 'READY';
      case 'countdown':
        return 'STARTING';
      case 'playing':
        return 'IN GAME';
      case 'round_end':
      case 'round_draw':
        return 'ROUND END';
      default:
        return status.toUpperCase();
    }
  }

  /// Convenience: the signed-in uid, or null.
  static String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
}
