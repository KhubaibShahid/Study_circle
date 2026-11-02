import 'package:flutter/foundation.dart';

import '../models.dart';
import 'db.dart';
import 'notifications.dart';

/// Keeps local alarms in sync with Firestore data.
class Reminders {
  static Future<void> syncAll() async {
    await syncDaily();
    await syncSessions();
  }

  /// The roadmap the learner is focusing on: the chosen one, else the first unfinished one.
  static Future<Lesson?> todaysLesson([AppSettings? settings]) async {
    final s = settings ?? await Db.settings();
    final roadmaps = await Db.myRoadmapsOnce();
    if (roadmaps.isEmpty) return null;
    final ordered = [
      ...roadmaps.where((r) => r.id == s.activeRoadmapId),
      ...roadmaps.where((r) => r.id != s.activeRoadmapId),
    ];
    for (final r in ordered) {
      final lesson = nextLesson(r, await Db.progressOnce(r.id));
      if (lesson != null) return lesson;
    }
    return null;
  }

  static Future<void> syncDaily() async {
    try {
      final s = await Db.settings();
      if (!s.reminderEnabled) {
        await Notifs.cancel(Notifs.dailyId);
        return;
      }
      final lesson = await todaysLesson(s);
      final body = lesson == null
          ? 'Plan your next topic in StudyCircle and keep the streak alive.'
          : 'Today: ${lesson.topic.title}\n${lesson.roadmap.title} › ${lesson.section.title}';
      await Notifs.scheduleDaily(
        hour: s.reminderHour,
        minute: s.reminderMinute,
        title: '📚 Time to learn',
        body: body,
      );
    } catch (e) {
      debugPrint('Daily reminder sync failed: $e');
    }
  }

  static Future<void> syncSessions() async {
    try {
      for (final c in await Db.myCirclesOnce()) {
        for (final s in await Db.upcomingSessionsOnce(c.id)) {
          await Notifs.scheduleSession(s, c.name);
        }
      }
    } catch (e) {
      debugPrint('Session alarm sync failed: $e');
    }
  }
}
