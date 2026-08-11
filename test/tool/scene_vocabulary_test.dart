import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/scene_vocabulary.dart';

void main() {
  test('defines exactly 5 scenes with 10 objects each', () {
    expect(scenes.length, 5);
    for (final scene in scenes) {
      expect(scene.objects.length, 10, reason: 'scene ${scene.id}');
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
