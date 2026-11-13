import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/scene_vocabulary.dart';

void main() {
  // The app's first five scenes. They started at 10 objects each; extra
  // objects were added per scene to match new items drawn into the updated
  // background art.
  const originalSceneCounts = {
    'home': 12,
    'kitchen': 14,
    'farm': 16,
    'street': 13,
    'bathroom': 14,
  };

  test('defines the expected scenes with the expected object count each', () {
    const expectedCounts = {
      ...originalSceneCounts,
      'playground': 7,
      'zoo': 7,
      'forest': 10,
      'toys': 7,
      'sea': 12,
    };
    expect(scenes.map((s) => s.id), expectedCounts.keys);
    for (final scene in scenes) {
      expect(scene.objects.length, expectedCounts[scene.id], reason: 'scene ${scene.id}');
    }
  });

  // The agreed exceptions to the 7-object cap. The forest art draws a
  // stump, leafy trees and a path so prominently that they are named too;
  // the sea looked empty with 7, so five more objects were drawn into it.
  const scenesAllowedOverSeven = {'forest', 'sea'};

  test('every scene added after the first five has at most 7 objects', () {
    final laterScenes = scenes.where(
      (s) => !originalSceneCounts.containsKey(s.id) && !scenesAllowedOverSeven.contains(s.id),
    );
    expect(laterScenes, isNotEmpty);
    for (final scene in laterScenes) {
      expect(scene.objects.length, lessThanOrEqualTo(7), reason: 'scene ${scene.id}');
    }
  });

  test('kitchen scene includes the expected vocabulary', () {
    final kitchen = scenes.firstWhere((s) => s.id == 'kitchen');
    expect(kitchen.title, 'Кухня');
    final apple = kitchen.objects.firstWhere((o) => o.id == 'apple');
    expect(apple.label, 'Яблоко');
  });

  test('every object id is unique within its scene', () {
    for (final scene in scenes) {
      final ids = scene.objects.map((o) => o.id).toSet();
      expect(ids.length, scene.objects.length, reason: 'scene ${scene.id}');
    }
  });
}
