import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

final _fs = FirebaseFirestore.instance;

/// All Firestore access lives here.
class Db {
  static String get uid => FirebaseAuth.instance.currentUser!.uid;
  static String get myName {
    final n = FirebaseAuth.instance.currentUser?.displayName;
    return (n == null || n.trim().isEmpty) ? 'Learner' : n;
  }

  static CollectionReference<Map<String, dynamic>> get _roadmaps => _fs.collection('roadmaps');
  static CollectionReference<Map<String, dynamic>> get _circles => _fs.collection('circles');
  static DocumentReference<Map<String, dynamic>> get _settings =>
      _fs.collection('users').doc(uid).collection('private').doc('settings');

  static String newId() => _fs.collection('_').doc().id;

  // ───────────────────────── users ─────────────────────────
  static Future<void> ensureProfile() {
    final u = FirebaseAuth.instance.currentUser!;
    return _fs.collection('users').doc(u.uid).set({
      'name': myName,
      'email': u.email ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static final Map<String, String> _nameCache = {};
  static Future<String> userName(String id) async {
    if (_nameCache.containsKey(id)) return _nameCache[id]!;
    final d = await _fs.collection('users').doc(id).get();
    final n = (d.data()?['name'] as String?) ?? 'Learner';
    _nameCache[id] = n;
    return n;
  }

  // ───────────────────────── settings ─────────────────────────
  static Stream<AppSettings> settingsStream() =>
      _settings.snapshots().map((d) => AppSettings.fromMap(d.data() ?? {}));
  static Future<AppSettings> settings() async =>
      AppSettings.fromMap((await _settings.get()).data() ?? {});
  static Future<void> saveSettings(Map<String, dynamic> data) =>
      _settings.set(data, SetOptions(merge: true));

  // ───────────────────────── roadmaps ─────────────────────────
  static List<Roadmap> _sortRoadmaps(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map(Roadmap.fromDoc).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  static Stream<List<Roadmap>> myRoadmaps() =>
      _roadmaps.where('memberIds', arrayContains: uid).snapshots().map(_sortRoadmaps);
  static Future<List<Roadmap>> myRoadmapsOnce() async =>
      _sortRoadmaps(await _roadmaps.where('memberIds', arrayContains: uid).get());

  static Stream<Roadmap?> roadmap(String id) =>
      _roadmaps.doc(id).snapshots().map((d) => d.exists ? Roadmap.fromDoc(d) : null);

  /// Creates the roadmap when [id] is null, otherwise updates title/description/sections.
  static Future<String> saveRoadmap({
    String? id,
    required String title,
    required String description,
    required List<Section> sections,
  }) async {
    final data = {
      'title': title,
      'description': description,
      'sections': sections.map((s) => s.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (id == null) {
      final ref = await _roadmaps.add({
        ...data,
        'ownerId': uid,
        'memberIds': [uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    }
    await _roadmaps.doc(id).update(data);
    return id;
  }

  static Future<void> deleteRoadmap(String id) => _roadmaps.doc(id).delete();

  // ───────────────────────── progress ─────────────────────────
  static DocumentReference<Map<String, dynamic>> _progress(String rid, [String? user]) =>
      _roadmaps.doc(rid).collection('progress').doc(user ?? uid);

  static Set<String> _doneSet(DocumentSnapshot<Map<String, dynamic>> d) =>
      Set<String>.from(((d.data()?['completed'] as List?) ?? const []).map((e) => e.toString()));

  static Stream<Set<String>> progress(String rid) => _progress(rid).snapshots().map(_doneSet);
  static Future<Set<String>> progressOnce(String rid, [String? user]) async =>
      _doneSet(await _progress(rid, user).get());

  static Future<void> setTopicDone(String rid, String topicId, bool done) => _progress(rid).set({
        'completed': done ? FieldValue.arrayUnion([topicId]) : FieldValue.arrayRemove([topicId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  // ───────────────────────── notes & videos ─────────────────────────
  static CollectionReference<Map<String, dynamic>> _items(String rid) =>
      _roadmaps.doc(rid).collection('items');

  static Stream<List<Item>> items(String rid, String topicId) => _items(rid)
      .where('topicId', isEqualTo: topicId)
      .snapshots()
      .map((s) => s.docs.map(Item.fromDoc).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  static Future<void> addItem(String rid,
      {required String topicId,
      required String type,
      required String title,
      String content = '',
      String url = ''}) {
    return _items(rid).add({
      'topicId': topicId,
      'type': type,
      'title': title,
      'content': content,
      'url': url,
      'authorId': uid,
      'authorName': myName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateItem(String rid, String itemId, Map<String, dynamic> data) =>
      _items(rid).doc(itemId).update(data);
  static Future<void> deleteItem(String rid, String itemId) => _items(rid).doc(itemId).delete();

  // ───────────────────────── circles ─────────────────────────
  static List<Circle> _sortCircles(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map(Circle.fromDoc).toList()..sort((a, b) => b.lastAt.compareTo(a.lastAt));

  static Stream<List<Circle>> myCircles() =>
      _circles.where('memberIds', arrayContains: uid).snapshots().map(_sortCircles);
  static Future<List<Circle>> myCirclesOnce() async =>
      _sortCircles(await _circles.where('memberIds', arrayContains: uid).get());
  static Stream<Circle?> circle(String id) =>
      _circles.doc(id).snapshots().map((d) => d.exists ? Circle.fromDoc(d) : null);

  static String _code() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static Future<String> createCircle(String name, Roadmap? roadmap) async {
    var code = _code();
    for (var i = 0; i < 5; i++) {
      final exists = (await _fs.collection('invites').doc(code).get()).exists;
      if (!exists) break;
      code = _code();
    }
    final ref = _circles.doc();
    final batch = _fs.batch();
    batch.set(ref, {
      'name': name,
      'ownerId': uid,
      'memberIds': [uid],
      'inviteCode': code,
      'roadmapId': roadmap?.id,
      'roadmapTitle': roadmap?.title ?? '',
      'lastMessage': 'Circle created',
      'lastAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_fs.collection('invites').doc(code), {'circleId': ref.id, 'createdBy': uid});
    await batch.commit();
    return ref.id;
  }

  /// Joins a circle by invite code and returns its id.
  static Future<String> joinCircle(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    final invite = await _fs.collection('invites').doc(code).get();
    if (!invite.exists) throw Exception('No circle found for code $code');
    final cid = invite.data()!['circleId'] as String;
    final ref = _circles.doc(cid);
    try {
      await ref.update({'memberIds': FieldValue.arrayUnion([uid])});
    } on FirebaseException catch (e) {
      // Already a member → the "adds exactly one" rule rejects the no-op update.
      if (e.code != 'permission-denied') rethrow;
    }
    final circle = Circle.fromDoc(await ref.get());
    if (circle.roadmapId != null) {
      try {
        await _roadmaps.doc(circle.roadmapId).update({'memberIds': FieldValue.arrayUnion([uid])});
      } on FirebaseException catch (_) {/* already a member */}
    }
    await _postSystem(cid, '$myName joined the circle 👋');
    return cid;
  }

  static Future<void> leaveCircle(String cid) =>
      _circles.doc(cid).update({'memberIds': FieldValue.arrayRemove([uid])});

  // ───────────────────────── chat ─────────────────────────
  static CollectionReference<Map<String, dynamic>> _messages(String cid) =>
      _circles.doc(cid).collection('messages');

  static Stream<List<Message>> messages(String cid) => _messages(cid)
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map(Message.fromDoc).toList());

  static Future<void> _touch(String cid, String preview) => _circles.doc(cid).update({
        'lastMessage': preview,
        'lastAt': FieldValue.serverTimestamp(),
      });

  static Future<void> _postSystem(String cid, String text) async {
    await _messages(cid).add({
      'type': 'system',
      'senderId': uid,
      'senderName': myName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _touch(cid, text);
  }

  static Future<void> sendText(String cid, String text) async {
    await _messages(cid).add({
      'type': 'text',
      'senderId': uid,
      'senderName': myName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _touch(cid, '$myName: $text');
  }

  static Future<void> createPoll(String cid, String question, List<String> options) async {
    await _messages(cid).add({
      'type': 'poll',
      'senderId': uid,
      'senderName': myName,
      'question': question,
      'options': options,
      'votes': <String, int>{},
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _touch(cid, '📊 Poll: $question');
  }

  static Future<void> vote(String cid, String messageId, int option) =>
      _messages(cid).doc(messageId).update({'votes.$uid': option});

  // ───────────────────────── sessions (classes) ─────────────────────────
  static CollectionReference<Map<String, dynamic>> _sessions(String cid) =>
      _circles.doc(cid).collection('sessions');

  static Future<Session> createSession(String cid,
      {required String title, required DateTime startsAt, required int durationMin, String note = ''}) async {
    final ref = _sessions(cid).doc();
    final batch = _fs.batch();
    batch.set(ref, {
      'title': title,
      'startsAt': Timestamp.fromDate(startsAt),
      'durationMin': durationMin,
      'note': note,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_messages(cid).doc(), {
      'type': 'session',
      'senderId': uid,
      'senderName': myName,
      'text': title,
      'sessionId': ref.id,
      'startsAt': Timestamp.fromDate(startsAt),
      'durationMin': durationMin,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await _touch(cid, '📅 Class scheduled: $title');
    return Session(
        id: ref.id,
        circleId: cid,
        title: title,
        startsAt: startsAt,
        durationMin: durationMin,
        note: note,
        createdBy: uid);
  }

  static Query<Map<String, dynamic>> _upcoming(String cid) => _sessions(cid)
      .where('startsAt', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 3))))
      .orderBy('startsAt');

  static Stream<List<Session>> upcomingSessions(String cid) => _upcoming(cid)
      .snapshots()
      .map((s) => s.docs.map((d) => Session.fromDoc(cid, d)).where((x) => x.endsAt.isAfter(DateTime.now())).toList());

  static Future<List<Session>> upcomingSessionsOnce(String cid) async => (await _upcoming(cid).get())
      .docs
      .map((d) => Session.fromDoc(cid, d))
      .where((x) => x.endsAt.isAfter(DateTime.now()))
      .toList();

  /// Upcoming sessions across all my circles, paired with the circle name.
  static Future<List<(Session, String)>> allUpcomingSessions() async {
    final circles = await myCirclesOnce();
    final out = <(Session, String)>[];
    for (final c in circles) {
      for (final s in await upcomingSessionsOnce(c.id)) {
        out.add((s, c.name));
      }
    }
    out.sort((a, b) => a.$1.startsAt.compareTo(b.$1.startsAt));
    return out;
  }

  // ───────────────────────── exams ─────────────────────────
  static CollectionReference<Map<String, dynamic>> get _exams =>
      _fs.collection('users').doc(uid).collection('exams');

  static Future<void> saveExam({
    required Roadmap roadmap,
    required Section section,
    required int score,
    required int total,
  }) =>
      _exams.add({
        'roadmapId': roadmap.id,
        'roadmapTitle': roadmap.title,
        'sectionId': section.id,
        'sectionTitle': section.title,
        'score': score,
        'total': total,
        'createdAt': FieldValue.serverTimestamp(),
      });

  static Stream<List<ExamResult>> examsFor(String rid) => _exams
      .where('roadmapId', isEqualTo: rid)
      .snapshots()
      .map((s) => s.docs.map(ExamResult.fromDoc).toList());

  static Future<List<ExamResult>> recentExams({int limit = 5}) async {
    final s = await _exams.orderBy('createdAt', descending: true).limit(limit).get();
    return s.docs.map(ExamResult.fromDoc).toList();
  }
}
