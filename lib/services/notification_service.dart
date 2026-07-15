import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/keys.dart';

/// Local-notification helper.
///
/// Responsibilities:
///   • request the OS notification permission (Android 13+ / iOS),
///   • render a heads-up notification while the app is in the FOREGROUND in
///     response to a real received FCM push (FCM does not show its own banner
///     when the app is already foregrounded), and
///   • schedule the daily 9 PM local "come back and play" reminder.
///
/// The daily reminder is LOCAL-ONLY (no FCM / Cloud Functions / Blaze). It is
/// controlled by the Settings notification toggle and re-synced on startup.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _tzInitialized = false;
  bool _dailyReminderScheduledThisSession = false;

  /// Stable id for the single daily reminder so re-scheduling never duplicates.
  static const int dailyReminderNotificationId = 9001;

  /// Android channel used to display foreground FCM messages. Keep this id in
  /// sync with the `default_notification_channel_id` metadata declared in
  /// AndroidManifest.xml so background pushes use the same channel.
  static const String channelId = 'xo_arena_general';
  static const String _channelName = 'XO Arena';
  static const String _channelDescription =
      'XO Arena game notifications (rewards, invites).';

  Future<void> init() async {
    if (_initialized) return;
    if (kDebugMode) debugPrint('[NOTIF] init start');

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

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
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
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted =
          await androidPlugin.requestNotificationsPermission() ?? true;
      if (kDebugMode) {
        debugPrint(granted
            ? '[NOTIF] permission granted'
            : '[NOTIF] permission denied');
      }
      return granted;
    }
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      if (kDebugMode) {
        debugPrint(granted
            ? '[NOTIF] permission granted'
            : '[NOTIF] permission denied');
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

  // ── Daily 9 PM local reminder (local-only, no FCM) ────────────────────────

  /// Load the timezone database once (needed for [tz.TZDateTime]).
  void _ensureTimezone() {
    if (_tzInitialized) return;
    try {
      tz_data.initializeTimeZones();
    } catch (e) {
      if (kDebugMode) debugPrint('[NOTIF] timezone init failed: $e');
    }
    _tzInitialized = true;
  }

  /// The next occurrence of 21:00 *device-local* wall-clock time, expressed as
  /// a UTC [tz.TZDateTime]. Anchoring to UTC (instead of an IANA location)
  /// avoids needing a device-timezone-name plugin; combined with
  /// `DateTimeComponents.time` it repeats daily at the same local time for the
  /// device's current UTC offset.
  tz.TZDateTime _next9pmLocal() {
    final nowLocal = DateTime.now();
    var next = DateTime(nowLocal.year, nowLocal.month, nowLocal.day, 21);
    if (!next.isAfter(nowLocal)) {
      next = next.add(const Duration(days: 1));
    }
    return tz.TZDateTime.from(next.toUtc(), tz.UTC);
  }

  /// Localized reminder copy based on the saved app language at schedule time.
  Future<({String title, String body})> _reminderText() async {
    var isAr = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      isAr = (prefs.getString(Keys.appLanguage) ?? 'en') == 'ar';
    } catch (_) {}
    return (
      title: 'XO Arena',
      body: isAr
          ? 'يلا نلعب ماتش XO سريع دلوقتي!'
          : 'Come back and play a quick XO match now!',
    );
  }

  /// Schedule (or reschedule) the daily 9 PM local play reminder. Cancels any
  /// existing instance first so there is never a duplicate.
  Future<void> scheduleDailyPlayReminder() async {
    if (_dailyReminderScheduledThisSession) return;
    if (!_initialized) await init();
    _ensureTimezone();
    final text = await _reminderText();

    await _notifications.cancel(dailyReminderNotificationId);

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

    try {
      await _notifications.zonedSchedule(
        dailyReminderNotificationId,
        text.title,
        text.body,
        _next9pmLocal(),
        details,
        // Inexact mode never requires the SCHEDULE_EXACT_ALARM permission, so
        // it cannot crash on Android 12+ when that permission is unavailable.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        // Repeat daily at the same wall-clock time.
        matchDateTimeComponents: DateTimeComponents.time,
      );
      _dailyReminderScheduledThisSession = true;
      if (kDebugMode) debugPrint('[NOTIF] daily reminder scheduled at 21:00');
    } catch (e) {
      // Do not crash the app if scheduling fails on a restricted device.
      if (kDebugMode) debugPrint('[NOTIF] daily reminder schedule failed: $e');
    }
  }

  /// Cancel the daily reminder.
  Future<void> cancelDailyPlayReminder() async {
    if (!_initialized) await init();
    await _notifications.cancel(dailyReminderNotificationId);
    _dailyReminderScheduledThisSession = false;
    if (kDebugMode) debugPrint('[NOTIF] daily reminder cancelled');
  }

  /// Re-apply the daily reminder from saved preferences (called on startup):
  /// schedule when the notification toggle is ON, cancel otherwise.
  Future<void> syncDailyReminderFromPrefs() async {
    var enabled = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(Keys.notificationsEnabled) ?? false;
    } catch (_) {}
    if (kDebugMode) debugPrint('[NOTIF] sync from prefs enabled=$enabled');
    if (enabled) {
      await scheduleDailyPlayReminder();
    } else {
      await cancelDailyPlayReminder();
    }
  }
}
