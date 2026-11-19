import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/voiceover_tasks.dart';

void main() {
  test('includes all 3 spoken system phrases with the agreed text', () {
    final tasks = buildVoiceoverTasks();
    final byPath = {for (final t in tasks) t.outputPath: t.text};

    expect(byPath['assets/audio/system/find_intro.wav'], 'Где');
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

  test('includes every phrase of the "Монстрики" game, in its own folder', () {
    final tasks = buildVoiceoverTasks();
    final byPath = {for (final t in tasks) t.outputPath: t.text};

    expect(byPath['assets/audio/monsters/intro.wav'], 'Покорми монстриков! Красный ест красное, синий — синее.');
    expect(byPath['assets/audio/monsters/food_red_strawberry.wav'], 'Красная клубника');
    expect(byPath['assets/audio/monsters/food_red_tomato.wav'], 'Красный помидор');
    expect(byPath['assets/audio/monsters/iam_orange.wav'], 'Я оранжевый!');
    expect(byPath['assets/audio/monsters/for_blue.wav'], '— синему!');
    expect(buildMonstersVoiceoverTasks(), hasLength(71));
  });

  test('produces exactly 213 tasks with no duplicate output paths', () {
    // 115 for the scenes and system phrases, 71 for the "Монстрики" game.
    final tasks = buildVoiceoverTasks();
    expect(tasks.length, 213);
    expect(tasks.map((t) => t.outputPath).toSet().length, 213);
  });
}
