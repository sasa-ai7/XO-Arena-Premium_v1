import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/app_config.dart';
import '../../models/arena/arena_room.dart';

/// Writes the compact post-match history to Firestore plus per-user
/// `user_logs` and (optionally) global `audit_logs` entries.
///
/// Output paths written by each device (only paths the caller is authorized
/// to write per Firestore rules):
///   • /users/{selfUid}/onlineRoomHistory/{matchId}  — caller's own history
///   • /online_room_history/{matchId}                — shared per-match doc
///
/// The opponent's `/users/{opponentUid}/onlineRoomHistory/{matchId}` is
/// **deliberately NOT written** from this device — Firestore rules at
/// [firestore.rules:114-116](firestore.rules:114) (and intentionally so)
/// only allow each user to write their own subcollections. The opponent's
/// client writes its own mirror when its room listener delivers
/// `status == 'finished'`.
///
/// All writes are idempotent (`set(..., merge: true)` keyed by [matchId]) so
/// both players can write independently without producing duplicates.
///
/// TODO: Move server-authoritative `onlineRoomHistory` writes to a Cloud
/// Function so a single trusted write produces both per-user mirrors.
class ArenaMatchSummary {
  ArenaMatchSummary._();

  static final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// Decide the `resultReason` enum value from the room state.
  static String resultReasonOf(ArenaRoom room) {
    final r = room.finalResult ?? room.result;
    switch (r) {
      case 'opponent_left':
      case 'forfeit':
      case 'disconnect_forfeit':
        return 'opponent_left';
      case 'expired':
        return 'expired';
      case 'completed':
      default:
        return 'completed';
    }
  }

  /// Write the compact summary to the caller's own user history path plus
  /// the shared global path. Idempotent (set+merge keyed by matchId).
  ///
  /// Only writes the *caller's* `/users/{selfUid}/onlineRoomHistory/...`
  /// path — the opponent's mirror is written by the opponent's own device
  /// when its listener sees `status == 'finished'`. This matches Firestore
  /// rules and prevents the PERMISSION_DENIED warnings observed before.
  static Future<void> writeForRoom({
    required ArenaRoom room,
    required int coinsWon,
  }) async {
    if (room.matchId.isEmpty) return;
    final selfUid = FirebaseAuth.instance.currentUser?.uid;
    if (selfUid == null) {
      if (kDebugMode) {
        debugPrint(
            '[ARENA] summary skipped — no signed-in user matchId=${room.matchId}');
      }
      return;
    }
    final isParticipant = selfUid == room.hostUid || selfUid == room.guestUid;
    if (!isParticipant) {
      // Edge case — listener delivered a finished snapshot to a user who
      // isn't a participant. Firestore rules would reject either write, so
      // bail out cleanly.
      if (kDebugMode) {
        debugPrint('[ARENA] summary skipped — not participant '
            'self=$selfUid host=${room.hostUid} guest=${room.guestUid}');
      }
      return;
    }

    final winnerUid = room.roomWinnerUid;
    final loserUid = winnerUid == null
        ? null
        : (winnerUid == room.hostUid ? room.guestUid : room.hostUid);

    final roundsPlayed =
        (room.scoreHost + room.scoreGuest).clamp(0, room.roundsCount);
    final data = <String, dynamic>{
      'roomCode': room.roomCode,
      'hostUid': room.hostUid,
      'guestUid': room.guestUid,
      'winnerUid': winnerUid,
      'loserUid': loserUid,
      'roundCount': room.roundsCount,
      // roundsPlayed: actual rounds resolved (host wins + guest wins, capped).
      'roundsPlayed': roundsPlayed,
      'roundMaps': room.roundMaps,
      // 'maps' alias kept for downstream readers expecting that name.
      'maps': room.roundMaps,
      'bettingEnabled': room.betEnabled,
      'betAmount': room.betAmount,
      'potAmount': room.prizePool,
      'prizePool': room.prizePool,
      'finishedAt': FieldValue.serverTimestamp(),
      'resultReason': resultReasonOf(room),
      'result': room.finalResult ?? room.result,
      'finalScore': <String, dynamic>{
        'host': room.scoreHost,
        'guest': room.scoreGuest,
      },
      'coinsWon': coinsWon,
    };

    Future<bool> writeDoc(DocumentReference<Map<String, dynamic>> ref) async {
      try {
        await ref.set(data, SetOptions(merge: true));
        return true;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ARENA] summary write failed path=${ref.path}: $e');
        }
        return false;
      }
    }

    final selfRef = _fs
        .collection('users')
        .doc(selfUid)
        .collection('onlineRoomHistory')
        .doc(room.matchId);
    final globalRef = _fs.collection('online_room_history').doc(room.matchId);

    final results = await Future.wait<bool>([
      writeDoc(selfRef),
      writeDoc(globalRef),
    ]);
    final savedSelf = results[0];
    final savedGlobal = results[1];

    if (kDebugMode) {
      debugPrint('[ARENA] summary result matchId=${room.matchId} '
          'self=$selfUid savedSelf=$savedSelf savedGlobal=$savedGlobal');
    }
  }

  /// Write a `friend_room_finished` entry to users/{uid}/user_logs for the
  /// given player, plus an audit_logs entry (best-effort, non-fatal).
  static Future<void> writeUserLogs({
    required ArenaRoom room,
    required String uid,
    required String opponentUid,
    required String opponentName,
    required int coinsWon,
  }) async {
    final metadata = <String, dynamic>{
      'matchId': room.matchId,
      'roomCode': room.roomCode,
      'opponentUid': opponentUid,
      'opponentName': opponentName,
      'resultReason': resultReasonOf(room),
      'bettingEnabled': room.betEnabled,
      'betAmount': room.betAmount,
      'potAmount': room.prizePool,
      'coinsWon': coinsWon,
      'finalScore': <String, dynamic>{
        'host': room.scoreHost,
        'guest': room.scoreGuest,
      },
      'roundCount': room.roundsCount,
      'roundMaps': room.roundMaps,
    };
    try {
      await _fs
          .collection('users')
          .doc(uid)
          .collection('user_logs')
          .add(<String, dynamic>{
        'uid': uid,
        'eventName': 'friend_room_finished',
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
    } catch (_) {}
    if (AppConfig.kEnableFirestoreAuditLogs) {
      try {
        await _fs.collection('audit_logs').add(<String, dynamic>{
          'uid': uid,
          'eventName': 'friend_room_finished',
          'createdAt': FieldValue.serverTimestamp(),
          'metadata': metadata,
        });
      } catch (_) {}
    }
  }
}
