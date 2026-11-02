import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();
List<String> _strList(dynamic v) => ((v as List?) ?? const []).map((e) => e.toString()).toList();

class Topic {
  final String id;
  final String title;
  const Topic({required this.id, required this.title});

  Map<String, dynamic> toMap() => {'id': id, 'title': title};
  factory Topic.fromMap(Map<String, dynamic> m) =>
      Topic(id: m['id'] as String? ?? '', title: m['title'] as String? ?? '');
}

class Section {
  final String id;
  final String title;
  final List<Topic> topics;
  const Section({required this.id, required this.title, required this.topics});

  int doneCount(Set<String> done) => topics.where((t) => done.contains(t.id)).length;
  bool isComplete(Set<String> done) => topics.isNotEmpty && doneCount(done) == topics.length;
  double progress(Set<String> done) => topics.isEmpty ? 0 : doneCount(done) / topics.length;

  Map<String, dynamic> toMap() =>
      {'id': id, 'title': title, 'topics': topics.map((t) => t.toMap()).toList()};
  factory Section.fromMap(Map<String, dynamic> m) => Section(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        topics: ((m['topics'] as List?) ?? const [])
            .map((e) => Topic.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class Roadmap {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final List<String> memberIds;
  final List<Section> sections;
  final DateTime createdAt;

  const Roadmap({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.memberIds,
    required this.sections,
    required this.createdAt,
  });

  int get topicCount => sections.fold(0, (s, x) => s + x.topics.length);
  int doneCount(Set<String> done) => sections.fold(0, (s, x) => s + x.doneCount(done));
  double progress(Set<String> done) => topicCount == 0 ? 0 : doneCount(done) / topicCount;
  bool get isShared => memberIds.length > 1;

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'title': title,
        'description': description,
        'memberIds': memberIds,
        'sections': sections.map((s) => s.toMap()).toList(),
      };

  factory Roadmap.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Roadmap(
      id: d.id,
      ownerId: m['ownerId'] as String? ?? '',
      title: m['title'] as String? ?? 'Untitled',
      description: m['description'] as String? ?? '',
      memberIds: _strList(m['memberIds']),
      sections: ((m['sections'] as List?) ?? const [])
          .map((e) => Section.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: _ts(m['createdAt']),
    );
  }
}

/// The next thing to learn in a roadmap.
class Lesson {
  final Roadmap roadmap;
  final Section section;
  final Topic topic;
  final int sectionIndex;
  const Lesson(this.roadmap, this.section, this.topic, this.sectionIndex);
}

Lesson? nextLesson(Roadmap r, Set<String> done) {
  for (var i = 0; i < r.sections.length; i++) {
    final s = r.sections[i];
    for (final t in s.topics) {
      if (!done.contains(t.id)) return Lesson(r, s, t, i);
    }
  }
  return null;
}

String? extractYoutubeId(String url) {
  final m = RegExp(r'(?:v=|youtu\.be/|shorts/|embed/|live/)([A-Za-z0-9_-]{11})').firstMatch(url);
  return m?.group(1);
}

class Item {
  final String id;
  final String topicId;
  final String type; // note | video | link
  final String title;
  final String content;
  final String url;
  final String authorId;
  final String authorName;
  final DateTime createdAt;

  const Item({
    required this.id,
    required this.topicId,
    required this.type,
    required this.title,
    required this.content,
    required this.url,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
  });

  bool get isNote => type == 'note';
  String? get youtubeId => extractYoutubeId(url);

  Map<String, dynamic> toMap() => {
        'topicId': topicId,
        'type': type,
        'title': title,
        'content': content,
        'url': url,
        'authorId': authorId,
        'authorName': authorName,
      };

  factory Item.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Item(
      id: d.id,
      topicId: m['topicId'] as String? ?? '',
      type: m['type'] as String? ?? 'note',
      title: m['title'] as String? ?? '',
      content: m['content'] as String? ?? '',
      url: m['url'] as String? ?? '',
      authorId: m['authorId'] as String? ?? '',
      authorName: m['authorName'] as String? ?? '',
      createdAt: _ts(m['createdAt']),
    );
  }
}

class Circle {
  final String id;
  final String name;
  final String ownerId;
  final List<String> memberIds;
  final String inviteCode;
  final String? roadmapId;
  final String roadmapTitle;
  final String lastMessage;
  final DateTime lastAt;

  const Circle({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberIds,
    required this.inviteCode,
    required this.roadmapId,
    required this.roadmapTitle,
    required this.lastMessage,
    required this.lastAt,
  });

  factory Circle.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Circle(
      id: d.id,
      name: m['name'] as String? ?? 'Circle',
      ownerId: m['ownerId'] as String? ?? '',
      memberIds: _strList(m['memberIds']),
      inviteCode: m['inviteCode'] as String? ?? '',
      roadmapId: m['roadmapId'] as String?,
      roadmapTitle: m['roadmapTitle'] as String? ?? '',
      lastMessage: m['lastMessage'] as String? ?? '',
      lastAt: _ts(m['lastAt'] ?? m['createdAt']),
    );
  }
}

class Message {
  final String id;
  final String type; // text | poll | session | system
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;
  // poll
  final String question;
  final List<String> options;
  final Map<String, int> votes;
  // session
  final String? sessionId;
  final DateTime? startsAt;
  final int durationMin;

  const Message({
    required this.id,
    required this.type,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.question = '',
    this.options = const [],
    this.votes = const {},
    this.sessionId,
    this.startsAt,
    this.durationMin = 60,
  });

  factory Message.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final rawVotes = Map<String, dynamic>.from((m['votes'] as Map?) ?? const {});
    return Message(
      id: d.id,
      type: m['type'] as String? ?? 'text',
      senderId: m['senderId'] as String? ?? '',
      senderName: m['senderName'] as String? ?? '',
      text: m['text'] as String? ?? '',
      createdAt: _ts(m['createdAt']),
      question: m['question'] as String? ?? '',
      options: _strList(m['options']),
      votes: rawVotes.map((k, v) => MapEntry(k, (v as num).toInt())),
      sessionId: m['sessionId'] as String?,
      startsAt: m['startsAt'] is Timestamp ? (m['startsAt'] as Timestamp).toDate() : null,
      durationMin: (m['durationMin'] as num?)?.toInt() ?? 60,
    );
  }
}

class Session {
  final String id;
  final String circleId;
  final String title;
  final DateTime startsAt;
  final int durationMin;
  final String note;
  final String createdBy;

  const Session({
    required this.id,
    required this.circleId,
    required this.title,
    required this.startsAt,
    required this.durationMin,
    required this.note,
    required this.createdBy,
  });

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMin));

  factory Session.fromDoc(String circleId, DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Session(
      id: d.id,
      circleId: circleId,
      title: m['title'] as String? ?? 'Study session',
      startsAt: _ts(m['startsAt']),
      durationMin: (m['durationMin'] as num?)?.toInt() ?? 60,
      note: m['note'] as String? ?? '',
      createdBy: m['createdBy'] as String? ?? '',
    );
  }
}

class ExamResult {
  final String id;
  final String roadmapId;
  final String roadmapTitle;
  final String sectionId;
  final String sectionTitle;
  final int score;
  final int total;
  final DateTime createdAt;

  const ExamResult({
    required this.id,
    required this.roadmapId,
    required this.roadmapTitle,
    required this.sectionId,
    required this.sectionTitle,
    required this.score,
    required this.total,
    required this.createdAt,
  });

  double get pct => total == 0 ? 0 : score / total;
  bool get passed => pct >= 0.6;

  factory ExamResult.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return ExamResult(
      id: d.id,
      roadmapId: m['roadmapId'] as String? ?? '',
      roadmapTitle: m['roadmapTitle'] as String? ?? '',
      sectionId: m['sectionId'] as String? ?? '',
      sectionTitle: m['sectionTitle'] as String? ?? '',
      score: (m['score'] as num?)?.toInt() ?? 0,
      total: (m['total'] as num?)?.toInt() ?? 0,
      createdAt: _ts(m['createdAt']),
    );
  }
}

String gradeFor(double pct) {
  if (pct >= 0.9) return 'A';
  if (pct >= 0.8) return 'B';
  if (pct >= 0.7) return 'C';
  if (pct >= 0.6) return 'D';
  return 'F';
}

class AppSettings {
  final String geminiKey;
  final String model;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final String? activeRoadmapId;

  const AppSettings({
    this.geminiKey = '',
    this.model = 'gemini-2.5-flash',
    this.reminderEnabled = true,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.activeRoadmapId,
  });

  factory AppSettings.fromMap(Map<String, dynamic> m) => AppSettings(
        geminiKey: m['geminiKey'] as String? ?? '',
        model: (m['model'] as String?)?.trim().isNotEmpty == true
            ? m['model'] as String
            : 'gemini-2.5-flash',
        reminderEnabled: m['reminderEnabled'] as bool? ?? true,
        reminderHour: (m['reminderHour'] as num?)?.toInt() ?? 20,
        reminderMinute: (m['reminderMinute'] as num?)?.toInt() ?? 0,
        activeRoadmapId: m['activeRoadmapId'] as String?,
      );
}
