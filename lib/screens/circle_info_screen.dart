import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/db.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'roadmap_detail_screen.dart';

class _Rank {
  final String uid;
  final String name;
  final int done;
  const _Rank(this.uid, this.name, this.done);
}

class CircleInfoScreen extends StatefulWidget {
  final Circle circle;
  const CircleInfoScreen({super.key, required this.circle});
  @override
  State<CircleInfoScreen> createState() => _CircleInfoScreenState();
}

class _CircleInfoScreenState extends State<CircleInfoScreen> {
  late final Future<(Roadmap?, List<_Rank>)> _board = _load();
  late final Future<List<Session>> _sessions = Db.upcomingSessionsOnce(widget.circle.id);

  Future<(Roadmap?, List<_Rank>)> _load() async {
    final c = widget.circle;
    Roadmap? roadmap;
    if (c.roadmapId != null) {
      roadmap = await Db.roadmap(c.roadmapId!).first;
    }
    final ranks = <_Rank>[];
    for (final m in c.memberIds) {
      final name = await Db.userName(m);
      var done = 0;
      if (roadmap != null) {
        try {
          final set = await Db.progressOnce(roadmap.id, m);
          done = roadmap.doneCount(set);
        } catch (_) {}
      }
      ranks.add(_Rank(m, name, done));
    }
    ranks.sort((a, b) => b.done.compareTo(a.done));
    return (roadmap, ranks);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.circle;
    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          GlassCard(
            gradient: AppColors.gradient,
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const Text('INVITE CODE',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 1.4, fontSize: 12)),
              const SizedBox(height: 8),
              Text(c.inviteCode, style: display(38, color: Colors.white).copyWith(letterSpacing: 8)),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.bg),
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                      text: 'Join my study circle "${c.name}" on StudyCircle with code ${c.inviteCode}'));
                  toast(context, 'Invite copied — send it on WhatsApp!');
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy invite'),
              ),
            ]),
          ),
          const SectionLabel('Upcoming classes'),
          FutureBuilder<List<Session>>(
            future: _sessions,
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox(height: 50, child: Loader());
              if (snap.data!.isEmpty) {
                return const Text('No classes scheduled yet. Use ⏰ in the chat to plan one.',
                    style: TextStyle(color: AppColors.muted));
              }
              return Column(children: [
                for (final s in snap.data!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        const Icon(Icons.alarm_on_rounded, color: AppColors.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${DateFormat('EEE, d MMM · h:mm a').format(s.startsAt)} · ${s.durationMin} min',
                                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                            if (s.note.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: SelectableText(s.note, style: const TextStyle(fontSize: 13)),
                              ),
                          ]),
                        ),
                      ]),
                    ),
                  ),
              ]);
            },
          ),
          const SectionLabel('Leaderboard'),
          FutureBuilder<(Roadmap?, List<_Rank>)>(
            future: _board,
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox(height: 60, child: Loader());
              final (roadmap, ranks) = snap.data!;
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (roadmap != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => RoadmapDetailScreen(roadmapId: roadmap.id))),
                      child: Row(children: [
                        const Icon(Icons.route_rounded, color: AppColors.pink),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('Shared roadmap: ${roadmap.title}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                      ]),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('This circle has no shared roadmap, so progress is not compared.',
                        style: TextStyle(color: AppColors.muted)),
                  ),
                for (var i = 0; i < ranks.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        SizedBox(
                          width: 28,
                          child: Text(i < 3 ? ['🥇', '🥈', '🥉'][i] : '${i + 1}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                        Avatar(ranks[i].name, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(ranks[i].uid == Db.uid ? '${ranks[i].name} (you)' : ranks[i].name,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (roadmap != null) ...[
                              const SizedBox(height: 6),
                              GradientBar(
                                  value: roadmap.topicCount == 0 ? 0 : ranks[i].done / roadmap.topicCount,
                                  height: 6),
                            ],
                          ]),
                        ),
                        if (roadmap != null) ...[
                          const SizedBox(width: 12),
                          Text('${ranks[i].done}/${roadmap.topicCount}',
                              style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                        ],
                      ]),
                    ),
                  ),
              ]);
            },
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () async {
              if (await confirm(context, 'Leave circle?', 'You will stop getting its chat and class alarms.',
                  action: 'Leave')) {
                await Db.leaveCircle(c.id);
                if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
            label: const Text('Leave circle', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
