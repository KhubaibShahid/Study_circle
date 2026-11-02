import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/notifications.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'circle_info_screen.dart';

class CircleChatScreen extends StatefulWidget {
  final String circleId;
  const CircleChatScreen({super.key, required this.circleId});
  @override
  State<CircleChatScreen> createState() => _CircleChatScreenState();
}

class _CircleChatScreenState extends State<CircleChatScreen> {
  late final Stream<Circle?> _circle = Db.circle(widget.circleId);
  late final Stream<List<Message>> _messages = Db.messages(widget.circleId);
  final _text = TextEditingController();
  StreamSubscription<List<Session>>? _sessionSub;
  Set<String> _knownSessions = {};
  Circle? _c;
  bool _checkedRoadmap = false;

  @override
  void initState() {
    super.initState();
    // Whenever anyone schedules, moves or cancels a class, update the alarms on this phone.
    _sessionSub = Db.upcomingSessions(widget.circleId).listen((sessions) {
      final ids = sessions.map((s) => s.id).toSet();
      for (final gone in _knownSessions.difference(ids)) {
        Notifs.cancelSession(widget.circleId, gone);
      }
      _knownSessions = ids;
      for (final s in sessions) {
        Notifs.scheduleSession(s, _c?.name ?? 'your circle');
      }
    });
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _text.dispose();
    super.dispose();
  }

  String get _me => Db.uid;

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _text.clear();
    try {
      await Db.sendText(widget.circleId, t);
    } catch (e) {
      if (mounted) toast(context, 'Message not sent: $e');
    }
  }

  // ───────────────────────── message actions ─────────────────────────
  void _messageOptions(Message m) {
    final c = _c;
    if (c == null || m.type == 'system') return;
    final mine = m.senderId == _me;
    final admin = c.isAdmin(_me);
    final actions = <SheetAction>[
      if (m.type == 'text')
        SheetAction(Icons.copy_rounded, 'Copy text', () {
          Clipboard.setData(ClipboardData(text: m.text));
          toast(context, 'Copied');
        }),
      if (m.type == 'text' && mine) SheetAction(Icons.edit_outlined, 'Edit message', () => _editText(m)),
      if (m.type == 'session' && (mine || admin))
        SheetAction(Icons.edit_calendar_rounded, 'Edit class', () => _editSession(m)),
      if (m.type == 'session' && (mine || admin))
        SheetAction(Icons.event_busy_rounded, 'Cancel class', () => _cancelSession(m), danger: true),
      if (m.type != 'session' && (mine || admin))
        SheetAction(Icons.delete_outline_rounded, mine ? 'Delete' : 'Delete (admin)', () => _delete(m),
            danger: true),
    ];
    if (actions.isEmpty) return;
    showOptionsSheet(context,
        title: m.type == 'poll' ? m.question : (m.text.isEmpty ? null : m.text), actions: actions);
  }

  void _editText(Message m) {
    final ctl = TextEditingController(text: m.text);
    showAppSheet(context, (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Edit message', style: display(22)),
        const SizedBox(height: 16),
        TextField(controller: ctl, minLines: 1, maxLines: 6, autofocus: true),
        const SizedBox(height: 16),
        GradientButton(
          label: 'Save',
          icon: Icons.check_rounded,
          onPressed: () async {
            final t = ctl.text.trim();
            if (t.isEmpty) return;
            await Db.editMessage(widget.circleId, m.id, t);
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
      ]);
    });
  }

  Future<void> _delete(Message m) async {
    if (!await confirm(context, 'Delete for everyone?', 'This removes the message from the chat.')) return;
    try {
      await Db.deleteMessage(widget.circleId, m.id);
    } catch (e) {
      if (mounted) toast(context, 'Could not delete: $e');
    }
  }

  Future<void> _editSession(Message m) async {
    if (m.sessionId == null) return;
    final s = await Db.sessionById(widget.circleId, m.sessionId!);
    if (!mounted) return;
    if (s == null) {
      toast(context, 'This class no longer exists.');
      return;
    }
    _sessionSheet(existing: s);
  }

  Future<void> _cancelSession(Message m) async {
    if (!await confirm(context, 'Cancel this class?', 'Alarms will be removed for everyone in the circle.',
        action: 'Cancel class')) {
      return;
    }
    try {
      if (m.sessionId != null) {
        await Db.deleteSession(widget.circleId, m.sessionId!);
        await Notifs.cancelSession(widget.circleId, m.sessionId!);
      } else {
        await Db.deleteMessage(widget.circleId, m.id);
      }
      if (mounted) toast(context, 'Class cancelled.');
    } catch (e) {
      if (mounted) toast(context, 'Could not cancel: $e');
    }
  }

  // ───────────────────────── composer actions ─────────────────────────
  void _attach() {
    final c = _c;
    if (c == null) return;
    if (!c.canOrganize(_me)) {
      toast(context, 'In a classroom, only admins can create polls and classes.');
      return;
    }
    showAppSheet(context, (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Add to chat', style: display(22)),
        const SizedBox(height: 16),
        GlassCard(
          color: AppColors.surface2,
          onTap: () {
            Navigator.pop(ctx);
            _sessionSheet();
          },
          child: Row(children: [
            Icon(Icons.event_rounded, color: AppColors.accent),
            const SizedBox(width: 14),
            const Expanded(
              child: Text('Schedule a class\nDate, time & alarm for everyone',
                  style: TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        GlassCard(
          color: AppColors.surface2,
          onTap: () {
            Navigator.pop(ctx);
            _pollSheet();
          },
          child: Row(children: [
            Icon(Icons.poll_rounded, color: AppColors.pink),
            const SizedBox(width: 14),
            const Expanded(
              child: Text('Create a poll\nDecide topics, timings, strategy',
                  style: TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
            ),
          ]),
        ),
      ]);
    });
  }

  void _pollSheet() {
    final q = TextEditingController();
    final opts = [TextEditingController(), TextEditingController()];
    showAppSheet(context, (ctx) {
      return StatefulBuilder(builder: (ctx, setSheet) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('New poll', style: display(22)),
          const SizedBox(height: 16),
          TextField(
              controller: q,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Question, e.g. "Best time for daily class?"')),
          const SizedBox(height: 12),
          for (var i = 0; i < opts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: opts[i],
                decoration: InputDecoration(
                  hintText: 'Option ${i + 1}',
                  suffixIcon: opts.length > 2
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setSheet(() => opts.removeAt(i)),
                        )
                      : null,
                ),
              ),
            ),
          if (opts.length < 6)
            TextButton.icon(
              onPressed: () => setSheet(() => opts.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: const Text('Add option'),
            ),
          const SizedBox(height: 12),
          GradientButton(
            label: 'Post poll',
            icon: Icons.send_rounded,
            onPressed: () async {
              final options = opts.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
              if (q.text.trim().isEmpty || options.length < 2) {
                toast(ctx, 'Add a question and at least 2 options.');
                return;
              }
              try {
                await Db.createPoll(widget.circleId, q.text.trim(), options);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) toast(ctx, 'Could not post: $e');
              }
            },
          ),
        ]);
      });
    });
  }

  void _sessionSheet({Session? existing}) {
    final title = TextEditingController(text: existing?.title ?? '');
    final note = TextEditingController(text: existing?.note ?? '');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = existing?.startsAt;
    var date = start == null ? today : DateTime(start.year, start.month, start.day);
    if (date.isBefore(today)) date = today;
    var time = start == null ? TimeOfDay(hour: (now.hour + 1) % 24, minute: 0) : TimeOfDay.fromDateTime(start);
    var duration = existing?.durationMin ?? 60;
    var loading = false;
    final circleName = _c?.name ?? 'your circle';

    showAppSheet(context, (ctx) {
      return StatefulBuilder(builder: (ctx, setSheet) {
        Widget pickerTile(IconData icon, String label, VoidCallback onTap) => Expanded(
              child: GlassCard(
                color: AppColors.surface2,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                onTap: onTap,
                child: Row(children: [
                  Icon(icon, size: 20, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              ),
            );
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(existing == null ? 'Schedule a class' : 'Edit class', style: display(22)),
          const SizedBox(height: 6),
          Text('Every member gets a reminder 15 min before and an alarm at start time.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          TextField(
            controller: title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'What will you study? e.g. "Graphs: BFS & DFS"'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            pickerTile(Icons.calendar_today_rounded, DateFormat('EEE, d MMM').format(date), () async {
              final d = await showDatePicker(
                context: ctx,
                initialDate: date,
                firstDate: today,
                lastDate: today.add(const Duration(days: 365)),
              );
              if (d != null) setSheet(() => date = d);
            }),
            const SizedBox(width: 10),
            pickerTile(Icons.schedule_rounded, time.format(ctx), () async {
              final t = await showTimePicker(context: ctx, initialTime: time);
              if (t != null) setSheet(() => time = t);
            }),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 8, children: [
            for (final d in [30, 45, 60, 90, 120])
              ChoiceChip(
                label: Text('$d min'),
                selected: duration == d,
                onSelected: (_) => setSheet(() => duration = d),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(hintText: 'Prep notes / meeting link (optional)'),
          ),
          const SizedBox(height: 18),
          GradientButton(
            label: existing == null ? 'Schedule & set alarms' : 'Save changes',
            icon: Icons.alarm_add_rounded,
            loading: loading,
            onPressed: () async {
              final startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
              if (title.text.trim().isEmpty) {
                toast(ctx, 'Give the class a title.');
                return;
              }
              if (!startsAt.isAfter(DateTime.now())) {
                toast(ctx, 'Pick a time in the future.');
                return;
              }
              setSheet(() => loading = true);
              try {
                if (existing == null) {
                  final s = await Db.createSession(widget.circleId,
                      title: title.text.trim(), startsAt: startsAt, durationMin: duration, note: note.text.trim());
                  await Notifs.scheduleSession(s, circleName);
                } else {
                  await Db.updateSession(existing,
                      title: title.text.trim(), startsAt: startsAt, durationMin: duration, note: note.text.trim());
                  final updated = await Db.sessionById(widget.circleId, existing.id);
                  if (updated != null) await Notifs.scheduleSession(updated, circleName);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  setSheet(() => loading = false);
                  toast(ctx, 'Could not save: $e');
                }
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
        _c = c;
        if (c != null && !_checkedRoadmap) {
          _checkedRoadmap = true;
          if (c.roadmapId != null) Db.ensureRoadmapAccess(c);
        }
        final removed = cs.connectionState == ConnectionState.active && (c == null || !c.memberIds.contains(_me));
        if (removed) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.no_accounts_rounded,
              title: 'You are not in this circle',
              subtitle: 'You left, were removed by an admin, or the circle was deleted.',
            ),
          );
        }
        final canOrganize = c?.canOrganize(_me) ?? false;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: InkWell(
              onTap: c == null
                  ? null
                  : () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => CircleInfoScreen(circleId: c.id))),
              child: Row(children: [
                Avatar(c?.name ?? '', size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c?.name ?? '…', overflow: TextOverflow.ellipsis, style: display(17)),
                    Text(
                        c == null
                            ? ''
                            : '${c.isClassroom ? 'Classroom' : 'Squad'} · ${c.memberIds.length} members · tap for info',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
              ]),
            ),
            actions: [
              if (canOrganize)
                IconButton(
                  tooltip: 'Schedule a class',
                  icon: const Icon(Icons.alarm_add_rounded),
                  onPressed: () => _sessionSheet(),
                ),
            ],
          ),
          body: Column(children: [
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: _messages,
                builder: (context, snap) {
                  if (!snap.hasData) return const Loader();
                  final msgs = snap.data!;
                  if (msgs.isEmpty) {
                    return EmptyState(
                      icon: Icons.forum_rounded,
                      title: 'Say hi to your class',
                      subtitle: canOrganize
                          ? 'Agree on a learning plan, run a poll, or schedule your first class with ⏰.'
                          : 'Your admins will schedule classes here. Say hi!',
                    );
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[i];
                      final older = i + 1 < msgs.length ? msgs[i + 1] : null;
                      final showName = older == null || older.senderId != m.senderId || older.type == 'system';
                      return _MessageView(
                        circleId: widget.circleId,
                        m: m,
                        showName: showName,
                        isAdminSender: c?.isAdmin(m.senderId) ?? false,
                        onLongPress: () => _messageOptions(m),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(children: [
                  if (canOrganize)
                    IconButton(
                      icon: Icon(Icons.add_circle_rounded, color: AppColors.accent, size: 30),
                      onPressed: _attach,
                    )
                  else
                    const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Message', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.gradient),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _MessageView extends StatelessWidget {
  final String circleId;
  final Message m;
  final bool showName;
  final bool isAdminSender;
  final VoidCallback onLongPress;
  const _MessageView({
    required this.circleId,
    required this.m,
    required this.showName,
    required this.isAdminSender,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (m.type == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(20)),
            child: Text(m.text, style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
        ),
      );
    }
    final mine = m.senderId == Db.uid;
    final fg = mine ? Colors.white : AppColors.text;
    final Widget body = switch (m.type) {
      'poll' => _PollCard(circleId: circleId, m: m),
      'session' => _SessionCard(m: m),
      _ => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: mine ? AppColors.gradient : null,
            color: mine ? null : AppColors.surface2,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(m.text, style: TextStyle(fontSize: 15, height: 1.35, color: fg)),
            const SizedBox(height: 3),
            Text('${m.edited ? 'edited · ' : ''}${DateFormat('h:mm a').format(m.createdAt)}',
                style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.6))),
          ]),
        ),
    };
    return Padding(
      padding: EdgeInsets.only(top: showName ? 10 : 3),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showName && !mine)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(m.senderName,
                    style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                if (isAdminSender) ...[
                  const SizedBox(width: 6),
                  Pill('admin', color: AppColors.warning),
                ],
              ]),
            ),
          GestureDetector(
            onLongPress: onLongPress,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  final String circleId;
  final Message m;
  const _PollCard({required this.circleId, required this.m});

  @override
  Widget build(BuildContext context) {
    final total = m.votes.length;
    final myVote = m.votes[Db.uid];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.pink.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Pill('POLL', color: AppColors.pink, icon: Icons.poll_rounded),
        const SizedBox(height: 10),
        Text(m.question, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 12),
        for (var i = 0; i < m.options.length; i++) _option(i, total, myVote),
        const SizedBox(height: 4),
        Text('$total vote${total == 1 ? '' : 's'} · by ${m.senderName} · tap to vote',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
      ]),
    );
  }

  Widget _option(int i, int total, int? myVote) {
    final count = m.votes.values.where((v) => v == i).length;
    final frac = total == 0 ? 0.0 : count / total;
    final selected = myVote == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Db.vote(circleId, m.id, i),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.accent : Colors.transparent),
          ),
          child: Stack(alignment: Alignment.centerLeft, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: frac),
              duration: const Duration(milliseconds: 500),
              builder: (_, v, __) => FractionallySizedBox(
                widthFactor: v,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppColors.primary.withValues(alpha: 0.35),
                      AppColors.accent.withValues(alpha: 0.25),
                    ]),
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                if (selected) Icon(Icons.check_circle_rounded, size: 16, color: AppColors.accent),
                if (selected) const SizedBox(width: 6),
                Expanded(child: Text(m.options[i], overflow: TextOverflow.ellipsis)),
                Text('$count · ${(frac * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Message m;
  const _SessionCard({required this.m});

  @override
  Widget build(BuildContext context) {
    final start = m.startsAt ?? m.createdAt;
    final ended = DateTime.now().isAfter(start.add(Duration(minutes: m.durationMin)));
    final live = !ended && DateTime.now().isAfter(start);
    final fg = ended ? AppColors.text : Colors.white;
    final fgSoft = ended ? AppColors.muted : Colors.white70;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: ended ? null : AppColors.gradient,
        color: ended ? AppColors.surface2 : null,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.event_rounded, color: fg, size: 18),
          const SizedBox(width: 6),
          Text(live ? 'CLASS IS LIVE' : (ended ? 'CLASS ENDED' : 'CLASS SCHEDULED'),
              style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2)),
          if (m.edited) ...[
            const SizedBox(width: 6),
            Text('· updated', style: TextStyle(color: fgSoft, fontSize: 11)),
          ],
        ]),
        const SizedBox(height: 8),
        Text(m.text, style: display(17, color: fg)),
        const SizedBox(height: 6),
        Text('${DateFormat('EEE, d MMM · h:mm a').format(start)} · ${m.durationMin} min',
            style: TextStyle(color: fgSoft)),
        if (!ended) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
            child: const Text('⏰ Alarm set on your phone',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
        const SizedBox(height: 6),
        Text('by ${m.senderName} · hold for options', style: TextStyle(color: fgSoft, fontSize: 11)),
      ]),
    );
  }
}
