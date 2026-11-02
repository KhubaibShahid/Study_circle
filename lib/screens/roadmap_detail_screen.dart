import 'package:flutter/material.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/reminders.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'exam_screen.dart';
import 'roadmap_editor_screen.dart';
import 'topic_screen.dart';
import 'tutor_screen.dart';

class RoadmapDetailScreen extends StatefulWidget {
  final String roadmapId;
  const RoadmapDetailScreen({super.key, required this.roadmapId});
  @override
  State<RoadmapDetailScreen> createState() => _RoadmapDetailScreenState();
}

class _RoadmapDetailScreenState extends State<RoadmapDetailScreen> {
  late final Stream<Roadmap?> _roadmap = Db.roadmap(widget.roadmapId);
  late final Stream<Set<String>> _progress = Db.progress(widget.roadmapId);
  late final Stream<List<ExamResult>> _exams = Db.examsFor(widget.roadmapId);

  Future<void> _menu(String v, Roadmap r) async {
    switch (v) {
      case 'focus':
        await Db.saveSettings({'activeRoadmapId': r.id});
        Reminders.syncDaily();
        if (mounted) toast(context, 'Daily reminders will now follow "${r.title}".');
      case 'edit':
        Navigator.push(context, MaterialPageRoute(builder: (_) => RoadmapEditorScreen.edit(r)));
      case 'delete':
        if (await confirm(context, 'Delete roadmap?', 'This removes "${r.title}" for everyone sharing it.')) {
          await Db.deleteRoadmap(r.id);
          Reminders.syncDaily();
          if (mounted) Navigator.pop(context);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Roadmap?>(
      stream: _roadmap,
      builder: (context, rs) {
        if (rs.connectionState == ConnectionState.waiting) return const Scaffold(body: Loader());
        final r = rs.data;
        if (r == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
                icon: Icons.search_off, title: 'Roadmap not found', subtitle: 'It may have been deleted.'),
          );
        }
        final isOwner = r.ownerId == Db.uid;
        return Scaffold(
          appBar: AppBar(
            title: Text(r.title, overflow: TextOverflow.ellipsis),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) => _menu(v, r),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'focus', child: Text('Set as daily focus')),
                  if (isOwner) const PopupMenuItem(value: 'edit', child: Text('Edit roadmap')),
                  if (isOwner) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          body: StreamBuilder<Set<String>>(
            stream: _progress,
            builder: (context, ps) {
              final done = ps.data ?? <String>{};
              return StreamBuilder<List<ExamResult>>(
                stream: _exams,
                builder: (context, es) {
                  final best = <String, ExamResult>{};
                  for (final e in es.data ?? const <ExamResult>[]) {
                    final cur = best[e.sectionId];
                    if (cur == null || e.pct > cur.pct) best[e.sectionId] = e;
                  }
                  final passed = r.sections.where((s) => best[s.id]?.passed == true).length;
                  final firstOpen = r.sections.indexWhere((s) => !s.isComplete(done) || best[s.id]?.passed != true);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      _Header(roadmap: r, done: done, passed: passed),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: GhostButton(
                            label: 'Ask tutor',
                            icon: Icons.auto_awesome,
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => TutorScreen(roadmapId: r.id, standalone: true))),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GhostButton(
                            label: 'Daily focus',
                            icon: Icons.alarm_rounded,
                            onPressed: () => _menu('focus', r),
                          ),
                        ),
                      ]),
                      const SectionLabel('Syllabus'),
                      for (var i = 0; i < r.sections.length; i++)
                        _SectionCard(
                          roadmap: r,
                          section: r.sections[i],
                          index: i,
                          done: done,
                          best: best[r.sections[i].id],
                          initiallyExpanded: i == (firstOpen < 0 ? 0 : firstOpen),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final Roadmap roadmap;
  final Set<String> done;
  final int passed;
  const _Header({required this.roadmap, required this.done, required this.passed});

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: display(20)),
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ]);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        ProgressRing(
          value: roadmap.progress(done),
          size: 110,
          stroke: 10,
          center: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${(roadmap.progress(done) * 100).round()}%', style: display(26)),
            const Text('complete', style: TextStyle(color: AppColors.muted, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (roadmap.description.isNotEmpty) ...[
              Text(roadmap.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
              const SizedBox(height: 12),
            ],
            Row(children: [
              Expanded(child: stat('${roadmap.doneCount(done)}/${roadmap.topicCount}', 'topics')),
              Expanded(child: stat('$passed/${roadmap.sections.length}', 'exams passed')),
            ]),
            if (roadmap.isShared) ...[
              const SizedBox(height: 10),
              Pill('Shared with ${roadmap.memberIds.length - 1} classmates', color: AppColors.pink, icon: Icons.groups),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Roadmap roadmap;
  final Section section;
  final int index;
  final Set<String> done;
  final ExamResult? best;
  final bool initiallyExpanded;

  const _SectionCard({
    required this.roadmap,
    required this.section,
    required this.index,
    required this.done,
    required this.best,
    required this.initiallyExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final complete = section.isComplete(done);
    final examPassed = best?.passed == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: examPassed ? AppColors.success.withValues(alpha: 0.5) : AppColors.border),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
            shape: const RoundedRectangleBorder(),
            leading: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: examPassed ? null : AppColors.gradient,
                color: examPassed ? AppColors.success : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: examPassed
                  ? const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22)
                  : Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            title: Text(section.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Expanded(child: GradientBar(value: section.progress(done), height: 6)),
                const SizedBox(width: 10),
                Text('${section.doneCount(done)}/${section.topics.length}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ]),
            ),
            children: [
              for (final t in section.topics) _TopicRow(roadmap: roadmap, section: section, topic: t, done: done),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: complete
                    ? GradientButton(
                        label: best == null
                            ? 'Take section exam'
                            : 'Retake exam · best ${best!.score}/${best!.total} (${gradeFor(best!.pct)})',
                        icon: Icons.quiz_rounded,
                        gradient: examPassed
                            ? const LinearGradient(colors: [AppColors.success, AppColors.accent])
                            : AppColors.warmGradient,
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => ExamScreen(roadmap: roadmap, section: section))),
                      )
                    : Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(children: [
                          Icon(Icons.lock_outline_rounded, color: AppColors.muted, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text('Finish every topic to unlock the section exam.',
                                style: TextStyle(color: AppColors.muted, fontSize: 13)),
                          ),
                        ]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  final Roadmap roadmap;
  final Section section;
  final Topic topic;
  final Set<String> done;
  const _TopicRow({required this.roadmap, required this.section, required this.topic, required this.done});

  @override
  Widget build(BuildContext context) {
    final isDone = done.contains(topic.id);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: GestureDetector(
        onTap: () async {
          await Db.setTopicDone(roadmap.id, topic.id, !isDone);
          Reminders.syncDaily();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isDone ? AppColors.gradient : null,
            border: isDone ? null : Border.all(color: AppColors.muted, width: 2),
          ),
          child: isDone ? const Icon(Icons.check_rounded, size: 17, color: Colors.white) : null,
        ),
      ),
      title: Text(
        topic.title,
        style: TextStyle(
          color: isDone ? AppColors.muted : AppColors.text,
          decoration: isDone ? TextDecoration.lineThrough : null,
          decorationColor: AppColors.muted,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TopicScreen(roadmap: roadmap, section: section, topic: topic)),
      ),
    );
  }
}
