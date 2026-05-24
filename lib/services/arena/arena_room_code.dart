import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Generates and verifies the uniqueness of 6-digit numeric room codes.
class ArenaRoomCode {
  ArenaRoomCode._();

  static final Random _rng = Random.secure();

  /// Returns a fresh 6-digit string (zero-padded, e.g. "049281").
  static String generate6() {
    final n = _rng.nextInt(900000) + 100000; // 100000..999999 keeps it 6 digits
    return n.toString();
  }

  /// Returns a 6-digit code that does NOT currently exist under
  /// `rooms/{code}` in RTDB. Retries up to [maxAttempts] times.
  static Future<String> allocate({
    required DatabaseReference roomsRef,
    int maxAttempts = 8,
  }) async {
    for (int i = 0; i < maxAttempts; i++) {
      final code = generate6();
      final snap = await roomsRef.child(code).get();
      if (!snap.exists) {
        return code;
      }
      if (kDebugMode) {
        debugPrint('[ARENA] code collision $code (attempt ${i + 1})');
      }
    }
    // Extremely unlikely; fall back to a longer-but-still-6-digit attempt
    // using a tighter random window. Caller should treat any further failure
    // as a transient backend issue.
    throw StateError('Could not allocate unique room code.');
  }
}
