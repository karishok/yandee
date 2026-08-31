import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/voiceover_tasks.dart';

void main() {
  test('includes all 3 spoken system phrases with the agreed text', () {
    final tasks = buildVoiceoverTasks();
    final byPath = {for (final t in tasks) t.outputPath: t.text};

    expect(byPath['assets/audio/system/find_intro.wav'], 'Найди:');
    expect(byPath['assets/audio/system/wrong_hint.wav'], 'Попробуй ещё раз');
    // No entry for correct.wav: the success sound is a generated chime
    // (tool/generate_ding.dart), not a spoken phrase, so the recording tool
    // must not offer to record over it.
    expect(byPath.containsKey('assets/audio/system/correct.wav'), isFalse);
    expect(byPath['assets/audio/system/round_complete.wav'], 'Ура, ты всё нашёл!');
  });

  test('includes one task per scene object, at the path scene.json expects', () {
    final tasks = buildVoiceoverTasks();
    final byPath = {for (final t in tasks) t.outputPath: t.text};

    expect(byPath['assets/demo_content/kitchen/apple.wav'], 'Яблоко');
    expect(byPath['assets/demo_content/street/road_sign.wav'], 'Дорожный знак');
    expect(byPath['assets/demo_content/bathroom/duck_toy.wav'], 'Уточка');
  });

  test('produces exactly 72 tasks with no duplicate output paths', () {
    final tasks = buildVoiceoverTasks();
    expect(tasks.length, 72);
    expect(tasks.map((t) => t.outputPath).toSet().length, 72);
  });
}
