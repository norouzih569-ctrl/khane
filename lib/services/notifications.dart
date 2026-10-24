import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// اعلان‌های محلی. همه‌ی متدها خطا را می‌بلعند تا مشکل اعلان باعث کرش برنامه نشود.
class Notif {
  Notif._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'khane_reminders',
      'یادآوری‌های خرج خانه',
      channelDescription: 'سررسید اقساط، قبوض و یادآوری ثبت هزینه',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await impl?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// یک اعلان در زمان مشخص (اگر زمان گذشته باشد، کاری نمی‌کند)
  static Future<void> scheduleOnce(
    int id,
    String title,
    String body,
    DateTime when,
  ) async {
    if (!_ready || !when.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  /// اعلان تکرارشونده‌ی روزانه
  static Future<void> scheduleDaily(
    int id,
    String title,
    String body,
    int hour,
    int minute,
  ) async {
    if (!_ready) return;
    try {
      final now = tz.TZDateTime.now(tz.local);
      var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (t.isBefore(now)) t = t.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        t,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }

  static Future<void> showNow(int id, String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(id, title, body, _details);
    } catch (_) {}
  }

  static Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
