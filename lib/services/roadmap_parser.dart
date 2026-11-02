import '../models.dart';
import 'db.dart';

/// Turns a pasted text roadmap into sections and topics.
///
///   # React              ← "#" line, or any un-indented non-bullet line = section
///   - JSX                ← "-", "*", "•", "1.", "[ ]" or indented line = topic
///   - Hooks
///   Next.js:
///     Routing
List<Section> parseRoadmapText(String text) {
  final sections = <Section>[];
  String? title;
  var topics = <Topic>[];
  final bullet = RegExp(r'^(?:[-*•+]\s*(?:\[[ xX]\]\s*)?|\d+[.)]\s+|\[[ xX]\]\s*)');

  void flush() {
    if (title != null || topics.isNotEmpty) {
      sections.add(Section(id: Db.newId(), title: title ?? 'General', topics: topics));
    }
    title = null;
    topics = <Topic>[];
  }

  for (final raw in text.split('\n')) {
    final t = raw.trim();
    if (t.isEmpty) continue;
    final indented = raw.startsWith(' ') || raw.startsWith('\t');
    if (t.startsWith('#')) {
      flush();
      title = t.replaceFirst(RegExp(r'^#+\s*'), '');
    } else if (bullet.hasMatch(t) || indented) {
      final name = t.replaceFirst(bullet, '').trim();
      if (name.isNotEmpty) topics.add(Topic(id: Db.newId(), title: name));
    } else {
      flush();
      title = t.replaceFirst(RegExp(r':\s*$'), '');
    }
  }
  flush();
  return sections;
}
