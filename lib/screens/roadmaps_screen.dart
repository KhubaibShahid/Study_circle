import 'package:flutter/material.dart';

import '../models.dart';
import '../services/ai.dart';
import '../services/db.dart';
import '../services/roadmap_parser.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'roadmap_detail_screen.dart';
import 'roadmap_editor_screen.dart';

class RoadmapsScreen extends StatefulWidget {
  const RoadmapsScreen({super.key});
  @override
  State<RoadmapsScreen> createState() => _RoadmapsScreenState();
}

class _RoadmapsScreenState extends State<RoadmapsScreen> {
  late final Stream<List<Roadmap>> _roadmaps = Db.myRoadmaps();

  void _openEditor({String title = '', String description = '', List<Section> sections = []}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoadmapEditorScreen(
          initialTitle: title,
          initialDescription: description,
          initialSections: sections,
        ),
      ),
    );
  }

  void _create() {
    showAppSheet(context, (ctx) {
      Widget option(IconData icon, String title, String sub, VoidCallback onTap, {Gradient? g}) => Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: GlassCard(
              color: AppColors.surface2,
              onTap: () {
                Navigator.pop(ctx);
                onTap();
              },
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(gradient: g ?? AppColors.gradient, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: Colors.white),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    SizedBox(height: 3),
                    Text(sub, style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
          );
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('New roadmap', style: display(22)),
        SizedBox(height: 18),
        option(Icons.content_paste_rounded, 'Paste my roadmap', 'Already have a list? Paste it and we structure it.',
            _paste),
        option(Icons.auto_awesome, 'Generate with AI', 'Describe your goal, get a course plan.', _generate,
            g: AppColors.warmGradient),
        option(Icons.edit_note_rounded, 'Build by hand', 'Start empty and add sections and topics.',
            () => _openEditor()),
      ]);
    });
  }

  void _paste() {
    final ctl = TextEditingController();
    showAppSheet(context, (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Paste your roadmap', style: display(22)),
        SizedBox(height: 8),
        Text(
          'Section headings on their own line, topics as "-" bullets or indented lines.',
          style: TextStyle(color: AppColors.muted),
        ),
        SizedBox(height: 16),
        TextField(
          controller: ctl,
          minLines: 8,
          maxLines: 16,
          decoration: InputDecoration(
            hintText: '# JavaScript Deep Dive\n- Closures\n- Event loop\n\n# System Design\n- Caching\n- Load balancing',
          ),
        ),
        SizedBox(height: 16),
        GradientButton(
          label: 'Structure it',
          icon: Icons.auto_fix_high_rounded,
          onPressed: () {
            final sections = parseRoadmapText(ctl.text);
            if (sections.isEmpty) {
              toast(ctx, 'Nothing to import yet.');
              return;
            }
            Navigator.pop(ctx);
            _openEditor(sections: sections);
          },
        ),
      ]);
    });
  }

  void _generate() {
    final goal = TextEditingController();
    final time = TextEditingController();
    var loading = false;
    showAppSheet(context, (ctx) {
      return StatefulBuilder(builder: (ctx, setSheet) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Generate with AI', style: display(22)),
          SizedBox(height: 16),
          TextField(
            controller: goal,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
                hintText: 'What do you want to learn? e.g. "Become a backend engineer with Node and system design"'),
          ),
          SizedBox(height: 12),
          TextField(
            controller: time,
            decoration: InputDecoration(hintText: 'Time you have, e.g. "1 hour on weekdays, 3 months"'),
          ),
          SizedBox(height: 18),
          GradientButton(
            label: loading ? 'Designing your course…' : 'Generate roadmap',
            icon: Icons.auto_awesome,
            gradient: AppColors.warmGradient,
            loading: loading,
            onPressed: () async {
              if (goal.text.trim().isEmpty) return;
              setSheet(() => loading = true);
              try {
                final r = await AI.generateRoadmap(goal.text.trim(), time.text.trim());
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _openEditor(title: r.title, description: r.description, sections: r.sections);
              } catch (e) {
                if (ctx.mounted) {
                  setSheet(() => loading = false);
                  toast(ctx, e.toString());
                }
              }
            },
          ),
          SizedBox(height: 8),
          Text('You can edit everything before saving.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ]);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Roadmaps')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: Icon(Icons.add),
        label: Text('New roadmap'),
      ),
      body: StreamBuilder<List<Roadmap>>(
        stream: _roadmaps,
        builder: (context, snap) {
          if (!snap.hasData) return Loader();
          final list = snap.data!;
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.route_rounded,
              title: 'No roadmaps yet',
              subtitle: 'A roadmap is your syllabus. Sections become semesters, topics become daily lessons.',
              action: GradientButton(label: 'Create roadmap', icon: Icons.add, expand: false, onPressed: _create),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 100),
            itemCount: list.length,
            separatorBuilder: (_, __) => SizedBox(height: 12),
            itemBuilder: (_, i) => _RoadmapCard(roadmap: list[i]),
          );
        },
      ),
    );
  }
}

class _RoadmapCard extends StatefulWidget {
  final Roadmap roadmap;
  const _RoadmapCard({required this.roadmap});
  @override
  State<_RoadmapCard> createState() => _RoadmapCardState();
}

class _RoadmapCardState extends State<_RoadmapCard> {
  late final Stream<Set<String>> _p = Db.progress(widget.roadmap.id);

  @override
  Widget build(BuildContext context) {
    final r = widget.roadmap;
    return StreamBuilder<Set<String>>(
      stream: _p,
      builder: (context, snap) {
        final done = snap.data ?? <String>{};
        return GlassCard(
          padding: EdgeInsets.all(18),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => RoadmapDetailScreen(roadmapId: r.id))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.title, style: display(18)),
                if (r.description.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(r.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
                SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  Pill('${r.sections.length} sections', icon: Icons.layers_outlined),
                  Pill('${r.doneCount(done)}/${r.topicCount} topics',
                      color: AppColors.success, icon: Icons.check_circle_outline),
                  if (r.isShared) Pill('${r.memberIds.length} learners', color: AppColors.pink, icon: Icons.groups),
                ]),
              ]),
            ),
            SizedBox(width: 12),
            ProgressRing(value: r.progress(done), size: 64),
          ]),
        );
      },
    );
  }
}
