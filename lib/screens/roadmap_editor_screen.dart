import 'package:flutter/material.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/reminders.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'roadmap_detail_screen.dart';

class _EditTopic {
  final String id;
  final TextEditingController ctl;
  _EditTopic(this.id, String title) : ctl = TextEditingController(text: title);
}

class _EditSection {
  final String id;
  final TextEditingController ctl;
  final List<_EditTopic> topics;
  _EditSection(this.id, String title, this.topics) : ctl = TextEditingController(text: title);
}

class RoadmapEditorScreen extends StatefulWidget {
  final String? roadmapId; // null → creating
  final String initialTitle;
  final String initialDescription;
  final List<Section> initialSections;

  const RoadmapEditorScreen({
    super.key,
    this.roadmapId,
    this.initialTitle = '',
    this.initialDescription = '',
    this.initialSections = const [],
  });

  factory RoadmapEditorScreen.edit(Roadmap r) => RoadmapEditorScreen(
        roadmapId: r.id,
        initialTitle: r.title,
        initialDescription: r.description,
        initialSections: r.sections,
      );

  @override
  State<RoadmapEditorScreen> createState() => _RoadmapEditorScreenState();
}

class _RoadmapEditorScreenState extends State<RoadmapEditorScreen> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late final _desc = TextEditingController(text: widget.initialDescription);
  late final List<_EditSection> _sections = widget.initialSections
      .map((s) => _EditSection(s.id, s.title, s.topics.map((t) => _EditTopic(t.id, t.title)).toList()))
      .toList();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (_sections.isEmpty) _addSection();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    for (final s in _sections) {
      s.ctl.dispose();
      for (final t in s.topics) {
        t.ctl.dispose();
      }
    }
    super.dispose();
  }

  void _addSection() => setState(() => _sections.add(_EditSection(Db.newId(), '', [_EditTopic(Db.newId(), '')])));

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      toast(context, 'Give your roadmap a title.');
      return;
    }
    final sections = <Section>[];
    for (final s in _sections) {
      final topics = s.topics
          .where((t) => t.ctl.text.trim().isNotEmpty)
          .map((t) => Topic(id: t.id, title: t.ctl.text.trim()))
          .toList();
      if (s.ctl.text.trim().isEmpty && topics.isEmpty) continue;
      sections.add(Section(
          id: s.id, title: s.ctl.text.trim().isEmpty ? 'Untitled section' : s.ctl.text.trim(), topics: topics));
    }
    if (sections.isEmpty) {
      toast(context, 'Add at least one section with a topic.');
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await Db.saveRoadmap(
        id: widget.roadmapId,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        sections: sections,
      );
      Reminders.syncDaily();
      if (!mounted) return;
      if (widget.roadmapId == null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RoadmapDetailScreen(roadmapId: id)));
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        toast(context, 'Could not save: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicCount = _sections.fold<int>(0, (a, s) => a + s.topics.length);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roadmapId == null ? 'New roadmap' : 'Edit roadmap'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _saving
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : TextButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          TextField(
            controller: _title,
            style: display(20),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Roadmap title, e.g. "Full-stack Mastery"'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _desc,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(hintText: 'Why are you learning this? (optional)'),
          ),
          SectionLabel('${_sections.length} sections · $topicCount topics'),
          for (var i = 0; i < _sections.length; i++) _sectionEditor(i),
          const SizedBox(height: 8),
          GhostButton(label: 'Add section', icon: Icons.add, onPressed: _addSection),
        ],
      ),
    );
  }

  Widget _sectionEditor(int i) {
    final s = _sections[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 6, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(10)),
              child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: s.ctl,
                style: const TextStyle(fontWeight: FontWeight.w700),
                decoration: const InputDecoration(hintText: 'Section title', isDense: true),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.muted),
              onSelected: (v) => setState(() {
                if (v == 'up' && i > 0) {
                  _sections.insert(i - 1, _sections.removeAt(i));
                } else if (v == 'down' && i < _sections.length - 1) {
                  _sections.insert(i + 1, _sections.removeAt(i));
                } else if (v == 'delete') {
                  _sections.removeAt(i);
                }
              }),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'up', child: Text('Move up')),
                PopupMenuItem(value: 'down', child: Text('Move down')),
                PopupMenuItem(value: 'delete', child: Text('Delete section')),
              ],
            ),
          ]),
          const SizedBox(height: 8),
          for (var j = 0; j < s.topics.length; j++)
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 6),
              child: Row(children: [
                const Icon(Icons.circle_outlined, size: 14, color: AppColors.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: s.topics[j].ctl,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => setState(() => s.topics.insert(j + 1, _EditTopic(Db.newId(), ''))),
                    decoration: const InputDecoration(
                      hintText: 'Topic',
                      isDense: true,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                  onPressed: () => setState(() => s.topics.removeAt(j)),
                ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: TextButton.icon(
              onPressed: () => setState(() => s.topics.add(_EditTopic(Db.newId(), ''))),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add topic'),
            ),
          ),
        ]),
      ),
    );
  }
}
