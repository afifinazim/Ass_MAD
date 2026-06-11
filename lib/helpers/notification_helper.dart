import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationHelper {
  static final NotificationHelper instance = NotificationHelper._init();
  NotificationHelper._init();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const _channelId = 'extracurricular_channel';
  static const _channelName = 'Extracurricular Logger';
  static const _channelDesc = 'Notifications for activity reminders and achievements';

  Future<void> init() async {
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(android: android, iOS: iOS);
    await _plugin.initialize(settings);

    // Request Android 13+ permission
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  AndroidNotificationDetails get _androidDetails =>
      const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

  NotificationDetails get _notifDetails =>
      NotificationDetails(android: _androidDetails);

  // ─── Immediate Notifications ──────────────────────────────
  Future<void> showAchievementNotification(String title) async {
    await _plugin.show(
      title.hashCode,
      '🏆 Achievement Unlocked!',
      'You unlocked: $title',
      _notifDetails,
    );
  }

  Future<void> showActivitySavedNotification(String activityTitle) async {
    await _plugin.show(
      activityTitle.hashCode,
      '✅ Activity Saved',
      '"$activityTitle" has been logged successfully!',
      _notifDetails,
    );
  }

  Future<void> showTestNotification() async {
    await _plugin.show(
      999,
      '🔔 Test Notification',
      'Notifications are working correctly!',
      _notifDetails,
    );
  }

  Future<void> showPedometerGoalNotification(int steps) async {
    await _plugin.show(
      888,
      '👣 Step Goal Reached!',
      'Congratulations! You walked $steps steps today!',
      _notifDetails,
    );
  }

  // ─── Scheduled Notifications ──────────────────────────────
  Future<void> scheduleWeeklySummary({
    required int totalActivities,
    required int totalHours,
  }) async {
    await cancelWeeklySummary();

    final now = tz.TZDateTime.now(tz.local);
    // Next Monday at 8:00 AM
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      8,
      0,
    );

    // Move to next Monday
    while (scheduledDate.weekday != DateTime.monday) {
      scheduledDate =
          scheduledDate.add(const Duration(days: 1));
    }
    if (scheduledDate.isBefore(now)) {
      scheduledDate =
          scheduledDate.add(const Duration(days: 7));
    }

    await _plugin.zonedSchedule(
      100,
      '📊 Weekly Activity Summary',
      'This week: $totalActivities activities, $totalHours hours logged!',
      scheduledDate,
      _notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  // ─── Cancel ───────────────────────────────────────────────
  Future<void> cancelWeeklySummary() async {
    await _plugin.cancel(100);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
