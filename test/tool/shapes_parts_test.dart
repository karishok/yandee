import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/shapes/shape_phrases.dart';

import '../../tool/src/shapes_parts.dart';
import '../../tool/src/voiceover_queue.dart';
import '../../tool/src/voiceover_tasks.dart';

void main() {
  test('three parts of at most ten phrases cover every phrase once, in order', () {
    final parts = buildShapesParts();
    expect(parts.map((p) => p.filter), ['shapes-1', 'shapes-2', 'shapes-3']);
    expect(parts.map((p) => p.clips.length), [10, 10, 7]);
    expect([for (final p in parts) ...p.clips], ShapePhrases.allClips);
  });

  test('the "shapes" filters select only the shapes phrases', () {
    final all = buildVoiceoverTasks();
    List<String> texts(String filter) => [for (final t in all) if (taskMatchesFilter(t, filter)) t.text];
    expect(texts('shapes'), hasLength(27));
    expect(texts('shapes-1').first, 'Круг!');
    expect(texts('shapes-3').last, 'Ура! Ты знаешь все фигурки!');
    expect(texts('monsters'), isNot(contains('Круг!')));
    for (final filter in shapesFilters) {
      expect(isValidSceneFilter(filter), isTrue, reason: filter);
      expect(isGamePhrasesFilter(filter), isTrue, reason: filter);
    }
    expect(buildShapesVoiceoverTasks().first.outputPath, '${shapesVoiceoverDir}shape_circle.wav');
  });

  test('only the part with a two-sentence phrase needs the long gap', () {
    expect(gamePhraseGapMsFor('shapes-1'), monstersShortPhraseGapMs);
    expect(gamePhraseGapMsFor('shapes-2'), monstersShortPhraseGapMs);
    expect(gamePhraseGapMsFor('shapes-3'), monstersPhraseGapMs);
    expect(gamePhraseGapMsFor('monsters-1'), monstersPhraseGapMs);
  });
}
