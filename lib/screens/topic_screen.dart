import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/reminders.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'tutor_screen.dart';

class TopicScreen extends StatefulWidget {
  final Roadmap roadmap;
  final Section section;
  final Topic topic;
  const TopicScreen({super.key, required this.roadmap, required this.section, required this.topic});
  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  late final Stream<Set<String>> _progress = Db.progress(widget.roadmap.id);
  late final Stream<List<Item>> _items = Db.items(widget.roadmap.id, widget.topic.id);

  Future<void> _toggle(bool done) async {
    await Db.setTopicDone(widget.roadmap.id, widget.topic.id, !done);
    Reminders.syncDaily();
    if (mounted && !done) toast(context, 'Topic completed ✓');
  }

  void _noteSheet([Item? existing]) {
    final title = TextEditingController(text: existing?.title ?? '');
    final body = TextEditingController(text: existing?.content ?? '');
    showAppSheet(context, (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(existing == null ? 'New note' : 'Edit note', style: display(22)),
        const SizedBox(height: 16),
        TextField(
            controller: title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Title')),
        const SizedBox(height: 12),
        TextField(
          controller: body,
          minLines: 8,
          maxLines: 18,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'What did you learn? Key ideas, code, questions…'),
        ),
        const SizedBox(height: 16),
        GradientButton(
          label: 'Save note',
          icon: Icons.check_rounded,
          onPressed: () async {
            if (title.text.trim().isEmpty && body.text.trim().isEmpty) return;
            final t = title.text.trim().isEmpty ? 'Note' : title.text.trim();
            if (existing == null) {
              await Db.addItem(widget.roadmap.id,
                  topicId: widget.topic.id, type: 'note', title: t, content: body.text.trim());
            } else {
              await Db.updateItem(widget.roadmap.id, existing.id, {'title': t, 'content': body.text.trim()});
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
      ]);
    });
  }

  void _linkSheet() {
    final url = TextEditingController();
    final title = TextEditingController();
    showAppSheet(context, (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Add video or link', style: display(22)),
        const SizedBox(height: 8),
        const Text('YouTube links show a thumbnail and open in the YouTube app.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        TextField(
          controller: url,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://youtube.com/watch?v=…', prefixIcon: Icon(Icons.link)),
        ),
        const SizedBox(height: 12),
        TextField(controller: title, decoration: const InputDecoration(hintText: 'Title (optional)')),
        const SizedBox(height: 16),
        GradientButton(
          label: 'Add',
          icon: Icons.add_rounded,
          onPressed: () async {
            var u = url.text.trim();
            if (u.isEmpty) return;
            if (!u.startsWith('http')) u = 'https://$u';
            final isYt = extractYoutubeId(u) != null;
            final host = Uri.tryParse(u)?.host.replaceFirst('www.', '') ?? 'Link';
            await Db.addItem(widget.roadmap.id,
                topicId: widget.topic.id,
                type: isYt ? 'video' : 'link',
                title: title.text.trim().isEmpty ? (isYt ? 'YouTube video' : host) : title.text.trim(),
                url: u);
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
      ]);
    });
  }

  Future<void> _delete(Item item) async {
    if (item.authorId != Db.uid) return;
    if (await confirm(context, 'Delete?', 'Remove "${item.title}"?')) {
      await Db.deleteItem(widget.roadmap.id, item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: StreamBuilder<Set<String>>(
        stream: _progress,
        builder: (context, ps) {
          final done = (ps.data ?? <String>{}).contains(widget.topic.id);
          return Scaffold(
            appBar: AppBar(
              title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.topic.title, overflow: TextOverflow.ellipsis),
                Text(widget.section.title,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500)),
              ]),
              bottom: const TabBar(
                indicatorColor: AppColors.accent,
                labelColor: AppColors.text,
                unselectedLabelColor: AppColors.muted,
                tabs: [
                  Tab(icon: Icon(Icons.sticky_note_2_outlined), text: 'Notes'),
                  Tab(icon: Icon(Icons.play_circle_outline), text: 'Videos & links'),
                ],
              ),
            ),
            body: StreamBuilder<List<Item>>(
              stream: _items,
              builder: (context, snap) {
                if (!snap.hasData) return const Loader();
                final notes = snap.data!.where((i) => i.isNote).toList();
                final media = snap.data!.where((i) => !i.isNote).toList();
                return TabBarView(children: [
                  _list(
                    notes,
                    empty: const EmptyState(
                      icon: Icons.edit_note_rounded,
                      title: 'No notes yet',
                      subtitle: 'Write what you learn in your own words — it is the fastest way to remember it.',
                    ),
                    addLabel: 'Add note',
                    onAdd: _noteSheet,
                    itemBuilder: _noteCard,
                  ),
                  _list(
                    media,
                    empty: const EmptyState(
                      icon: Icons.smart_display_rounded,
                      title: 'No videos yet',
                      subtitle: 'Save the YouTube lectures and articles you use for this topic.',
                    ),
                    addLabel: 'Add video / link',
                    onAdd: _linkSheet,
                    itemBuilder: _mediaCard,
                  ),
                ]);
              },
            ),
            bottomNavigationBar: SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(children: [
                  Expanded(
                    child: GhostButton(
                      label: 'Ask tutor',
                      icon: Icons.auto_awesome,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TutorScreen(
                            roadmapId: widget.roadmap.id,
                            standalone: true,
                            initialPrompt: 'Teach me "${widget.topic.title}" (part of ${widget.section.title}). '
                                'Start with the core idea, then a practical example, then common mistakes.',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GradientButton(
                      label: done ? 'Completed' : 'Mark complete',
                      icon: done ? Icons.check_circle_rounded : Icons.check_rounded,
                      gradient: done
                          ? const LinearGradient(colors: [AppColors.success, AppColors.accent])
                          : AppColors.gradient,
                      onPressed: () => _toggle(done),
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _list(List<Item> items,
      {required Widget empty,
      required String addLabel,
      required VoidCallback onAdd,
      required Widget Function(Item) itemBuilder}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        GhostButton(label: addLabel, icon: Icons.add_rounded, onPressed: onAdd),
        const SizedBox(height: 14),
        if (items.isEmpty) empty,
        for (final i in items) Padding(padding: const EdgeInsets.only(bottom: 12), child: itemBuilder(i)),
      ],
    );
  }

  Widget _noteCard(Item n) {
    final mine = n.authorId == Db.uid;
    return GlassCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _NoteView(item: n, onEdit: mine ? () => _noteSheet(n) : null)),
      ),
      onLongPress: () => _delete(n),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        if (n.content.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(n.content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, height: 1.45)),
        ],
        const SizedBox(height: 10),
        Text('${mine ? 'You' : n.authorName} · ${DateFormat('d MMM, h:mm a').format(n.createdAt)}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ]),
    );
  }

  Widget _mediaCard(Item v) {
    final yt = v.youtubeId;
    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () => launchUrl(Uri.parse(v.url), mode: LaunchMode.externalApplication),
      onLongPress: () => _delete(v),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (yt != null)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                Image.network('https://img.youtube.com/vi/$yt/hqdefault.jpg',
                    fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.surface2)),
                Container(color: Colors.black26),
                const Center(child: Icon(Icons.play_circle_fill_rounded, size: 58, color: Colors.white)),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            if (yt == null) ...[
              const Icon(Icons.link_rounded, color: AppColors.accent),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(v.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ]),
            ),
            const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.muted),
          ]),
        ),
      ]),
    );
  }
}

class _NoteView extends StatelessWidget {
  final Item item;
  final VoidCallback? onEdit;
  const _NoteView({required this.item, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                Navigator.pop(context);
                onEdit!();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('${item.authorName} · ${DateFormat('d MMM yyyy, h:mm a').format(item.createdAt)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 16),
          SelectableText(item.content, style: const TextStyle(fontSize: 16, height: 1.6)),
        ],
      ),
    );
  }
}
