import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/db.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'circle_chat_screen.dart';

class CirclesScreen extends StatefulWidget {
  const CirclesScreen({super.key});
  @override
  State<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends State<CirclesScreen> {
  late final Stream<List<Circle>> _circles = Db.myCircles();

  void _open(String id) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => CircleChatScreen(circleId: id)));

  void _actions() {
    showAppSheet(context, (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Study circles', style: display(22)),
        SizedBox(height: 6),
        Text('A circle is your class: group chat, polls, scheduled classes with alarms and a shared roadmap.',
            style: TextStyle(color: AppColors.muted, height: 1.4)),
        SizedBox(height: 20),
        GradientButton(
          label: 'Create a circle',
          icon: Icons.add_rounded,
          onPressed: () {
            Navigator.pop(ctx);
            _createSheet();
          },
        ),
        SizedBox(height: 10),
        GhostButton(
          label: 'Join with invite code',
          icon: Icons.vpn_key_outlined,
          onPressed: () {
            Navigator.pop(ctx);
            _joinSheet();
          },
        ),
      ]);
    });
  }

  void _createSheet() {
    final name = TextEditingController();
    Roadmap? selected;
    var type = 'squad';
    var loading = false;
    final roadmapsFuture = Db.myRoadmapsOnce();
    showAppSheet(context, (ctx) {
      return StatefulBuilder(builder: (ctx, setSheet) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Create a circle', style: display(22)),
          SizedBox(height: 16),
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: 'Circle name, e.g. "Night Owls — DSA"'),
          ),
          SizedBox(height: 16),
          Text('Type', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _TypeCard(
                icon: Icons.diversity_3_rounded,
                title: 'Study squad',
                subtitle: 'Everyone can chat, make polls and schedule classes. You are admin.',
                selected: type == 'squad',
                onTap: () => setSheet(() => type = 'squad'),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _TypeCard(
                icon: Icons.school_rounded,
                title: 'Classroom',
                subtitle: 'Only admins make polls and classes. Students chat.',
                selected: type == 'classroom',
                onTap: () => setSheet(() => type = 'classroom'),
              ),
            ),
          ]),
          SizedBox(height: 16),
          Text('Shared roadmap (optional)',
              style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          FutureBuilder<List<Roadmap>>(
            future: roadmapsFuture,
            builder: (context, snap) {
              final list = snap.data ?? <Roadmap>[];
              return Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(
                  label: Text('None'),
                  selected: selected == null,
                  onSelected: (_) => setSheet(() => selected = null),
                ),
                for (final r in list)
                  ChoiceChip(
                    label: Text(r.title),
                    selected: selected?.id == r.id,
                    onSelected: (_) => setSheet(() => selected = r),
                  ),
              ]);
            },
          ),
          SizedBox(height: 8),
          Text('Everyone who joins gets this roadmap, and you can see each other\'s progress.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          SizedBox(height: 20),
          GradientButton(
            label: 'Create circle',
            icon: Icons.groups_rounded,
            loading: loading,
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              setSheet(() => loading = true);
              try {
                final id = await Db.createCircle(name.text.trim(), selected, type: type);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _open(id);
              } catch (e) {
                if (ctx.mounted) {
                  setSheet(() => loading = false);
                  toast(ctx, 'Could not create circle: $e');
                }
              }
            },
          ),
        ]);
      });
    });
  }

  void _joinSheet() {
    final code = TextEditingController();
    var loading = false;
    showAppSheet(context, (ctx) {
      return StatefulBuilder(builder: (ctx, setSheet) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Join a circle', style: display(22)),
          SizedBox(height: 6),
          Text('Ask your friend for the 6-character invite code.', style: TextStyle(color: AppColors.muted)),
          SizedBox(height: 16),
          TextField(
            controller: code,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: display(28).copyWith(letterSpacing: 8),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))],
            decoration: InputDecoration(hintText: 'ABC123', counterText: ''),
          ),
          SizedBox(height: 16),
          GradientButton(
            label: 'Join',
            icon: Icons.login_rounded,
            loading: loading,
            onPressed: () async {
              if (code.text.trim().length != 6) return;
              setSheet(() => loading = true);
              try {
                final id = await Db.joinCircle(code.text);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _open(id);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Circles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _actions,
        icon: Icon(Icons.group_add_rounded),
        label: Text('New / Join'),
      ),
      body: StreamBuilder<List<Circle>>(
        stream: _circles,
        builder: (context, snap) {
          if (!snap.hasData) return Loader();
          final list = snap.data!;
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.groups_rounded,
              title: 'Learn together',
              subtitle: 'Create a circle and invite friends. Plan classes, vote on what to learn next, and keep '
                  'each other accountable.',
              action: GradientButton(label: 'Create or join', icon: Icons.add, expand: false, onPressed: _actions),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 100),
            itemCount: list.length,
            separatorBuilder: (_, __) => SizedBox(height: 10),
            itemBuilder: (_, i) {
              final c = list[i];
              return GlassCard(
                onTap: () => _open(c.id),
                child: Row(children: [
                  Avatar(c.name, size: 52),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: Text(c.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        Text(_when(c.lastAt), style: TextStyle(color: AppColors.muted, fontSize: 12)),
                      ]),
                      SizedBox(height: 4),
                      Text(c.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.muted, fontSize: 13)),
                      SizedBox(height: 8),
                      Wrap(spacing: 6, children: [
                        Pill(c.isClassroom ? 'Classroom' : 'Squad',
                            color: AppColors.warning,
                            icon: c.isClassroom ? Icons.school_rounded : Icons.diversity_3_rounded),
                        Pill('${c.memberIds.length} members', icon: Icons.person_outline),
                        if (c.roadmapTitle.isNotEmpty)
                          Pill(c.roadmapTitle, color: AppColors.pink, icon: Icons.route_rounded),
                      ]),
                    ]),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  String _when(DateTime t) {
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) return DateFormat('h:mm a').format(t);
    return DateFormat('d MMM').format(t);
  }
}


class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary.withValues(alpha: 0.14) : AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.muted),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35)),
          ]),
        ),
      ),
    );
  }
}
