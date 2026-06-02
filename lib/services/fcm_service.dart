import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'app_mode_service.dart';
import 'notification_service.dart';

/// Background isolate handler for FCM. Must be a top-level function annotated
/// with `@pragma('vm:entry-point')` and registered from `main()` BEFORE
/// `runApp` via `FirebaseMessaging.onBackgroundMessage`.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase must be initialized in the background isolate.
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  if (kDebugMode) {
    debugPrint('[FCM] background message id=${message.messageId} '
        'type=${message.data['type']}');
  }
  // For notification-payload messages the OS renders the tray entry itself, so
  // there is nothing else to do here.
}

/// Firebase Cloud Messaging wiring: permission, per-user token storage, and
/// foreground/opened handlers.
///
/// Real notifications (e.g. the referral reward) are SENT only from the
/// backend Cloud Function `redeemReferralCode` — this client merely registers
/// to receive them and surfaces them in-app.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  /// Invoked when a `referral_reward` message arrives in the foreground or the
  /// app is opened from one. The Home screen assigns this to re-check pending
  /// referral-reward popups so the user sees the reward immediately.
  static VoidCallback? onReferralReward;

  bool _wired = false;
  String? _lastToken;

  FirebaseMessaging get _fm => FirebaseMessaging.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Wire listeners once. Safe to call repeatedly. Does NOT prompt for
  /// permission — it only saves the token if permission was already granted.
  Future<void> init() async {
    if (_wired) return;
    if (!AppModeService.canUseOnlineServices) return;
    _wired = true;
    try {
      await NotificationService().init();

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
      _fm.onTokenRefresh.listen((t) {
        _lastToken = t;
        _saveToken(t);
      });

      // App launched from terminated state by tapping a notification.
      final initial = await _fm.getInitialMessage();
      if (initial != null) _onMessageOpened(initial);

      // If permission is already granted, ensure the token is persisted.
      final settings = await _fm.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await registerToken();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] init failed: $e');
    }
  }

  /// Explicitly request the OS permission and register the token.
  /// Returns true if granted.
  Future<bool> requestPermissionAndRegister() async {
    if (!AppModeService.canUseOnlineServices) return false;
    bool granted = false;
    try {
      // iOS/APNs prompt (+ Android 13+ via the messaging plugin).
      final settings = await _fm.requestPermission();
      granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      // Android runtime POST_NOTIFICATIONS via the local-notifications plugin.
      final localGranted =
          await NotificationService().requestNotificationsPermission();
      granted = granted || localGranted;
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] requestPermission failed: $e');
    }
    if (kDebugMode) {
      debugPrint('[FCM] permission=${granted ? 'granted' : 'denied'}');
    }
    if (granted) await registerToken();
    return granted;
  }

  /// Fetch and persist this device's FCM token under the current user.
  Future<void> registerToken() async {
    if (!AppModeService.canUseOnlineServices) return;
    try {
      final token = await _fm.getToken();
      if (token == null || token.isEmpty) return;
      _lastToken = token;
      await _saveToken(token);
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] registerToken failed: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        <String, dynamic>{
          'fcmTokens': <String, dynamic>{token: true},
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (kDebugMode) debugPrint('[FCM] token_saved uid=$uid');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] token save failed: $e');
    }
  }

  /// Remove this device's token from the current user (e.g. notifications
  /// toggled off). Does not revoke the device-level token.
  Future<void> unregisterToken() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final token = _lastToken ?? await _fm.getToken();
      if (token == null || token.isEmpty) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).update(
        <String, dynamic>{'fcmTokens.$token': FieldValue.delete()},
      );
      if (kDebugMode) debugPrint('[FCM] token_removed uid=$uid');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] token remove failed: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final type = (message.data['type'] ?? '').toString();
    if (kDebugMode) {
      debugPrint('[FCM] foreground message type=$type id=${message.messageId}');
    }
    final n = message.notification;
    if (n != null) {
      NotificationService().showLocalNotification(
        title: n.title ?? 'XO Arena',
        body: n.body ?? '',
        payload: type,
      );
    }
    if (type == 'referral_reward') {
      onReferralReward?.call();
    }
  }

  void _onMessageOpened(RemoteMessage message) {
    final type = (message.data['type'] ?? '').toString();
    if (kDebugMode) {
      debugPrint('[FCM] notification_opened type=$type');
    }
    if (type == 'referral_reward') {
      onReferralReward?.call();
    }
  }
}
