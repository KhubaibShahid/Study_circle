import 'dart:async';

import 'package:flutter/material.dart';
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
  String _circleName = 'your circle';

  @override
  void initState() {
    super.initState();
    // Whenever anyone schedules a class, set the alarm on this phone too.
    _sessionSub = Db.upcomingSessions(widget.circleId).listen((sessions) {
      for (final s in sessions) {
        Notifs.scheduleSession(s, _circleName);
      }
    });
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _text.clear();
    await Db.sendText(widget.circleId, t);
  }

  void _attach() {
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
          child: const Row(children: [
            Icon(Icons.event_rounded, color: AppColors.accent),
            SizedBox(width: 14),
            Expanded(
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
          child: const Row(children: [
            Icon(Icons.poll_rounded, color: AppColors.pink),
            SizedBox(width: 14),
            Expanded(
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
              await Db.createPoll(widget.circleId, q.text.trim(), options);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ]);
      });
    });
  }

  void _sessionSheet() {
    final title = TextEditingController();
    final note = TextEditingController();
    final now = DateTime.now();
    var date = DateTime(now.year, now.month, now.day);
    var time = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
    var duration = 60;
    var loading = false;

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
          Text('Schedule a class', style: display(22)),
          const SizedBox(height: 6),
          const Text('Every member gets a reminder 15 min before and an alarm at start time.',
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
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: now.add(const Duration(days: 365)),
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
            label: 'Schedule & set alarms',
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
                final s = await Db.createSession(widget.circleId,
                    title: title.text.trim(), startsAt: startsAt, durationMin: duration, note: note.text.trim());
                await Notifs.scheduleSession(s, _circleName);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  setSheet(() => loading = false);
                  toast(ctx, 'Could not schedule: $e');
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
        if (c != null) _circleName = c.name;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: InkWell(
              onTap: c == null
                  ? null
                  : () => Navigator.push(context, MaterialPageRoute(builder: (_) => CircleInfoScreen(circle: c))),
              child: Row(children: [
                Avatar(c?.name ?? '', size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c?.name ?? '…', overflow: TextOverflow.ellipsis, style: display(17)),
                    Text(c == null ? '' : '${c.memberIds.length} members · tap for info',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
              ]),
            ),
            actions: [
              IconButton(
                tooltip: 'Schedule a class',
                icon: const Icon(Icons.alarm_add_rounded),
                onPressed: _sessionSheet,
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
                    return const EmptyState(
                      icon: Icons.forum_rounded,
                      title: 'Say hi to your class',
                      subtitle: 'Agree on a learning plan, run a poll, or schedule your first class with ⏰.',
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
                      return _MessageView(circleId: widget.circleId, m: m, showName: showName);
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_rounded, color: AppColors.accent, size: 30),
                    onPressed: _attach,
                  ),
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
  const _MessageView({required this.circleId, required this.m, required this.showName});

  @override
  Widget build(BuildContext context) {
    if (m.type == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(20)),
            child: Text(m.text, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
        ),
      );
    }
    final mine = m.senderId == Db.uid;
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
            SelectableText(m.text, style: const TextStyle(fontSize: 15, height: 1.35, color: Colors.white)),
            const SizedBox(height: 3),
            Text(DateFormat('h:mm a').format(m.createdAt),
                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6))),
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
              child: Text(m.senderName,
                  style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
            child: body,
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
        const Pill('POLL', color: AppColors.pink, icon: Icons.poll_rounded),
        const SizedBox(height: 10),
        Text(m.question, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 12),
        for (var i = 0; i < m.options.length; i++) _option(i, total, myVote),
        const SizedBox(height: 4),
        Text('$total vote${total == 1 ? '' : 's'} · by ${m.senderName}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
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
              tween: Tween(begin: 0, end: frac),
              duration: const Duration(milliseconds: 500),
              builder: (_, v, __) => FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppColors.primary.withValues(alpha: 0.45),
                      AppColors.accent.withValues(alpha: 0.35),
                    ]),
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                if (selected) const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.accent),
                if (selected) const SizedBox(width: 6),
                Expanded(child: Text(m.options[i], overflow: TextOverflow.ellipsis)),
                Text('${(frac * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: ended ? null : AppColors.gradient,
        color: ended ? AppColors.surface2 : null,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.event_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(live ? 'CLASS IS LIVE' : (ended ? 'CLASS ENDED' : 'CLASS SCHEDULED'),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2)),
        ]),
        const SizedBox(height: 8),
        Text(m.text, style: display(17, color: Colors.white)),
        const SizedBox(height: 6),
        Text('${DateFormat('EEE, d MMM · h:mm a').format(start)} · ${m.durationMin} min',
            style: const TextStyle(color: Colors.white70)),
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
        Text('by ${m.senderName}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ]),
    );
  }
}
