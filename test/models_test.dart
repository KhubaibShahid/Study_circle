import 'package:flutter_test/flutter_test.dart';
import 'package:study_circle/models.dart';

void main() {
  test('nextLesson returns the first unfinished topic', () {
    final r = Roadmap(
      id: 'r',
      ownerId: 'u',
      title: 'T',
      description: '',
      memberIds: const ['u'],
      sections: const [
        Section(id: 's1', title: 'One', topics: [Topic(id: 'a', title: 'A'), Topic(id: 'b', title: 'B')]),
      ],
      createdAt: DateTime(2026),
    );
    expect(nextLesson(r, {'a'})?.topic.id, 'b');
    expect(r.progress({'a'}), 0.5);
  });

  test('extractYoutubeId handles common URLs', () {
    expect(extractYoutubeId('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    expect(extractYoutubeId('https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=1'), 'dQw4w9WgXcQ');
  });
}
