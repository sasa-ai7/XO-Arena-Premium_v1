import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Best-effort audit logger.
///
/// Logging must never break user-facing flows such as auth, gameplay, or IAP.
class AuditService {
  AuditService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static void log(String eventName, [Map<String, dynamic>? metadata]) {
    unawaited(_write(eventName, metadata));
  }

  static Future<void> _write(
    String eventName,
    Map<String, dynamic>? metadata,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await _firestore.collection('audit_logs').add({
        'eventName': eventName,
        'metadata': metadata ?? <String, dynamic>{},
        'uid': user?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUDIT] Failed to write "$eventName": $e');
      }
    }
  }
}