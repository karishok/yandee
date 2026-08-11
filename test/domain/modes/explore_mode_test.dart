import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/models/object_rect.dart';
import 'package:yandee/domain/models/scene_object.dart';
import 'package:yandee/domain/modes/explore_mode.dart';

import '../../support/fake_scene_mode_effects.dart';

void main() {
  const rect = ObjectRect(x: 0, y: 0, width: 0.1, height: 0.1);
  const tree = SceneObject(id: 'tree', label: 'Дерево', audio: 'tree.mp3', rect: rect);

  test('activate() has no side effects', () {
    final effects = FakeSceneModeEffects();
    ExploreMode(effects: effects).activate();
    expect(effects.objectAudioCalls, isEmpty);
    expect(effects.promptFindCalls, isEmpty);
    expect(effects.systemPhraseCalls, isEmpty);
  });

  test('tapping an object plays its own audio', () {
    final effects = FakeSceneModeEffects();
    ExploreMode(effects: effects).onObjectTapped(tree);
    expect(effects.objectAudioCalls, [tree]);
  });
}
