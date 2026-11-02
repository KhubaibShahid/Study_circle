import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/reminders.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'roadmap_detail_screen.dart';
import 'topic_screen.dart';

class TodayScreen extends StatefulWidget {
  final void Function(int tab) onOpenTab;
  const TodayScreen({super.key, required this.onOpenTab});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late final Stream<AppSettings> _settings = Db.settingsStream();
  late final Stream<List<Roadmap>> _roadmaps = Db.myRoadmaps();
  late Future<List<(Session, String)>> _sessions = Db.allUpcomingSessions();
  late Future<List<ExamResult>> _exams = Db.recentExams();

  Future<void> _refresh() async {
    setState(() {
      _sessions = Db.allUpcomingSessions();
      _exams = Db.recentExams();
    });
    await Reminders.syncAll();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<AppSettings>(
        stream: _settings,
        builder: (context, ss) {
          final settings = ss.data ?? const AppSettings();
          return StreamBuilder<List<Roadmap>>(
            stream: _roadmaps,
            builder: (context, rs) {
              final roadmaps = rs.data ?? const <Roadmap>[];
              Roadmap? focus;
              for (final r in roadmaps) {
                if (r.id == settings.activeRoadmapId) focus = r;
              }
              focus ??= roadmaps.isEmpty ? null : roadmaps.first;

              return RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.primary,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
                              style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('$_greeting,\n${Db.myName.split(' ').first} 👋', style: display(28)),
                        ]),
                      ),
                      Avatar(Db.myName, size: 48),
                    ]),
                    const SizedBox(height: 24),
                    if (!rs.hasData)
                      const Loader()
                    else if (focus == null)
                      _NoRoadmapCard(onCreate: () => widget.onOpenTab(1))
                    else
                      _LessonCard(key: ValueKey(focus.id), roadmap: focus),
                    SectionLabel('Upcoming classes',
                        trailing: TextButton(onPressed: () => widget.onOpenTab(2), child: const Text('Circles'))),
                    FutureBuilder<List<(Session, String)>>(
                      future: _sessions,
                      builder: (context, snap) {
                        if (!snap.hasData) return const SizedBox(height: 60, child: Loader());
                        final list = snap.data!;
                        if (list.isEmpty) {
                          return const GlassCard(
                            child: Row(children: [
                              Icon(Icons.event_available_outlined, color: AppColors.muted),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text('No classes scheduled. Open a circle and plan one with your friends.',
                                    style: TextStyle(color: AppColors.muted)),
                              ),
                            ]),
                          );
                        }
                        return Column(
                          children: [for (final (s, name) in list.take(4)) _SessionTile(session: s, circleName: name)],
                        );
                      },
                    ),
                    if (roadmaps.isNotEmpty) ...[
                      const SectionLabel('Your progress'),
                      for (final r in roadmaps) _ProgressTile(roadmap: r),
                    ],
                    FutureBuilder<List<ExamResult>>(
                      future: _exams,
                      builder: (context, snap) {
                        final list = snap.data ?? const [];
                        if (list.isEmpty) return const SizedBox.shrink();
                        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          const SectionLabel('Recent exams'),
                          for (final e in list) _ExamTile(result: e),
                        ]);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _NoRoadmapCard extends StatelessWidget {
  final VoidCallback onCreate;
  const _NoRoadmapCard({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      gradient: AppColors.gradient,
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.flag_rounded, color: Colors.white, size: 32),
        const SizedBox(height: 12),
        Text('Start your first roadmap', style: display(22, color: Colors.white)),
        const SizedBox(height: 6),
        const Text(
          'Paste the roadmap you already have, build one by hand, or let AI design it. '
          'Then StudyCircle tells you what to learn every day.',
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onCreate,
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.bg),
          icon: const Icon(Icons.add),
          label: const Text('Create roadmap'),
        ),
      ]),
    );
  }
}

class _LessonCard extends StatefulWidget {
  final Roadmap roadmap;
  const _LessonCard({super.key, required this.roadmap});
  @override
  State<_LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends State<_LessonCard> {
  late final Stream<Set<String>> _progress = Db.progress(widget.roadmap.id);

  @override
  Widget build(BuildContext context) {
    final r = widget.roadmap;
    return StreamBuilder<Set<String>>(
      stream: _progress,
      builder: (context, snap) {
        final done = snap.data ?? <String>{};
        final lesson = nextLesson(r, done);
        return GlassCard(
          gradient: AppColors.gradient,
          padding: const EdgeInsets.all(22),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => RoadmapDetailScreen(roadmapId: r.id))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("TODAY'S LESSON",
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                  const SizedBox(height: 10),
                  Text(lesson?.topic.title ?? 'Roadmap complete 🎓',
                      style: display(24, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(
                    lesson == null
                        ? 'Every topic in ${r.title} is done. Make sure you passed all section exams.'
                        : '${r.title} › Section ${lesson.sectionIndex + 1}: ${lesson.section.title}',
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              ProgressRing(
                value: r.progress(done),
                size: 76,
                track: Colors.white24,
                center: Text('${(r.progress(done) * 100).round()}%', style: display(17, color: Colors.white)),
              ),
            ]),
            if (lesson != null) ...[
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.bg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              TopicScreen(roadmap: r, section: lesson.section, topic: lesson.topic)),
                    ),
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: const Text('Study now'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      await Db.setTopicDone(r.id, lesson.topic.id, true);
                      Reminders.syncDaily();
                      if (context.mounted) toast(context, 'Nice! "${lesson.topic.title}" marked as learned.');
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Learned it'),
                  ),
                ),
              ]),
            ],
          ]),
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Session session;
  final String circleName;
  const _SessionTile({required this.session, required this.circleName});

  @override
  Widget build(BuildContext context) {
    final live = DateTime.now().isAfter(session.startsAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              Text(DateFormat('MMM').format(session.startsAt).toUpperCase(),
                  style: const TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w800)),
              Text('${session.startsAt.day}', style: display(20)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              Text('$circleName · ${DateFormat('EEE h:mm a').format(session.startsAt)} · ${session.durationMin} min',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ]),
          ),
          live
              ? const Pill('LIVE', color: AppColors.success, icon: Icons.circle)
              : const Icon(Icons.alarm_on_rounded, color: AppColors.accent),
        ]),
      ),
    );
  }
}

class _ProgressTile extends StatefulWidget {
  final Roadmap roadmap;
  const _ProgressTile({required this.roadmap});
  @override
  State<_ProgressTile> createState() => _ProgressTileState();
}

class _ProgressTileState extends State<_ProgressTile> {
  late final Stream<Set<String>> _p = Db.progress(widget.roadmap.id);

  @override
  Widget build(BuildContext context) {
    final r = widget.roadmap;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StreamBuilder<Set<String>>(
        stream: _p,
        builder: (context, snap) {
          final done = snap.data ?? <String>{};
          return GlassCard(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => RoadmapDetailScreen(roadmapId: r.id))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(r.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        overflow: TextOverflow.ellipsis)),
                Text('${r.doneCount(done)}/${r.topicCount}',
                    style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              GradientBar(value: r.progress(done)),
            ]),
          );
        },
      ),
    );
  }
}

class _ExamTile extends StatelessWidget {
  final ExamResult result;
  const _ExamTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final c = result.passed ? AppColors.success : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: Text(gradeFor(result.pct), style: display(20, color: c)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(result.sectionTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('${result.roadmapTitle} · ${DateFormat('d MMM').format(result.createdAt)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ]),
          ),
          Text('${result.score}/${result.total}', style: display(16, color: c)),
        ]),
      ),
    );
  }
}
