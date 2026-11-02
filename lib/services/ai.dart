import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'db.dart';

class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}

class ChatTurn {
  final bool fromUser;
  final String text;
  const ChatTurn(this.fromUser, this.text);
}

class ExamQuestion {
  final String question;
  final List<String> options;
  final int answer;
  final String explanation;
  const ExamQuestion(this.question, this.options, this.answer, this.explanation);
}

/// Gemini (Google AI Studio) client. Free key: https://aistudio.google.com/apikey
class AI {
  static Future<String> _call({
    required List<Map<String, dynamic>> contents,
    String? system,
    bool json = false,
    double? temperature,
  }) async {
    final s = await Db.settings();
    if (s.geminiKey.trim().isEmpty) {
      throw AiException('Add your free Gemini API key in Profile → AI settings first.');
    }
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${s.model.trim()}:generateContent');
    final body = <String, dynamic>{
      if (system != null) 'system_instruction': {
        'parts': [
          {'text': system}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': temperature ?? (json ? 0.5 : 0.7),
        if (json) 'responseMimeType': 'application/json',
      },
    };
    final http.Response r;
    try {
      r = await http
          .post(uri,
              headers: {'Content-Type': 'application/json', 'x-goog-api-key': s.geminiKey.trim()},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 90));
    } catch (_) {
      throw AiException('Could not reach the AI. Check your internet connection.');
    }
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) {
      final msg = (data['error'] as Map?)?['message'] ?? 'HTTP ${r.statusCode}';
      throw AiException('AI error: $msg');
    }
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw AiException('The AI returned no answer. Try rephrasing.');
    }
    final parts = ((candidates.first as Map)['content'] as Map?)?['parts'] as List? ?? const [];
    return parts.map((p) => (p as Map)['text'] ?? '').join().trim();
  }

  static Map<String, dynamic> _parseJson(String raw) {
    var t = raw.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*'), '').replaceFirst(RegExp(r'```$'), '').trim();
    }
    try {
      return jsonDecode(t) as Map<String, dynamic>;
    } catch (_) {
      throw AiException('The AI response was not in the expected format. Please try again.');
    }
  }

  /// Removes stray markdown so answers read cleanly in the chat bubble.
  static String clean(String s) => s
      .replaceAll('**', '')
      .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\*\s', multiLine: true), '- ');

  // ───────────────────────── Models ─────────────────────────
  static const fallbackModels = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.5-pro',
  ];

  /// Text models this key can use, newest first. Throws if the key is invalid.
  static Future<List<String>> listModels(String key) async {
    final r = await http.get(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?pageSize=200'),
      headers: {'x-goog-api-key': key.trim()},
    ).timeout(const Duration(seconds: 20));
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) {
      throw AiException((data['error'] as Map?)?['message']?.toString() ?? 'Invalid API key');
    }
    final skip = RegExp(r'embedding|tts|image|audio|live|vision|aqa|learnlm|computer-use|robotics|native');
    final names = <String>[];
    for (final m in (data['models'] as List? ?? const [])) {
      final mm = m as Map;
      final methods = (mm['supportedGenerationMethods'] as List?)?.map((e) => e.toString()) ?? const [];
      final name = (mm['name'] ?? '').toString().replaceFirst('models/', '');
      if (!methods.contains('generateContent')) continue;
      if (!name.startsWith('gemini') || skip.hasMatch(name)) continue;
      names.add(name);
    }
    names.sort((a, b) => b.compareTo(a));
    return names.isEmpty ? fallbackModels : names;
  }

  // ───────────────────────── Tutor ─────────────────────────
  static Future<String> tutor(List<ChatTurn> history, {Roadmap? roadmap, Set<String> done = const {}}) {
    final sb = StringBuffer()
      ..writeln('You are StudyCircle Tutor, a friendly expert teacher for a software developer '
          'who studies after a full-time job. Teach clearly with small concrete examples and analogies. '
          'Keep answers focused and practical. The learner may write in English, Urdu or Hinglish — '
          'reply in the same language they use. Format as plain text: short paragraphs and "-" bullets; '
          'put code on its own lines; never use markdown symbols like ** or #. '
          'When asked to quiz, ask one question at a time and wait for the answer before continuing.');
    if (roadmap != null) {
      final lesson = nextLesson(roadmap, done);
      sb
        ..writeln()
        ..writeln("Learner's roadmap: ${roadmap.title}. ${roadmap.description}")
        ..writeln('Progress: ${roadmap.doneCount(done)}/${roadmap.topicCount} topics done. ✓ = completed.');
      for (final s in roadmap.sections) {
        sb.writeln('Section: ${s.title}');
        for (final t in s.topics) {
          sb.writeln('  ${done.contains(t.id) ? '✓' : '○'} ${t.title}');
        }
      }
      if (lesson != null) {
        sb.writeln('Current topic: ${lesson.topic.title} (section "${lesson.section.title}").');
      }
    }
    return _call(
      system: sb.toString(),
      contents: history
          .map((t) => {
                'role': t.fromUser ? 'user' : 'model',
                'parts': [
                  {'text': t.text}
                ],
              })
          .toList(),
    ).then(clean);
  }

  // ───────────────────────── Exams ─────────────────────────
  static const _examAngles = [
    'real-world debugging scenarios',
    'design trade-offs and "which approach is better and why"',
    'predicting the output or behaviour of short code snippets',
    'edge cases and common misconceptions',
    'comparing related concepts side by side',
    'applying the concept to a small project',
    'performance and best practices',
    'interview-style conceptual questions',
  ];

  static Future<List<ExamQuestion>> generateExam(Roadmap roadmap, Section section,
      {int count = 10, List<String> avoid = const []}) async {
    final rnd = Random();
    final angles = [..._examAngles]..shuffle(rnd);
    final recent = avoid.take(40).toList();
    final prompt = '''
Create a university-style section exam for a self-learner.
Roadmap: ${roadmap.title}
Section: ${section.title}
Topics covered:
${section.topics.map((t) => '- ${t.title}').join('\n')}

Write exactly $count NEW multiple-choice questions that test real understanding, not trivia.
This attempt should focus especially on: ${angles.take(3).join('; ')}.
Spread questions across all topics and vary difficulty from medium to hard.
Each question has exactly 4 options and exactly one correct answer. Randomise the position of the correct option.
${recent.isEmpty ? '' : 'The learner has ALREADY seen the questions below in earlier attempts. Do NOT repeat or lightly reword any of them — ask about different aspects:\n${recent.map((q) => '- $q').join('\n')}\n'}
Variation seed: ${rnd.nextInt(1 << 30)}
Return JSON only, in this shape:
{"questions":[{"question":"...","options":["...","...","...","..."],"answer":0,"explanation":"why the answer is correct"}]}
''';
    final raw = await _call(
      system: 'You are a strict but fair university examiner who never reuses old exam papers.',
      contents: [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      json: true,
      temperature: 1.0,
    );
    final list = (_parseJson(raw)['questions'] as List?) ?? const [];
    final out = <ExamQuestion>[];
    for (final q in list) {
      final m = q as Map;
      final opts = ((m['options'] as List?) ?? const []).map((e) => e.toString()).toList();
      final ans = (m['answer'] as num?)?.toInt() ?? -1;
      if (opts.length < 2 || ans < 0 || ans >= opts.length) continue;
      // Shuffle answer positions so the correct option isn't predictable.
      final order = List.generate(opts.length, (i) => i)..shuffle(rnd);
      out.add(ExamQuestion(
        (m['question'] ?? '').toString(),
        [for (final i in order) opts[i]],
        order.indexOf(ans),
        (m['explanation'] ?? '').toString(),
      ));
    }
    out.shuffle(rnd);
    if (out.length < 3) throw AiException('Could not build a proper exam. Please try again.');
    return out;
  }

  // ───────────────────────── Roadmap generator ─────────────────────────
  static Future<({String title, String description, List<Section> sections})> generateRoadmap(
      String goal, String time) async {
    final prompt = '''
Design a structured learning roadmap, like a university course plan.
Goal: $goal
Available time: ${time.isEmpty ? 'about 1 hour per day after work' : time}

Break it into 4–10 sections in learning order. Each section has 3–8 concrete, bite-sized topics
(each topic should be learnable in one study session). Keep titles short.
Return JSON only:
{"title":"...","description":"one sentence","sections":[{"title":"...","topics":["...","..."]}]}
''';
    final raw = await _call(
      system: 'You are an expert curriculum designer for software engineers.',
      contents: [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      json: true,
    );
    final m = _parseJson(raw);
    final sections = ((m['sections'] as List?) ?? const []).map((s) {
      final sm = s as Map;
      return Section(
        id: Db.newId(),
        title: (sm['title'] ?? '').toString(),
        topics: ((sm['topics'] as List?) ?? const [])
            .map((t) => Topic(id: Db.newId(), title: t.toString()))
            .toList(),
      );
    }).toList();
    if (sections.isEmpty) throw AiException('The AI could not build a roadmap. Try a clearer goal.');
    return (
      title: (m['title'] ?? goal).toString(),
      description: (m['description'] ?? '').toString(),
      sections: sections,
    );
  }
}
