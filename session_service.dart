import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/keys.dart';

/// Single-device session enforcer.
///
/// On login, writes a unique session ID + device info to Firestore.
/// A real-time listener detects when another device overwrites the session,
/// triggering a force-logout on the old device.
class SessionService {
  SessionService._();

  static String? _currentSessionId;

  /// Generate a unique session, save it locally, and write it to Firestore.
  static Future<void> writeSession(String uid) async {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentSessionId = sessionId;

    // Persist locally
    final p = await SharedPreferences.getInstance();
    await p.setString(Keys.sessionId, sessionId);

    // Get device model
    final deviceModel = await _getDeviceModel();

    // Write to Firestore
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'Session': {
        'currentSessionId': sessionId,
        'lastDeviceModel': deviceModel,
        'lastLoginTime': FieldValue.serverTimestamp(),
      },
    });

    if (kDebugMode) {
      debugPrint('[SESSION] Written session $sessionId for $uid on $deviceModel');
    }
  }

  /// Get the locally saved session ID (in-memory first, then SharedPreferences).
  static Future<String?> getLocalSessionId() async {
    if (_currentSessionId != null) return _currentSessionId;
    final p = await SharedPreferences.getInstance();
    _currentSessionId = p.getString(Keys.sessionId);
    return _currentSessionId;
  }

  /// Listen for session conflicts on the user's Firestore document.
  ///
  /// [sessionId] must be the current session ID (from [writeSession] or
  /// [getLocalSessionId]) so that the listener is immediately ready to
  /// detect conflicts — no async SharedPreferences race.
  ///
  /// Returns a [StreamSubscription] that the caller must cancel on dispose.
  /// Calls [onConflict] with the new device model and login time when
  /// the remote session ID differs from the local one.
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
      listenForConflict({
    required String uid,
    required String sessionId,
    required void Function(String newDevice, DateTime loginTime) onConflict,
  }) {
    // Set in-memory ID immediately — no async race
    _currentSessionId = sessionId;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
      (snap) {
        try {
          final data = snap.data();
          if (data == null) return;

          final session = data['Session'] as Map<String, dynamic>?;
          if (session == null) return;

          final remoteId = session['currentSessionId'] as String?;
          if (remoteId == null || remoteId.isEmpty) return;

          if (_currentSessionId == null) return;
          if (remoteId == _currentSessionId) return;

          // Conflict detected — another device logged in
          if (kDebugMode) {
            debugPrint('[SESSION] Conflict! Remote=$remoteId Local=$_currentSessionId');
          }

          final deviceModel = session['lastDeviceModel'] as String? ?? 'Unknown Device';
          final loginTimestamp = session['lastLoginTime'];
          DateTime loginTime;
          if (loginTimestamp is Timestamp) {
            loginTime = loginTimestamp.toDate();
          } else {
            loginTime = DateTime.now();
          }

          onConflict(deviceModel, loginTime);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[SESSION] Listener callback error: $e');
          }
        }
      },
      onError: (e) {
        if (kDebugMode) {
          debugPrint('[SESSION] Stream error: $e');
        }
      },
    );
  }

  /// Clear session data on sign-out.
  static Future<void> clearLocal() async {
    _currentSessionId = null;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(Keys.sessionId);
    } catch (_) {}
  }

  /// Get a human-readable device model string.
  static Future<String> _getDeviceModel() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        final brand = android.brand;
        final model = android.model;
        // Capitalize brand
        final brandCap = brand.isNotEmpty
            ? '${brand[0].toUpperCase()}${brand.substring(1)}'
            : brand;
        return '$brandCap $model';
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return ios.utsname.machine;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SESSION] Failed to get device model: $e');
      }
    }
    return 'Unknown Device';
  }
}
