import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local-notification helper.
///
/// Responsibilities are intentionally narrow:
///   • request the OS notification permission (Android 13+ / iOS), and
///   • render a heads-up notification while the app is in the FOREGROUND in
///     response to a real received FCM push (FCM does not show its own banner
///     when the app is already foregrounded).
///
/// There is deliberately NO scheduled/daily reminder here. The old 9 PM
/// "Let's play" reminder and the in-app "test notification" button were
/// removed — real notifications now originate from FCM only (see
/// `FcmService`).
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Android channel used to display foreground FCM messages. Keep this id in
  /// sync with the `default_notification_channel_id` metadata declared in
  /// AndroidManifest.xml so background pushes use the same channel.
  static const String channelId = 'xo_arena_general';
  static const String _channelName = 'XO Arena';
  static const String _channelDescription =
      'XO Arena game notifications (rewards, invites).';

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    // Do NOT request permissions on init — the permission prompt is driven
    // explicitly (first-launch flow / Settings toggle / FCM init).
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (kDebugMode) {
          debugPrint(
              '[NOTIF] tapped: id=${details.id} payload=${details.payload}');
        }
      },
    );

    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      const channel = AndroidNotificationChannel(
        channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      await androidPlugin.createNotificationChannel(channel);
    }

    _initialized = true;
    if (kDebugMode) debugPrint('[NOTIF] init complete');
  }

  /// Request the OS notification permission.
  /// Returns true if granted (or not required, e.g. Android < 13).
  Future<bool> requestNotificationsPermission() async {
    if (!_initialized) await init();
    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted =
          await androidPlugin.requestNotificationsPermission() ?? true;
      if (kDebugMode) debugPrint('[NOTIF] permission result: granted=$granted');
      return granted;
    }
    final iosPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      if (kDebugMode) {
        debugPrint('[NOTIF] iOS permission result: granted=$granted');
      }
      return granted;
    }
    return false;
  }

  /// Display a heads-up notification immediately. Used to surface a real FCM
  /// message while the app is foregrounded.
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await init();
    const androidDetails = AndroidNotificationDetails(
      channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
