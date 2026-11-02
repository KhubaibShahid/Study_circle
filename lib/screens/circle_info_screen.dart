import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/reminders.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'roadmap_detail_screen.dart';

class _Member {
  final String uid;
  final String name;
  final int done;
  const _Member(this.uid, this.name, this.done);
}

class CircleInfoScreen extends StatefulWidget {
  final String circleId;
  const CircleInfoScreen({super.key, required this.circleId});
  @override
  State<CircleInfoScreen> createState() => _CircleInfoScreenState();
}

class _CircleInfoScreenState extends State<CircleInfoScreen> {
  late final Stream<Circle?> _circle = Db.circle(widget.circleId);
  late final Future<List<Session>> _sessions = Db.upcomingSessionsOnce(widget.circleId);
  Future<(Roadmap?, List<_Member>)>? _members;
  String _membersKey = '';

  String get _me => Db.uid;

  Future<(Roadmap?, List<_Member>)> _load(Circle c) async {
    Roadmap? roadmap;
    if (c.roadmapId != null) {
      try {
        roadmap = await Db.roadmap(c.roadmapId!).first;
      } catch (_) {}
    }
    final list = <_Member>[];
    for (final m in c.memberIds) {
      final name = await Db.userName(m);
      var done = 0;
      if (roadmap != null) {
        try {
          done = roadmap.doneCount(await Db.progressOnce(roadmap.id, m));
        } catch (_) {}
      }
      list.add(_Member(m, name, done));
    }
    list.sort((a, b) => b.done.compareTo(a.done));
    return (roadmap, list);
  }

  // ───────────────────────── admin actions ─────────────────────────
  void _memberOptions(Circle c, _Member m) {
    if (m.uid == _me) return;
    final iAmOwner = c.isOwner(_me);
    final iAmAdmin = c.isAdmin(_me);
    final theyAreAdmin = c.isAdmin(m.uid);
    final theyAreOwner = c.isOwner(m.uid);
    final actions = <SheetAction>[
      if (iAmOwner && !theyAreOwner)
        SheetAction(
          theyAreAdmin ? Icons.remove_moderator_outlined : Icons.add_moderator_outlined,
          theyAreAdmin ? 'Remove admin role' : 'Make admin',
          () => _run(() => Db.setAdmin(c.id, m.uid, !theyAreAdmin),
              theyAreAdmin ? '${m.name} is no longer an admin.' : '${m.name} is now an admin.'),
        ),
      // Admins can remove students; only the owner can remove other admins.
      if (iAmAdmin && !theyAreOwner && (!theyAreAdmin || iAmOwner))
        SheetAction(Icons.person_remove_alt_1_rounded, 'Remove from circle', () async {
          if (await confirm(context, 'Remove ${m.name}?',
              'They will lose access to the chat and classes, and can\'t rejoin with the invite code unless an admin adds them back.',
              action: 'Remove')) {
            await _run(() => Db.removeMember(c, m.uid, m.name), '${m.name} was removed.');
          }
        }, danger: true),
    ];
    if (actions.isEmpty) return;
    showOptionsSheet(context, title: m.name, actions: actions);
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (mounted) toast(context, success);
    } catch (e) {
      if (mounted) toast(context, 'Failed: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  void _addByEmail(Circle c) {
    final email = TextEditingController();
    var loading = false;
    showAppSheet(context, (ctx) {
      return StatefulBuilder(builder: (ctx, setSheet) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Add a member', style: display(22)),
          const SizedBox(height: 6),
          Text('They need a StudyCircle account. Or just share the invite code.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'friend@email.com', prefixIcon: Icon(Icons.alternate_email)),
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Add to circle',
            icon: Icons.person_add_alt_1_rounded,
            loading: loading,
            onPressed: () async {
              if (email.text.trim().isEmpty) return;
              setSheet(() => loading = true);
              try {
                final name = await Db.addMemberByEmail(c, email.text);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                toast(context, '$name added.');
              } catch (e) {
                if (ctx.mounted) {
                  setSheet(() => loading = false);
                  toast(ctx, e.toString().replaceFirst('Exception: ', ''));
                }
              }
            },
          ),
        ]);
      });
    });
  }

  void _settings(Circle c) {
    final name = TextEditingController(text: c.name);
    var type = c.type;
    showAppSheet(context, (ctx) {
      return StatefulBuilder(builder: (ctx, setSheet) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Circle settings', style: display(22)),
          const SizedBox(height: 16),
          TextField(controller: name, decoration: const InputDecoration(hintText: 'Circle name')),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'squad', label: Text('Squad'), icon: Icon(Icons.diversity_3_rounded)),
              ButtonSegment(value: 'classroom', label: Text('Classroom'), icon: Icon(Icons.school_rounded)),
            ],
            selected: {type},
            onSelectionChanged: (v) => setSheet(() => type = v.first),
          ),
          const SizedBox(height: 8),
          Text(
            type == 'classroom'
                ? 'Classroom: only admins can create polls and schedule classes. Students chat and vote.'
                : 'Squad: everyone can chat, create polls and schedule classes. Admins can still remove people.',
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          GradientButton(
            label: 'Save',
            icon: Icons.check_rounded,
            onPressed: () async {
              try {
                if (name.text.trim().isNotEmpty && name.text.trim() != c.name) {
                  await Db.renameCircle(c.id, name.text.trim());
                }
                if (type != c.type) await Db.setCircleType(c.id, type);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) toast(ctx, 'Failed: $e');
              }
            },
          ),
        ]);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Circle?>(
      stream: _circle,
      builder: (context, cs) {
        final c = cs.data;
        if (c == null || !c.memberIds.contains(_me)) {
          return Scaffold(
            appBar: AppBar(),
            body: cs.connectionState == ConnectionState.waiting
                ? const Loader()
                : const EmptyState(
                    icon: Icons.no_accounts_rounded,
                    title: 'Not available',
                    subtitle: 'You are no longer a member of this circle.'),
          );
        }
        final key = '${c.memberIds.join(',')}|${c.roadmapId}';
        if (key != _membersKey) {
          _membersKey = key;
          _members = _load(c);
        }
        final iAmAdmin = c.isAdmin(_me);
        final iAmOwner = c.isOwner(_me);

        return Scaffold(
          appBar: AppBar(
            title: Text(c.name, overflow: TextOverflow.ellipsis),
            actions: [
              if (iAmAdmin)
                IconButton(
                    tooltip: 'Settings', icon: const Icon(Icons.tune_rounded), onPressed: () => _settings(c)),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              GlassCard(
                gradient: AppColors.gradient,
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(c.isClassroom ? Icons.school_rounded : Icons.diversity_3_rounded,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text('${c.isClassroom ? 'CLASSROOM' : 'STUDY SQUAD'} · INVITE CODE',
                        style: const TextStyle(
                            color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12)),
                  ]),
                  const SizedBox(height: 8),
                  Text(c.inviteCode, style: display(38, color: Colors.white).copyWith(letterSpacing: 8)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white, foregroundColor: const Color(0xFF14162B)),
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
                    return Text(
                        c.canOrganize(_me)
                            ? 'No classes scheduled yet. Use ⏰ in the chat to plan one.'
                            : 'No classes scheduled yet.',
                        style: TextStyle(color: AppColors.muted));
                  }
                  return Column(children: [
                    for (final s in snap.data!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Icon(Icons.alarm_on_rounded, color: AppColors.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                    '${DateFormat('EEE, d MMM · h:mm a').format(s.startsAt)} · ${s.durationMin} min',
                                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
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
              SectionLabel('Members · ${c.memberIds.length}',
                  trailing: iAmAdmin
                      ? TextButton.icon(
                          onPressed: () => _addByEmail(c),
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                          label: const Text('Add'),
                        )
                      : null),
              FutureBuilder<(Roadmap?, List<_Member>)>(
                future: _members,
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox(height: 60, child: Loader());
                  final (roadmap, members) = snap.data!;
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (roadmap != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => RoadmapDetailScreen(roadmapId: roadmap.id))),
                          child: Row(children: [
                            Icon(Icons.route_rounded, color: AppColors.pink),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('Shared roadmap: ${roadmap.title}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                          ]),
                        ),
                      ),
                    if (iAmAdmin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text('Tap a member to manage them.',
                            style: TextStyle(color: AppColors.muted, fontSize: 12)),
                      ),
                    for (var i = 0; i < members.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.all(14),
                          onTap: iAmAdmin && members[i].uid != _me ? () => _memberOptions(c, members[i]) : null,
                          child: Row(children: [
                            if (roadmap != null)
                              SizedBox(
                                width: 28,
                                child: Text(i < 3 ? ['🥇', '🥈', '🥉'][i] : '${i + 1}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              ),
                            Avatar(members[i].name, size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                  Text(members[i].uid == _me ? '${members[i].name} (you)' : members[i].name,
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  if (c.isOwner(members[i].uid))
                                    Pill('owner', color: AppColors.warning)
                                  else if (c.isAdmin(members[i].uid))
                                    Pill('admin', color: AppColors.warning),
                                ]),
                                if (roadmap != null) ...[
                                  const SizedBox(height: 6),
                                  GradientBar(
                                      value: roadmap.topicCount == 0 ? 0 : members[i].done / roadmap.topicCount,
                                      height: 6),
                                ],
                              ]),
                            ),
                            if (roadmap != null) ...[
                              const SizedBox(width: 12),
                              Text('${members[i].done}/${roadmap.topicCount}',
                                  style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                            ],
                            if (iAmAdmin && members[i].uid != _me) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.more_vert, color: AppColors.muted, size: 20),
                            ],
                          ]),
                        ),
                      ),
                  ]);
                },
              ),
              const SizedBox(height: 24),
              if (iAmOwner)
                TextButton.icon(
                  onPressed: () async {
                    if (await confirm(context, 'Delete circle?',
                        'This deletes "${c.name}" for everyone. Chat history and classes are lost.')) {
                      await Db.deleteCircle(c);
                      await Reminders.syncSessions();
                      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  },
                  icon: Icon(Icons.delete_forever_rounded, color: AppColors.danger),
                  label: Text('Delete circle', style: TextStyle(color: AppColors.danger)),
                )
              else
                TextButton.icon(
                  onPressed: () async {
                    if (await confirm(context, 'Leave circle?', 'You will stop getting its chat and class alarms.',
                        action: 'Leave')) {
                      await Db.leaveCircle(c.id);
                      await Reminders.syncSessions();
                      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  },
                  icon: Icon(Icons.logout_rounded, color: AppColors.danger),
                  label: Text('Leave circle', style: TextStyle(color: AppColors.danger)),
                ),
            ],
          ),
        );
      },
    );
  }
}
