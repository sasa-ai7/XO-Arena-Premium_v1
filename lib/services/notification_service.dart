import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Manages daily "Let's play" notifications.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification service (does not auto-schedule).
  /// Call scheduleDailyReminder() separately after user enables notifications in Settings.
  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();
    
    // Get device timezone and set it as local location
    // This ensures notifications schedule at 9:00 AM in device's local time (not UTC)
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      if (kDebugMode) {
        debugPrint('[NOTIF] Timezone initialized: ${tzInfo.identifier}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NOTIF] Failed to get device timezone, using default: $e');
      }
      // If timezone detection fails, tz.local will use system default
    }

    // Initialize Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Initialize iOS settings (do NOT request permissions on init)
    // Permissions will be requested only when user enables Daily Reminders in Settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);

    // Create notification channel for Android
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      const androidChannel = AndroidNotificationChannel(
        'daily_reminder',
        'XO ARENA Daily Reminder',
        description: 'Daily reminder to play XO ARENA',
        importance: Importance.defaultImportance,
      );
      await androidPlugin.createNotificationChannel(androidChannel);
    }

    _initialized = true;
  }

  /// Request notification permission (Android 13+).
  /// Returns true if permission is granted or not required (Android < 13), false otherwise.
  Future<bool> requestNotificationsPermission() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      // On Android < 13, permission is not required, so null means granted
      return await androidPlugin.requestNotificationsPermission() ?? true;
    }
    return false;
  }

  /// Schedule daily reminder. Checks permission first and only schedules if granted.
  /// Should only be called when user explicitly enables notifications in Settings.
  /// Returns true if scheduled successfully, false if permission denied or failed.
  Future<bool> scheduleDailyReminder() async {
    if (!_initialized) {
      await init();
    }

    // Request permission if not already granted (Android 13+)
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await requestNotificationsPermission();
      if (!granted) {
        // Permission not granted, don't schedule
        return false;
      }
    }

    // Request permissions (iOS)
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(alert: true, badge: true, sound: true);
    }

    try {
      await scheduleDaily();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NOTIF] scheduleDailyReminder: Failed to schedule: $e');
      }
      return false;
    }
  }

  /// Cancel the scheduled daily notification.
  Future<void> cancelDaily() async {
    await _notifications.cancel(0);
  }

  /// Cancel the scheduled daily reminder (alias for cancelDaily for consistency).
  Future<void> cancelDailyReminder() async {
    await cancelDaily();
  }

  /// Schedule a daily repeating notification at 9:00 AM local time.
  Future<void> scheduleDaily() async {
    // Cancel any existing daily notification first
    await _notifications.cancel(0);

    // Schedule for 9:00 AM local time, repeating daily
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      9,
      0,
    );

    // If 9 AM has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_reminder',
      'XO ARENA Daily Reminder',
      channelDescription: 'Daily reminder to play XO ARENA',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      0,
      'XO ARENA',
      "Let's play!",
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
