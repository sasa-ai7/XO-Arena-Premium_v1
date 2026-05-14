import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Best-effort audit logger with offline queue and debounce.
///
/// Logs are queued when offline and retried when connectivity restored.
/// Rapid repeated logs are debounced to reduce network load (max 1 flush per second).
class AuditService {
  AuditService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final List<Map<String, dynamic>> _pendingQueue = <Map<String, dynamic>>[];
  static Timer? _flushTimer;
  static DateTime? _auditBlockedUntil;
  static final Map<String, DateTime> _lastEventAt = <String, DateTime>{};
  static const Map<String, Duration> _eventCooldowns = <String, Duration>{
    'app_resumed': Duration(seconds: 12),
    'app_paused': Duration(seconds: 12),
    'app_open': Duration(seconds: 20),
  };

  /// Queue an audit event. Writes are debounced (flushed every 1-2 seconds).
  /// Guests (non-signed-in users) are skipped to avoid permission errors.
  static void log(String eventName, [Map<String, dynamic>? metadata]) {
    // Skip logging for guests - they lack write permission
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final blockedUntil = _auditBlockedUntil;
    if (blockedUntil != null && now.isBefore(blockedUntil)) return;

    final cooldown = _eventCooldowns[eventName];
    if (cooldown != null) {
      final last = _lastEventAt[eventName];
      if (last != null && now.difference(last) < cooldown) return;
      _lastEventAt[eventName] = now;
    }

    _pendingQueue.add({
      'eventName': eventName,
      'timestamp': now,
      'metadata': metadata ?? <String, dynamic>{},
    });
    _scheduleFlush();
  }

  static void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(seconds: 1), _flush);
  }

  static Future<void> _flush() async {
    if (_pendingQueue.isEmpty) return;
    
    final queueToWrite = List<Map<String, dynamic>>.from(_pendingQueue);
    _pendingQueue.clear();

    try {
      final user = FirebaseAuth.instance.currentUser;
      // Guard: user signed out between log() and flush — discard post-signout events
      if (user == null) {
        if (kDebugMode) {
          debugPrint('[AUDIT] skipped — user signed out, discarding ${queueToWrite.length} events');
        }
        return;
      }
      final batch = _firestore.batch();
      final slice = queueToWrite.take(50).toList();
      for (final entry in slice) {
        final doc = _firestore.collection('audit_logs').doc();
        batch.set(doc, {
          'eventName': entry['eventName'],
          'metadata': entry['metadata'],
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (queueToWrite.length > slice.length) {
        _pendingQueue.addAll(queueToWrite.skip(slice.length));
      }
    } catch (e) {
      final lower = e.toString().toLowerCase();
      if (lower.contains('permission-denied')) {
        // Permanent auth error — discard queue, do not retry
        _pendingQueue.clear();
        if (kDebugMode) debugPrint('[AUDIT] permission-denied, queue cleared');
      } else {
        _pendingQueue.insertAll(0, queueToWrite);
        if (kDebugMode) debugPrint('[AUDIT] Flush failed, events re-queued: $e');
      }
    }
  }
}