import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../models/arena/arena_room.dart';
import 'arena_repo.dart';

/// Three-state presence used in arena lobby / game UIs.
enum PresenceState { online, weak, offline }

/// Heartbeat cadence — every 5 s the owner re-stamps `lastSeenMs` so
/// observers can derive freshness without a real-time stream.
const Duration _kHeartbeatPeriod = Duration(seconds: 5);

/// `lastSeenMs <= now - kStaleOnlineMs` → no longer "online".
const int _kStaleOnlineMs = 10 * 1000;

/// `lastSeenMs <= now - kStaleWeakMs` → considered offline.
const int _kStaleWeakMs = 30 * 1000;

/// Tracks one player's presence inside a single arena room.
///
/// Lifecycle:
///   • Created when the user enters lobby/game.
///   • [start] writes `state=online` + `lastSeenMs=now` to
///     `/rooms/{code}/playersPresence/{selfUid}` and registers an
///     `onDisconnect()` that stamps `state=offline` if the socket drops.
///   • A 5-second timer re-stamps `lastSeenMs` so the other side can
///     derive `weak` / `offline` from staleness alone.
///   • [stop] writes `state=offline` once and cancels the timer.
///
/// Derived state for an *opponent* uid is computed by [derive], which the
/// UI calls every second or whenever it re-renders the player card.
class ArenaPresenceService {
  ArenaPresenceService({required this.code, required this.selfUid})
      : _ref = ArenaRepo.instance.roomRef(code).child('playersPresence');

  final String code;
  final String selfUid;
  final DatabaseReference _ref;

  Timer? _heartbeat;
  bool _started = false;
  PresenceState? _lastLoggedState;

  /// Writes initial online state, registers onDisconnect, starts heartbeat.
  /// Safe to call multiple times — repeat calls are no-ops.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final selfRef = _ref.child(selfUid);
    try {
      await selfRef.onDisconnect().set(<String, Object?>{
        'state': 'offline',
        'lastSeenMs': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ARENA_PRESENCE] onDisconnect register failed: $e');
      }
    }
    await _writeOnline();
    _heartbeat = Timer.periodic(_kHeartbeatPeriod, (_) => _writeOnline());
  }

  Future<void> _writeOnline() async {
    try {
      await _ref.child(selfUid).set(<String, Object?>{
        'state': 'online',
        'lastSeenMs': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (_) {
      // Network blip — swallow. Next heartbeat tick will retry.
    }
  }

  Future<void> markOnlineNow() => _writeOnline();

  /// Stops the heartbeat and (best-effort) marks the owner offline.
  Future<void> stop({bool markOffline = true}) async {
    if (!_started) return;
    _started = false;
    _heartbeat?.cancel();
    _heartbeat = null;
    try {
      await _ref.child(selfUid).onDisconnect().cancel();
    } catch (_) {}
    if (markOffline) {
      try {
        await _ref.child(selfUid).set(<String, Object?>{
          'state': 'offline',
          'lastSeenMs': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': ServerValue.timestamp,
        });
      } catch (_) {}
    }
  }

  /// Derives a three-state presence for the given uid from a snapshot of
  /// the room. Returns null when the uid is not in the room at all.
  PresenceState? derive(ArenaRoom room, String uid) {
    if (uid.isEmpty) return null;
    if (uid != room.hostUid && uid != room.guestUid) return null;
    final entry = room.playersPresence[uid];
    final now = DateTime.now().millisecondsSinceEpoch;
    if (entry == null) {
      // No presence record yet. For the guest, fall back to "online" once
      // they're in the seat — the heartbeat will overwrite within 5 s.
      return PresenceState.online;
    }
    final explicit = (entry['state'] ?? '').toString();
    if (explicit == 'offline') return PresenceState.offline;
    final lastSeen = (entry['lastSeenMs'] as num?)?.toInt() ?? 0;
    final stale = now - lastSeen;
    if (stale > _kStaleWeakMs) return PresenceState.offline;
    if (stale > _kStaleOnlineMs) return PresenceState.weak;
    return PresenceState.online;
  }

  /// Lightweight tag log on state transitions only — heartbeats are silent.
  void maybeLogTransition(String uid, PresenceState state) {
    if (!kDebugMode) return;
    if (uid != selfUid) return;
    if (_lastLoggedState == state) return;
    _lastLoggedState = state;
    debugPrint('[ARENA_PRESENCE] room=$code uid=$uid state=${state.name}');
  }
}
