import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';

/// Local notifications: the daily "what to learn today" reminder and
/// alarm-style reminders for scheduled classes.
class Notifs {
  static final _p = FlutterLocalNotificationsPlugin();
  static const dailyId = 1;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _p.initialize(settings);
    await _android?.createNotificationChannel(const AndroidNotificationChannel(
      'daily',
      'Daily study reminder',
      description: 'Tells you what to learn today',
      importance: Importance.high,
    ));
    await _android?.createNotificationChannel(const AndroidNotificationChannel(
      'sessions',
      'Class alarms',
      description: 'Alarms for study sessions scheduled with your circle',
      importance: Importance.max,
    ));
  }

  static Future<void> requestPermissions() async {
    try {
      await _android?.requestNotificationsPermission();
      final canExact = await _android?.canScheduleExactNotifications() ?? true;
      if (!canExact) await _android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  static Future<AndroidScheduleMode> _mode() async {
    final canExact = await _android?.canScheduleExactNotifications() ?? false;
    return canExact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  // Times are converted to UTC instants. For the repeating daily reminder this
  // means "same UTC time every day" — identical to local time in regions
  // without daylight saving (e.g. Pakistan).
  static tz.TZDateTime _at(DateTime local) => tz.TZDateTime.from(local, tz.UTC);

  static NotificationDetails _dailyDetails(String body) => NotificationDetails(
        android: AndroidNotificationDetails(
          'daily',
          'Daily study reminder',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      );

  static Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    var when = DateTime(now.year, now.month, now.day, hour, minute);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    await _p.zonedSchedule(
      dailyId,
      title,
      body,
      _at(when),
      _dailyDetails(body),
      androidScheduleMode: await _mode(),
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancel(int id) => _p.cancel(id);

  /// Stable 30-bit hash so the same session always gets the same ids.
  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x3fffffff;
    }
    return h == dailyId ? h + 7 : h;
  }

  static NotificationDetails _alarmDetails({required bool insistent}) => NotificationDetails(
        android: AndroidNotificationDetails(
          'sessions',
          'Class alarms',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: insistent,
          enableVibration: true,
          playSound: true,
          // FLAG_INSISTENT = 4: keeps ringing until the notification is opened/dismissed.
          additionalFlags: insistent ? Int32List.fromList(<int>[4]) : null,
        ),
      );

  /// The two notification ids used for one class.
  static List<int> sessionIds(String circleId, String sessionId) {
    final base = _hash('$circleId/$sessionId');
    return [base, base + 0x40000000];
  }

  static Future<void> cancelSession(String circleId, String sessionId) async {
    for (final id in sessionIds(circleId, sessionId)) {
      await _p.cancel(id);
    }
  }

  /// Cancels class alarms that are no longer wanted (deleted classes, left circles).
  static Future<void> keepOnlySessions(Set<int> keep) async {
    final pending = await _p.pendingNotificationRequests();
    for (final r in pending) {
      if (r.id == dailyId || r.id == 99) continue;
      if (!keep.contains(r.id)) await _p.cancel(r.id);
    }
  }

  /// Schedules a heads-up 15 minutes before and a ringing alarm at start time.
  static Future<void> scheduleSession(Session s, String circleName) async {
    final now = DateTime.now();
    final base = sessionIds(s.circleId, s.id).first;
    // Clear old times first in case the class was rescheduled.
    await cancelSession(s.circleId, s.id);
    final time = DateFormat('h:mm a').format(s.startsAt);
    final mode = await _mode();

    final early = s.startsAt.subtract(const Duration(minutes: 15));
    if (early.isAfter(now)) {
      await _p.zonedSchedule(
        base,
        '⏳ Class in 15 minutes',
        '${s.title} · $circleName at $time',
        _at(early),
        _alarmDetails(insistent: false),
        androidScheduleMode: mode,
      );
    }
    if (s.startsAt.isAfter(now)) {
      await _p.zonedSchedule(
        base + 0x40000000,
        '🔔 Class time: ${s.title}',
        '$circleName is starting now. Open StudyCircle and join your classmates.',
        _at(s.startsAt),
        _alarmDetails(insistent: true),
        androidScheduleMode: mode,
      );
    }
  }

  static Future<void> showTest() => _p.show(
        99,
        'StudyCircle',
        'Notifications are working 🎉 Your alarms will ring like this.',
        _alarmDetails(insistent: false),
      );
}
