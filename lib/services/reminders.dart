import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Weekly "check your report" reminder.
class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _weeklyId = 1;

  static Future<void> init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_launcher_monochrome'),
      ),
    );
  }

  static Future<void> setWeekly(bool on) async {
    await _plugin.cancel(id: _weeklyId);
    if (!on) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin.periodicallyShow(
      id: _weeklyId,
      repeatInterval: RepeatInterval.weekly,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'Your weekly focus report is ready',
      body: 'See how much time went to messages and how much to scrolling.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_report',
          'Weekly report',
          channelDescription: 'Weekly usage summary reminder',
          importance: Importance.defaultImportance,
        ),
      ),
    );
  }
}
